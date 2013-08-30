local allowedSpectatorSteamIds = {}
local NAME_PREFIX = "spec-"
local NAME_REMINDER_INTERVAL_IN_SECONDS = 400
local NAME_REMINDER_MESSAGE = "Remember to remove '" .. NAME_PREFIX .. "' from your name before reconnecting."
local DISCONNECT_REASON = "No Spectator slots open. You are being disconnected."
local clientConfirmConnectHandled = {}

local function RemindSpectatorsToRemoveSpecFromName()
	TGNS.DoFor(TGNS.GetSpectatorClients(), function(c)
		local clientName = TGNS.GetClientName(c)
		if TGNS.StartsWith(clientName, NAME_PREFIX) then
			TGNS.PlayerAction(c, function(p)
				md:ToPlayerNotifyInfo(p, NAME_REMINDER_MESSAGE)
			end)
		end
	end)
	TGNS.ScheduleAction(NAME_REMINDER_INTERVAL_IN_SECONDS, RemindSpectatorsToRemoveSpecFromName)
end
TGNS.ScheduleAction(NAME_REMINDER_INTERVAL_IN_SECONDS, RemindSpectatorsToRemoveSpecFromName)

local function RemoveFailedSpecAttempt(client)
	TGNS.KickClient(client, DISCONNECT_REASON, function(c,p) md:ToPlayerNotifyInfo(p, DISCONNECT_REASON) end)
end

local md = TGNSMessageDisplayer.Create()

local Plugin = {}

function Plugin:ClientConfirmConnectHandled(client)
	local result = TGNS.Has(clientConfirmConnectHandled, client)
	return result
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local cancel = false
	if TGNS.IsPlayerSpectator(player) then
		local client = TGNS.GetClient(player)
		TGNS.RemoveTempGroup(client, "spectator_group")
	end
	local playerIsAdmin = TGNS.ClientAction(player, TGNS.IsClientAdmin)
	if newTeamNumber == kSpectatorIndex then
		if not playerIsAdmin then
			local steamId = TGNS.ClientAction(player, TGNS.GetClientSteamId)
			if not TGNS.Has(allowedSpectatorSteamIds, steamId) then
				md:ToPlayerNotifyError(player, "Spectator is not available now.")
				cancel = true
			end
		end
		if not cancel then
			local client = TGNS.ClientAction(player, function(c) return c end)
			local steamId = TGNS.GetClientSteamId(client)
			TGNS.AddTempGroup(client, "spectator_group")
		end
	elseif TGNS.IsPlayerSpectator(player) then
		if playerIsAdmin then
			local playerName = TGNS.GetPlayerName(player)
			if TGNS.StartsWith(playerName, NAME_PREFIX) then
				md:ToPlayerNotifyError(player, "Admins must remove " .. NAME_PREFIX .. " from name to leave Spectator.")
				cancel = true
			end
		else
			md:ToPlayerNotifyError(player, "Reconnect to leave Spectator.")
			cancel = true
		end
	end
	if cancel then
		TGNS.RespawnPlayer(player)
		return false
	end
end

function Plugin:PlayerSay(client, networkMessage)
	local cancel = false
	local teamOnly = networkMessage.teamOnly
	local message = StringTrim(networkMessage.message)
	if not teamOnly then
		TGNS.PlayerAction(client, function(p)
			if TGNS.IsPlayerSpectator(p) and not TGNS.IsClientAdmin(client) then
				md:ToPlayerNotifyError(p, "Spectators may chat only to other Spectators.")
				cancel = true
			end
		end)
	end
	if cancel then
		return ""
	end
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("ClientConfirmConnect", function(client)
		local cancel = false
		table.remove(allowedSpectatorSteamIds, steamId)
		if TGNS.IsClientSM(client) then
			local clientName = TGNS.GetClientName(client)
			if TGNS.StartsWith(clientName, NAME_PREFIX) then
				local steamId = TGNS.GetClientSteamId(client)
				local spectatorsCountLimit = 4 // TGNSCaptains.IsCaptainsMode() and 7 or 4
				if #TGNS.GetSpectatorClients(TGNS.GetPlayerList()) < spectatorsCountLimit or TGNS.IsClientAdmin(client) then
					table.insert(allowedSpectatorSteamIds, steamId)
					TGNS.PlayerAction(client, function(p)
						md:ToPlayerNotifyInfo(p, NAME_REMINDER_MESSAGE)
						TGNS.SendToTeam(p, kSpectatorIndex)
					end)
				else
					TGNS.ScheduleAction(10, function() RemoveFailedSpecAttempt(client) end)
				end
				cancel = true
			end
		end
		if cancel then
			table.insert(clientConfirmConnectHandled, client)
		end
	end, TGNS.HIGHEST_EVENT_HANDLER_PRIORITY)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("speclimit", Plugin )