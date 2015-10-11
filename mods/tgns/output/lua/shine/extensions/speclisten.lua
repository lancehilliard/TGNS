local originalGetCanPlayerHearPlayer
local md
local specmodes = {}
local specpriority = {}
local whenSpecWasLastHeard = {}

local modeDescriptions = {["0"] = "Chat Advisory OFF; Voicecomm: All"
	, ["1"] = "Chat Advisory OFF; Voicecomm: Marines only"
	, ["2"] = "Chat Advisory OFF; Voicecomm: Aliens only"
	, ["3"] = "Chat Advisory OFF; Voicecomm: Marines and Aliens only"
	, ["4"] = "Chat Advisory OFF; Voicecomm: Spectators only"
	, ["5"] = "Chat Advisory OFF; Voicecomm: None"}

local pdr = TGNSPlayerDataRepository.Create("specmode", function(data)
	data.specmode = data.specmode ~= nil and data.specmode or nil
	data.specpriority = data.specpriority ~= nil and data.specpriority or nil
	return data
end)

local function listenerSpectatorShouldHearSpeaker(listenerPlayer, speakerPlayer)
	local listenerClient = TGNS.GetClient(listenerPlayer)
	local specmode = specmodes[listenerClient] or 0
	local playerCanHearAllVoices = specmode == 0
	local playerIsOnGameplayTeamThatPlayerCanHear = (TGNS.PlayerIsOnPlayingTeam(speakerPlayer) and (specmode == 3 or specmode == TGNS.GetPlayerTeamNumber(speakerPlayer)))
	local bothPlayersAreSpectatorsAndPlayerCanHearSpectators = TGNS.IsPlayerSpectator(listenerPlayer) and TGNS.IsPlayerSpectator(speakerPlayer) and specmode == 4
	local result = playerCanHearAllVoices or playerIsOnGameplayTeamThatPlayerCanHear or bothPlayersAreSpectatorsAndPlayerCanHearSpectators
	
	local adjustForSpecPriority = function()
		if result then
			if TGNS.IsPlayerSpectator(listenerPlayer) then
				if TGNS.IsPlayerSpectator(speakerPlayer) then
					whenSpecWasLastHeard[listenerClient] = Shared.GetTime()
				else
					whenSpecWasLastHeard[listenerClient] = whenSpecWasLastHeard[listenerClient] or 0
					if specpriority[listenerClient] and Shared.GetTime() - whenSpecWasLastHeard[listenerClient] < 0.5 then
						result = false
					end
				end
			end
		end
	end
	adjustForSpecPriority()

	return result
end

local function showUsage(player)
	md:ToPlayerNotifyError(player, "Invalid mode. Press 'M > Info > sh_specmode' for usage.")
end

local Plugin = {}

function Plugin:GetClientSviEnabled(client)
	local result = specpriority[client] == true
	return result
end

function Plugin:ClientConfirmConnect(client)
	local steamId = TGNS.GetClientSteamId(client)
	pdr:Load(steamId, function(loadResponse)
		if Shine:IsValidClient(client) then
			if loadResponse.success then
				specmodes[client] = loadResponse.value.specmode
				specpriority[client] = loadResponse.value.specpriority
				TGNS.ExecuteEventHooks("SviChanged", client, specpriority[client])
			else
				Shared.Message("specmode ERROR: Unable to access data.")
			end
		end
	end)
end

local function showCurrentSpecMode(player, showIfNil)
	local client = TGNS.GetClient(player)
	local currentSpecMode = specmodes[client]
	if showIfNil then
		currentSpecMode = currentSpecMode or 0
	end
	if currentSpecMode then
		local message = string.format("Current sh_specmode: %s (%s%s)", currentSpecMode, modeDescriptions[tostring(currentSpecMode)], specpriority[client] and currentSpecMode <= 3 and ", with Spectator Voice Interruptions (SVI)" or "")
		md:ToPlayerNotifyInfo(player, message)
		if not specpriority[client] then
			md:ToPlayerNotifyInfo(player, "SVI (Spectator Voicecomm Interruptions) interrupts all voicecomms when fellow Spectators speak! Toggle it in the menu.")
		end
	end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if newTeamNumber == kSpectatorIndex then
		showCurrentSpecMode(player)
	end
