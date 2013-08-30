TGNSClientKicker = {}
local kickedClients = {}
local chatAdvisory = "Kicked. See console for details."
local kickDelayInSeconds = 5
local md = TGNSMessageDisplayer.Create("KICK")

local function AdviseKickedClients()
	local connectedKickedClients = TGNS.GetClientList(TGNSClientKicker.IsClientKicked)
	if #connectedKickedClients > 0 then
		TGNS.DoFor(connectedKickedClients, function(c)
			TGNS.PlayerAction(c, function(p) md:ToPlayerNotifyInfo(p, chatAdvisory) end)
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
			md:ToAdminConsole(adminMessage)
			md:ToClientConsole(client, reason)
			md:ToClientConsole(client, "Contact TGNS administration: http://www.tacticalgamer.com/natural-selection-contact-admin/") 
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

TGNSScoreboardPlayerHider.RegisterHidingPredicate(function(targetPlayer)
	local targetClient = TGNS.GetClient(targetPlayer)
	local result = targetClient and TGNSClientKicker.IsClientKicked(targetClient)
	return result
end)