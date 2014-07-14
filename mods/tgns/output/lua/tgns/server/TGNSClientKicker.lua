TGNSClientKicker = {}
local kickedClients = {}
local chatAdvisory = "Kicked. See console for details."
local kickDelayInSeconds = 5
local md = TGNSMessageDisplayer.Create("KICK")
local kickReasons = {}
local REPEAT_KICK_THRESHOLD = 3
local REPEAT_KICK_BAN_DURATION_IN_MINUTES = 120

local function AdviseKickedClients()
	local connectedKickedClients = TGNS.GetClientList(TGNSClientKicker.IsClientKicked)
	if #connectedKickedClients > 0 then
		TGNS.DoFor(connectedKickedClients, function(c)
			TGNS.PlayerAction(c, function(p) md:ToPlayerNotifyInfo(p, chatAdvisory) end)
		end)
		TGNS.ScheduleAction(2, AdviseKickedClients)
	end
end

function TGNSClientKicker.Kick(client, reason, onPreKick, onPostKick, repeatOffensesIsCauseForBan)
	if client ~= nil and not TGNSClientKicker.IsClientKicked(client) then
		local targetSteamId = TGNS.GetClientSteamId(client)
		local targetName = TGNS.GetClientName(client)
		local player = TGNS.GetPlayer(client)
		if player ~= nil then
			table.insert(kickedClients, client)
			TGNS.SendToTeam(player, kTeamReadyRoom)
			if onPreKick ~= nil then
				onPreKick(client, player)
			end
			TGNS.ScheduleAction(1, AdviseKickedClients)
			if onPostKick ~= nil then
				TGNS.ScheduleAction(kickDelayInSeconds + 0.5, function()
					if Shine:IsValidClient(client) then
						onPostKick(targetName)
					end
				end)
			end
			local adminMessage = string.format("Kicking %s: %s", targetName, reason)
			if not TGNS.GetIsClientVirtual(client) then
				md:ToAdminConsole(adminMessage)
				md:ToClientConsole(client, reason)
				if repeatOffensesIsCauseForBan then
					md:ToClientConsole(client, "Note: Too many kicks may create a temporary ban.")
				end
				md:ToClientConsole(client, "Contact TGNS administration (CAA): http://rr.tacticalgamer.com/Community")
			end
			TGNS.ScheduleAction(kickDelayInSeconds, function()
				if repeatOffensesIsCauseForBan then
					kickReasons[targetSteamId] = kickReasons[targetSteamId] or {}
					table.insert(kickReasons[targetSteamId], reason)
					if #kickReasons[targetSteamId] >= REPEAT_KICK_THRESHOLD then
						Shine.Plugins.ban:AddBan(targetSteamId, targetName, REPEAT_KICK_BAN_DURATION_IN_MINUTES * 60, "TGNSClientKicker", 0, TGNS.Join(kickReasons[targetSteamId], "+"))
					end
				end
				TGNS.DisconnectClient(client, reason)
			end)
		else
			TGNS.ScheduleAction(5, function()
				if Shine:IsValidClient(client) then
					TGNSClientKicker.Kick(client, reason, onPreKick, onPostKick)
				end
			end)
		end
	end
end

function TGNSClientKicker.IsClientKicked(client)
	local result = TGNS.Has(kickedClients, client)
	return result
end

local function onTeamJoin(self, player, newTeamNumber, force)
	local client = TGNS.GetClient(player)
	local cancel = TGNS.IsPlayerReadyRoom(player) and TGNSClientKicker.IsClientKicked(client)
	if cancel then
		md:ToPlayerNotifyInfo(player, chatAdvisory)
	end
	if cancel then
		return false
	end
end
TGNS.RegisterEventHook("JoinTeam", onTeamJoin)

local function onPlayerSay(client, networkMessage)
	if TGNSClientKicker.IsClientKicked(client) then
		local teamOnly = networkMessage.teamOnly
		local message = StringTrim(networkMessage.message)
		md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), chatAdvisory)
		return ""
	end
end
TGNS.RegisterEventHook("PlayerSay", onPlayerSay, 5)

-- TGNSScoreboardPlayerHider.RegisterHidingPredicate(function(targetPlayer)
-- 	local targetClient = TGNS.GetClient(targetPlayer)
-- 	local result = targetClient and TGNSClientKicker.IsClientKicked(targetClient)
-- 	return result
-- end)