end

function Plugin:CreateCommands()
    local modCommand = self:BindCommand( "sh_specmode", "specmode", function(client, modeCandidate)
    	local player = TGNS.GetPlayer(client)
    	local mode = tonumber(modeCandidate)
    	if mode == nil or mode < 0 or mode > 6 then
    		showUsage(player)
    	else
    		if mode == 6 then
    			local currentSpecMode = specmodes[client] or 0
    			if currentSpecMode > 3 and not specpriority[client] then
    				md:ToPlayerNotifyError(player, "Before enabling SVI, you must first configure Spec Voicecomms to include Spectators in the voicecomms you hear.")
    			else
    				specpriority[client] = not specpriority[client]
    				TGNS.ExecuteEventHooks("SviChanged", client, specpriority[client])
    			end
    		else
	    		specmodes[client] = mode
    		end
    		local steamId = TGNS.GetClientSteamId(client)
			pdr:Load(steamId, function(loadResponse)
				if loadResponse.success then
					local data = loadResponse.value
					data.specmode = specmodes[client]
					data.specpriority = specpriority[client]
					pdr:Save(data, function(saveResponse)
						if not saveResponse.success then
							Shared.Message("specmode ERROR: Unable to save data.")
						end
					end)
				else
					if Shine:IsValidClient(client) then
						md:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to access specmode data.")
					end
					Shared.Message("taglines ERROR: Unable to access data.")
				end
			end)
    	end
    	showCurrentSpecMode(player, true)
    end, true)
    modCommand:AddParam{ Type = "string", TakeRestofLine = true, Optional = true }
    modCommand:Help( "Adjust what voicecomms you hear in Spectate." )
end

function Plugin:Initialise()
    self.Enabled = true
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result
		if TGNS.IsPlayerSpectator(listenerPlayer) and not (Shine.Plugins.sidebar and Shine.Plugins.sidebar.IsEitherPlayerInSidebar and Shine.Plugins.sidebar:IsEitherPlayerInSidebar(listenerPlayer, speakerPlayer)) then
			result = listenerSpectatorShouldHearSpeaker(listenerPlayer, speakerPlayer)
		else
			result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		end
		return result
	end)
	TGNS.ScheduleActionInterval(90, function()
		local specPlayers = TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.IsPlayerSpectator(p) and TGNS.ClientAction(p, function(c) return specmodes[c] end) == nil end)
		TGNS.DoFor(specPlayers, function(p)
			md:ToPlayerNotifyInfo(p, "Limit of 8 per team. Join when you can. Spec while you wait!")
			md:ToPlayerNotifyInfo(p, "Adjust what you hear in Spectate: press M > Spec Voicecomms")
			md:ToPlayerNotifyInfo(p, "Enjoy the show. Spectating is a fun privilege! Don't abuse it!")
		end)
	end)
	md = TGNSMessageDisplayer.Create("SPECTATE")
	self:CreateCommands()

	Shine.Hook.Add("PlayerSay", "SendTeamChatToSpectators", function(client, networkMessage)
		local chattingPlayer = TGNS.GetPlayer(client)
		local teamOnly = networkMessage.teamOnly
		if chattingPlayer and teamOnly and not TGNS.IsPlayerSpectator(chattingPlayer) then
			local message = StringTrim(networkMessage.message)
			TGNS.DoFor(TGNS.GetSpectatorPlayers(TGNS.GetPlayerList()), function(listeningPlayer)
				if listeningPlayer and listenerSpectatorShouldHearSpeaker(listeningPlayer, chattingPlayer) then
					Server.SendNetworkMessage(listeningPlayer, "Chat", BuildChatMessage(true, TGNS.GetPlayerName(chattingPlayer), TGNS.PlayerIsOnPlayingTeam(chattingPlayer) and chattingPlayer:GetLocationId() or TGNS.READYROOM_LOCATION_ID, chattingPlayer:GetTeamNumber(), chattingPlayer:GetTeamType(), message), true)
				end
			end)
		end
	end, TGNS.LOWEST_EVENT_HANDLER_PRIORITY)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("speclisten", Plugin )