Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSScoreboardPlayerHider.lua")

TGNSClientKicker = {}
local kickedClients = {}
local chatAdvisory = "Kicked. See console for details."
local messagePrefix = "KICK"
local kickDelayInSeconds = 5

local function AdviseKickedClients()
	local connectedKickedClients = TGNS.GetClientList(TGNSClientKicker.IsClientKicked)
	if #connectedKickedClients > 0 then
		TGNS.DoFor(connectedKickedClients, function(c)
			TGNS.PlayerAction(c, function(p) TGNS.SendChatMessage(p, chatAdvisory, messagePrefix) end)
		end)
		TGNS.ScheduleAction(2, AdviseKickedClients)
	end
end

function TGNSClientKicker.Kick(client, reason, onPreKick, onPostKick)
	if client ~= nil and not TGNSClientKicker.IsClientKicked(client) then
		local player = TGNS.GetPlayer(client)
		if player ~= nil then
			table.insert(kickedClients, client)
			TGNS.SendToTeam(player, kTeamReadyRoom)
			if onPreKick ~= nil then
				onPreKick(client, player)
			end
			TGNS.ScheduleAction(1, AdviseKickedClients)
			if onPostKick ~= nil then
				TGNS.ScheduleAction(kickDelayInSeconds + 0.5, function() onPostKick(client, player) end)
			end
			local adminMessage = string.format("Kicking %s: %s", TGNS.GetClientName(client), reason)
			TGNS.SendAdminConsoles(adminMessage, messagePrefix)
			TGNS.ConsolePrint(client, reason, messagePrefix)
			TGNS.ScheduleAction(kickDelayInSeconds, function()
				TGNS.DisconnectClient(client, reason)
				TGNS.UpdateAllScoreboards()
			end)
			TGNS.UpdateAllScoreboards()
		else
			TGNS.ScheduleAction(5, function() TGNSClientKicker.Kick(client, reason, onPreKick, onPostKick) end)
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
		TGNS.SendChatMessage(player, chatAdvisory, messagePrefix)
	end
	return cancel
end
TGNS.RegisterEventHook("OnTeamJoin", onTeamJoin)

local function onChatClient(client, networkMessage)
	local cancel = TGNSClientKicker.IsClientKicked(client)
	if cancel then
		local teamOnly = networkMessage.teamOnly
		local message = StringTrim(networkMessage.message)
		TGNS.SendChatMessage(TGNS.GetPlayer(client), chatAdvisory, messagePrefix)
	end
	return cancel
end
TGNS.RegisterNetworkMessageHook("ChatClient", onChatClient, 5)

TGNSScoreboardPlayerHider.RegisterHidingPredicate(TGNSClientKicker.IsClientKicked)