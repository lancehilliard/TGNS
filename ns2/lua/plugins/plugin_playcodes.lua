// automate voicecomm vetting of strangers

if kDAKConfig and kDAKConfig.PlayCodes then
	Script.Load("lua/TGNSCommon.lua")
	
	local profiles = {}
	local mapPlayCode = math.random(100, 999)

	local function MarkAllProfilesInactive(client)
		local steamId = TGNS.GetClientSteamId(client)
		TGNS.DoFor(profiles, function(p)
			if p.steamId == steamId then
				p.isActive = false
			end
		end)
	end
	
	local function HasClientBeenVetted(client)
		local result = false
		local steamId = TGNS.GetClientSteamId(client)
		TGNS.DoFor(profiles, function(p)
			if p.steamId == steamId and p.isVetted then
				result = true
			end
		end)
		return result
	end
	
	local function MarkProfileAsVettedForClient(client, playCode)
		local steamId = TGNS.GetClientSteamId(client)
		TGNS.DoFor(profiles, function(p)
			if p.steamId == steamId then
				p.isVetted = true
				p.isActive = false
			end
		end)
	end
	
	local function OnClientVetted(client, playCode)
		MarkAllProfilesInactive(client)
		MarkProfileAsVettedForClient(client, playCode)
		TGNS.SendTeamChat(TGNS.PlayerAction(client, TGNS.GetPlayerTeamNumber), string.format("%s communicated with the team!", TGNS.GetClientName(client)))
		TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, "Tired of PlayCodes? Become a regular at tacticalgamer.com/natural-selection") end)
	end
	
	local function PlayCodeVetsClient(client, playCode)
		local result = false
		local steamId = TGNS.GetClientSteamId(client)
		TGNS.DoFor(profiles, function(p)
			if not result then
				result = p.steamId == steamId and p.playCode == playCode
			end
		end)
		return result
	end
	
	local function onChatClient(client, networkMessage)
		local teamOnly = networkMessage.teamOnly
		local message = StringTrim(networkMessage.message)
		local playCode = tonumber(message)
		if teamOnly and playCode ~= nil then
			if PlayCodeVetsClient(client, playCode) then
				OnClientVetted(client, message)
			end
		end
	end
	TGNS.RegisterNetworkMessageHook("ChatClient", onChatClient)
	
	local function GetTeamRegularClients(client)
		local result = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c, p)
			return TGNS.PlayersAreTeammates(TGNS.GetPlayer(client), p) and not TGNS.IsClientStranger(c)
		end)
		return result
	end
	
	local function SendChatMessages(client, playCode)
		local displayName = string.sub(TGNS.GetClientName(client), 1, 17)
		local teamMessage = string.format("COMMS CHECK! Tell %s to type %s into Team Chat to prevent kick!", displayName, playCode)
		local teamRegularClients = GetTeamRegularClients(client)
		TGNS.DoFor(TGNS.GetPlayers(teamRegularClients), function(p) TGNS.SendChatMessage(p, teamMessage, "PlayCodes") end)
		TGNS.PlayerAction(client, function(player) TGNS.SendChatMessage(player, "Listen on team voicecomm for your PlayCode to avoid getting kicked!", "PlayCodes") end)
	end
	
	local function ProcessProfiles()
		TGNS.ScheduleAction(10, ProcessProfiles)
		TGNS.DoFor(profiles, function(p)
			if p.isActive then
				local client = GetClientMatchingSteamId(p.steamId)
				if client == nil then
					p.notFoundCount = p.notFoundCount + 1
					if p.notFoundCount > 3 then
						p.isActive = false
					end
				else
					local teamRegularClients = GetTeamRegularClients(client)
					if #teamRegularClients > 5 then
						if p.noticesRemaining > 0 then
							p.noticesRemaining = p.noticesRemaining - 1
							SendChatMessages(client, p.playCode)
						else
							TGNS.KickClient(client, "You did not enter your PlayCode. You are being kicked.")
							p.isActive = false
						end
					elseif p.noticesRemaining < 2 then
						p.isActive = false
					end
				end
			end
		end)
	end
	ProcessProfiles()
	
	local function CreateProfile(client)
		local result = {}
		result.isActive = true
		result.isVetted = false
		result.notFoundCount = 0
		result.noticesRemaining = 12
		result.playCode = mapPlayCode
		result.steamId = TGNS.GetClientSteamId(client)
		return result
	end
	
	local function PlayCodesOnTeamJoin(self, player, newTeamNumber, force)
		TGNS.ClientAction(player, function(c)
			if TGNS.IsClientStranger(c) then
				if not HasClientBeenVetted(c) then
					local profile = CreateProfile(c)
					table.insert(profiles, profile)
				end
			end
		end)
	end
	DAKRegisterEventHook("kDAKOnTeamJoin", PlayCodesOnTeamJoin, 5)

end

Shared.Message("PlayCodes Loading Complete")