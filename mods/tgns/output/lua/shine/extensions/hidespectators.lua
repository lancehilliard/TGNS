local clientsWhoCanSeeSpectators = {}

local Plugin = {}

function Plugin:ClientConfirmConnect(client)
	local steamId = TGNS.GetClientSteamId(client)
	if (Balance and Balance.GetTotalGamesPlayedBySteamId and Balance.GetTotalGamesPlayedBySteamId(steamId) >= 40) then
		TGNS.InsertDistinctly(clientsWhoCanSeeSpectators, client)
	end
end

function Plugin:Initialise()
    self.Enabled = true
	TGNSScoreboardPlayerHider.RegisterHidingPredicate(function(targetPlayer, message)
		return TGNS.IsTeamNumberSpectator(message.teamNumber) and not TGNS.ClientAction(targetPlayer, TGNS.IsClientAdmin) and not TGNS.IsPlayerSpectator(targetPlayer) and not TGNS.Has(clientsWhoCanSeeSpectators, TGNS.GetClient(targetPlayer))
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("hidespectators", Plugin )