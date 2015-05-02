local md = TGNSMessageDisplayer.Create("SIDEBAR")

local Plugin = {}

local sidebarClients = {}
local lastVoiceWarningTimes = {}

local function getSidebarParticipantClients(lookOutsideReadyRoom)
	local result = TGNS.Where(sidebarClients, function(c)
		return Shine:IsValidClient(c) and (lookOutsideReadyRoom or TGNS.IsPlayerReadyRoom(TGNS.GetPlayer(c)))
	end)
	return result
end

local function isAllTalkEnabled()
	local result = Shine.Plugins.basecommands and Shine.Plugins.basecommands.Config and (Shine.Plugins.basecommands.Config.AllTalk or Shine.Plugins.basecommands.Config.AllTalkPreGame or Shine.Plugins.basecommands.Config.AllTalkSpectator)
	return result
end

local function getSidebarHostClient(lookOutsideReadyRoom)
	local result
	local sidebarParticipantClients = getSidebarParticipantClients(lookOutsideReadyRoom)
	if #sidebarParticipantClients > 0 then
		local firstParticipantClient = TGNS.GetFirst(sidebarParticipantClients)
		if TGNS.IsClientAdmin(firstParticipantClient) then
			result = firstParticipantClient
		end
	end
	return result
end

local function getSidebarTargetClients(lookOutsideReadyRoom)
	local result = TGNS.Skip(getSidebarParticipantClients(lookOutsideReadyRoom), 1)
	return result
end

function Plugin:IsEitherPlayerInSidebar(listenerPlayer, speakerPlayer)
	local result = self:PlayerIsInSidebar(listenerPlayer) or self:PlayerIsInSidebar(speakerPlayer)
end

function Plugin:PlayerIsInSidebar(player)
	local client = TGNS.GetClient(player)
	local result = client and getSidebarHostClient() and TGNS.Has(getSidebarParticipantClients(), client)
	return result
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local cancel = false
	local hostClient = getSidebarHostClient()
	if hostClient and newTeamNumber ~= kTeamReadyRoom then
		local playerClient = TGNS.GetClient(player)
		if playerClient ~= hostClient and TGNS.Has(getSidebarParticipantClients(), playerClient) and not (force or shineForce) then
			md:ToPlayerNotifyError(player, string.format("You may leave the Ready Room after %s does.", TGNS.GetClientName(hostClient)))
			cancel = true
		end
	end
	if cancel then
		return false
	end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
	if newTeamNumber ~= kTeamReadyRoom then
		local hostClient = getSidebarHostClient(true)
		if hostClient and hostClient == client then
			local sidebarTargetClients = getSidebarTargetClients(true)
			local sidebarTargetClientNames = TGNS.Join(TGNS.Select(sidebarTargetClients, TGNS.GetClientName), ", ")
			md:ToAdminNotifyInfo(string.format("%s has ended the Sidebar. Free to leave the Ready Room: %s", TGNS.GetClientName(hostClient), sidebarTargetClientNames))
			TGNS.DoFor(TGNS.GetPlayers(sidebarTargetClients), function(p)
				md:ToPlayerNotifyInfo(p, "You are free to leave the Ready Room.")
			end)
			TGNS.DoFor(getSidebarParticipantClients(), function(c)
				Shine:SendText(c, Shine.BuildScreenMessage(70, 0.2, 0.25, "", 1, 0, 255, 0, 0, 4, 0 ) )
			end)
			sidebarClients = {}
		end
	end
end

function Plugin:CreateCommands()
	local sidebarCommand = self:BindCommand( "sh_sidebar", "sidebar", function(client, playerPredicate)
		local player = TGNS.GetPlayer(client)
		local sidebarParticipantClients = getSidebarParticipantClients()
		local hostClient = getSidebarHostClient()
		if hostClient and hostClient ~= client then
			md:ToPlayerNotifyError(player, string.format("%s is already holding a Sidebar.", TGNS.GetClientName(hostClient)))
		else
			if isAllTalkEnabled() then
				md:ToPlayerNotifyError(player, "Alltalk is enabled. Sidebars are not available while alltalk is enabled.")
			else
				local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
				if targetPlayer then
					local targetClient = TGNS.GetClient(targetPlayer)
					md:ToAdminNotifyInfo(string.format("%s has taken %s into Sidebar.", TGNS.GetClientName(client), TGNS.GetClientName(targetClient)))
					TGNS.SendToTeam(TGNS.GetPlayer(targetClient), kTeamReadyRoom, true)
					TGNS.SendToTeam(TGNS.GetPlayer(client), kTeamReadyRoom, true)
					if hostClient == nil then
						sidebarClients = {}
						table.insert(sidebarClients, client)
					end
					table.insertunique(sidebarClients, targetClient)
				else
					md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
				end
			end
		end
	end)
	sidebarCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
	sidebarCommand:Help( "<player> Take a player into Sidebar." )
end

function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()

    local originalGetCanPlayerHearPlayer
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(gamerulesSelf, listenerPlayer, speakerPlayer)
		local result = originalGetCanPlayerHearPlayer(gamerulesSelf, listenerPlayer, speakerPlayer)
		if self:PlayerIsInSidebar(speakerPlayer) then
			result = self:PlayerIsInSidebar(listenerPlayer)
		elseif self:PlayerIsInSidebar(listenerPlayer) then
			result = self:PlayerIsInSidebar(speakerPlayer) or ((TGNS.Has(getSidebarParticipantClients(), TGNS.GetClient(listenerPlayer)) and TGNS.IsClientAdmin(TGNS.GetClient(listenerPlayer))) and (Shine.Plugins.lookdown and Shine.Plugins.lookdown.IsPlayerLookingDown and Shine.Plugins.lookdown:IsPlayerLookingDown(listenerPlayer)) and result)
		end
		return result
	end)

	TGNS.RegisterEventHook("OnEverySecond", function()
		local hostClient = getSidebarHostClient()
		if hostClient then
			local sidebarTargetClients = getSidebarTargetClients()
			local message = string.format("Sidebar (%s):\n%s", TGNS.GetClientName(hostClient), TGNS.Join(TGNS.Select(sidebarTargetClients, TGNS.GetClientName), "\n"))
			TGNS.DoFor(getSidebarParticipantClients(), function(c)
				if lastVoiceWarningTimes[c] == nil or lastVoiceWarningTimes[c] < Shared.GetTime() - 1 then
					Shine:SendText(c, Shine.BuildScreenMessage(70, 0.2, 0.25, string.format("%s%s%s", message, TGNS.IsClientAdmin(c) and "\n\nLook down to hear beyond Sidebar." or "", isAllTalkEnabled() and "\nAlltalk enabled!!" or ""), 5, isAllTalkEnabled() and 255 or 0, isAllTalkEnabled() and 0 or 255, 0, 0, 4, 0 ) )
					lastVoiceWarningTimes[c] = Shared.GetTime()
				end
			end)
		end
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("sidebar", Plugin )