Script.Load("lua/TGNSCommon.lua")

local notifiedPlayerIds = {}

local originalGetIsPlayerValidForCommander
originalGetIsPlayerValidForCommander = TGNS.ReplaceClassMethod("CommandStructure", "GetIsPlayerValidForCommander", function(self, player)
	local result = originalGetIsPlayerValidForCommander(self, player)
	if result then
		local numberOfNonRookiesOnTeam = #TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return TGNS.PlayersAreTeammates(player, p) and not TGNS.PlayerIsRookie(p) end)
		local numberOfAliveTeammates = #TGNS.Where(TGNS.GetPlayersOnSameTeam(player), TGNS.IsPlayerAlive)
		local rookieShouldBePreventedFromCommanding = TGNS.PlayerIsRookie(player) and numberOfNonRookiesOnTeam >= 4 and numberOfAliveTeammates > 2
		if rookieShouldBePreventedFromCommanding then
			if not TGNS.Has(notifiedPlayerIds, playerId) then
				TGNS.SendTeamChat(TGNS.GetPlayerTeamNumber(player), string.format("%s! Rookies will fight from the ground this game. Help them!", TGNS.GetPlayerTeamName(player)), "TGNS")
				table.insert(notifiedPlayerIds, playerId)
				TGNS.ScheduleAction(3, function() TGNS.RemoveAllMatching(notifiedPlayerIds, playerId) end)
			end
		end
		result = not rookieShouldBePreventedFromCommanding
	end
	return result
end)
