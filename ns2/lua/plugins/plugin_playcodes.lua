// automate voicecomm vetting of strangers

if kDAKConfig and kDAKConfig.PlayCodes then
	Script.Load("lua/TGNSCommon.lua")
	Script.Load("lua/TGNSPlayerDataRepository.lua")

	local pdr = TGNSPlayerDataRepository.Create("playcodes", function(data)
				data.showShorthandCodes = data.showShorthandCodes ~= nil and data.showShorthandCodes or false
				return data
			end
		)
	
	local profiles = {}
	local mapPlayCode = math.random(100, 999)
	local nextTestAllowedAt = 0

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
		TGNS.SendTeamChat(TGNS.PlayerAction(client, TGNS.GetPlayerTeamNumber), string.format("COMMS Established! %s entered the PlayCode!", TGNS.GetClientName(client)), "PlayCodes")
		TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, "Do you like teamwork? Become a regular at tacticalgamer.com/natural-selection", "PlayCodes") end)
		nextTestAllowedAt = Shared.GetTime() + 60
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
		local displayName = string.sub(TGNS.GetClientName(client), 1, 12)
		local teamRegularClients = GetTeamRegularClients(client)
		TGNS.DoFor(TGNS.GetPlayers(teamRegularClients), function(p)
			local steamId = TGNS.ClientAction(p, TGNS.GetClientSteamId)
			local prefs = pdr:Load(steamId)
			local teamMessageTemplate = prefs.showShorthandCodes and "%s: %s" or "VOICECOMMS! Can %s hear you? Can they type %s into Team Chat to stay?"
			//local teamMessageTemplate = prefs.showShorthandCodes and "%s: %s" or "VOICECOMMS CHECK! Tell %s to type %s into Team Chat to prevent kick!"
			local teamMessage = string.format(teamMessageTemplate, displayName, playCode)
			TGNS.SendChatMessage(p, teamMessage, "PlayCodes")
		end)
		TGNS.PlayerAction(client, function(player) TGNS.SendChatMessage(player, "Listen to your team for your 3-digit PlayCode!", "PlayCodes") end)
	end
	
	local function ProcessProfiles()
		TGNS.ScheduleAction(10, ProcessProfiles)
		if nextTestAllowedAt < Shared.GetTime() then
			TGNS.DoFor(profiles, function(p)
				if p.isActive then
					local client = GetClientMatchingSteamId(p.steamId)
					if client == nil then
						//TGNS.SendAdminChat(string.format("No client found for SteamId %s.", p.steamId), "PlayCodesDebug")
						p.notFoundCount = p.notFoundCount + 1
						if p.notFoundCount > 3 then
							p.isActive = false
						end
					else
						local clientIsOnGameplayTeam
						local clientIsActive
						TGNS.PlayerAction(client, function(p)
							clientIsOnGameplayTeam = TGNS.GetPlayerTeamNumber(p) ~= kTeamReadyRoom
							clientIsActive = not DAKIsPlayerAFK(p)
						end)
						if clientIsOnGameplayTeam and clientIsActive and p.doNotEnforceBefore < Shared.GetTime() then
							local teamRegularClients = GetTeamRegularClients(client)
							if #teamRegularClients >= 4 then
								if p.noticesRemaining > 0 then
									p.noticesRemaining = p.noticesRemaining - 1
									SendChatMessages(client, p.playCode)
									return true
								else
									TGNS.KickClient(client, "You did not enter your three-digit PlayCode. You are being kicked.")
									p.isActive = false
								end
							elseif p.noticesRemaining < 2 then
								p.isActive = false
							end
						end
					end
				end
			end)
		end
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
		result.doNotEnforceBefore = Shared.GetTime() + 30
		return result
	end
	
	local function PlayCodesOnTeamJoin(self, player, newTeamNumber, force)
		TGNS.ClientAction(player, function(c)
			if TGNS.IsClientStranger(c) then
				MarkAllProfilesInactive(c)
				if not HasClientBeenVetted(c) then
					local profile = CreateProfile(c)
					table.insert(profiles, profile)
				end
			end
		end)
	end
	DAKRegisterEventHook("kDAKOnTeamJoin", PlayCodesOnTeamJoin, 5)

	local function svPlayCodes(client)
		local steamId = TGNS.GetClientSteamId(client)
		local prefs = pdr:Load(steamId)
		prefs.showShorthandCodes = not prefs.showShorthandCodes
		pdr:Save(prefs)
		local notificationsLengthDescriptor = prefs.showShorthandCodes and "short" or "long"
		local message = string.format("You will see %s PlayCodes notifications.", notificationsLengthDescriptor)
		TGNS.ConsolePrint(client, message, "PLAYCODES")
	end
	DAKCreateServerAdminCommand("Console_sv_playcodes", svPlayCodes, "Toggle short/long PlayCodes notifications.")

end

Shared.Message("PlayCodes Loading Complete")