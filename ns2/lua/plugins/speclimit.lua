Script.Load("lua/TGNSCommon.lua")

local allowedSpectatorSteamIds = {}
local NAME_PREFIX = "spec-"
local NAME_REMINDER_INTERVAL_IN_SECONDS = 400
local NAME_REMINDER_MESSAGE = "Remember to remove '" .. NAME_PREFIX .. "' from your name before reconnecting."
local DISCONNECT_REASON = "No Spectator slots open. You are being disconnected."

local function RemindSpectatorsToRemoveSpecFromName()
	TGNS.DoFor(TGNS.GetSpectatorClients(), function(c)
		local clientName = TGNS.GetClientName(c)
		if TGNS.StartsWith(clientName, NAME_PREFIX) then
			TGNS.PlayerAction(c, function(p)
				TGNS.SendChatMessage(p, NAME_REMINDER_MESSAGE, "SPECJOIN")
			end)
		end
	end)
	TGNS.ScheduleAction(NAME_REMINDER_INTERVAL_IN_SECONDS, RemindSpectatorsToRemoveSpecFromName)
end
TGNS.ScheduleAction(NAME_REMINDER_INTERVAL_IN_SECONDS, RemindSpectatorsToRemoveSpecFromName)

local function RemoveFailedSpecAttempt(client)
	TGNS.KickClient(client, DISCONNECT_REASON, function(c,p) TGNS.SendChatMessage(p, DISCONNECT_REASON, "SPECJOIN") end)
end

local function SpecLimitOnClientDelayedConnect(client)
	local cancel = false
	table.remove(allowedSpectatorSteamIds, steamId)
	if TGNS.IsClientSM(client) then
		local clientName = TGNS.GetClientName(client)
		if TGNS.StartsWith(clientName, NAME_PREFIX) then
			local steamId = TGNS.GetClientSteamId(client)
			if #TGNS.GetSpectatorClients(TGNS.GetPlayerList()) < 4 or TGNS.IsClientAdmin(client) then
				table.insert(allowedSpectatorSteamIds, steamId)
				TGNS.PlayerAction(client, function(p)
					TGNS.SendChatMessage(p, NAME_REMINDER_MESSAGE, "SPECJOIN")
					TGNS.SendToTeam(p, kSpectatorIndex)
				end)
			else
				TGNS.ScheduleAction(10, function() RemoveFailedSpecAttempt(client) end)
			end
			cancel = true
		end
	end
	return cancel
end
TGNS.RegisterEventHook("OnClientDelayedConnect", SpecLimitOnClientDelayedConnect, TGNS.HIGHEST_EVENT_HANDLER_PRIORITY)

local function SpecLimitOnTeamJoin(self, player, newTeamNumber, force)
	local cancel = false
	if TGNS.IsPlayerSpectator(player) then
		local client = TGNS.ClientAction(player, function(c) return c end)
		local steamId = TGNS.GetClientSteamId(client)
		TGNS.RemoveSteamIDFromGroup(steamId, "spectator_group")
	end
	local playerIsAdmin = TGNS.ClientAction(player, TGNS.IsClientAdmin)
	if newTeamNumber == kSpectatorIndex then
		if not playerIsAdmin then
			local steamId = TGNS.ClientAction(player, TGNS.GetClientSteamId)
			if not TGNS.Has(allowedSpectatorSteamIds, steamId) then
				TGNS.SendChatMessage(player, "Spectator is not available now.")
				cancel = true
			end
		end
		if not cancel then
			local client = TGNS.ClientAction(player, function(c) return c end)
			local steamId = TGNS.GetClientSteamId(client)
			TGNS.AddSteamIDToGroup(TGNS.GetClientSteamId(client), "spectator_group")
		end
	elseif TGNS.IsPlayerSpectator(player) then
		if playerIsAdmin then
			local playerName = TGNS.GetPlayerName(player)
			if TGNS.StartsWith(playerName, NAME_PREFIX) then
				TGNS.SendChatMessage(player, "Admins must remove " .. NAME_PREFIX .. " from name to leave Spectator.", "SPECJOIN")
				cancel = true
			end
		else
			TGNS.SendChatMessage(player, "Reconnect to leave Spectator.", "SPECJOIN")
			cancel = true
		end
	end
	return cancel
end
TGNS.RegisterEventHook("OnTeamJoin", SpecLimitOnTeamJoin)