Script.Load("lua/TGNSCommon.lua")

local notifiedPlayerIds = {}

local originalNS2GRGetPlayerBannedFromCommand = TGNS.ReplaceClassMethod(DAK.config.loader.GamerulesClassName, "GetPlayerBannedFromCommand", function(self, playerId)
	local player = DAK:GetPlayerMatching(playerId)
	local numberOfNonRookiesOnTeam = #TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return TGNS.PlayersAreTeammates(player, p) and not TGNS.PlayerIsRookie(p) end)
	local cancel = TGNS.PlayerIsRookie(player) and numberOfNonRookiesOnTeam >= 4
	if cancel then
		if not TGNS.Has(notifiedPlayerIds, playerId) then
			TGNS.SendTeamChat(TGNS.GetPlayerTeamNumber(player), string.format("%s! Rookies will fight from the ground this game. Help them!", TGNS.GetPlayerTeamName(player)), "TGNS")
			table.insert(notifiedPlayerIds, playerId)
			TGNS.ScheduleAction(3, function() TGNS.RemoveAllMatching(notifiedPlayerIds, playerId) end)
		end
	end
	return cancel
end)