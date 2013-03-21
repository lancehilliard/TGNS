Script.Load("lua/TGNSCommon.lua")

local notifiedPlayerIds = {}

local originalNS2GRGetPlayerBannedFromCommand = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "GetPlayerBannedFromCommand", function(self, playerId)
	local player = DAK:GetPlayerMatching(playerId)
	local cancel = TGNS.PlayerIsRookie(player) and #TGNS.GetPlayerList() >= 10
	if cancel then
		if not TGNS.Has(notifiedPlayerIds, playerId) then
			TGNS.SendTeamChat(TGNS.GetPlayerTeamNumber(player), string.format("Rookies may not command. %s, help %s any way you can!", TGNS.GetPlayerTeamName(player), TGNS.GetPlayerName(player)), "TGNS")
			table.insert(notifiedPlayerIds, playerId)
			TGNS.ScheduleAction(3, function() TGNS.RemoveAllMatching(notifiedPlayerIds, playerId) end)
		end
	end
	return cancel
end)