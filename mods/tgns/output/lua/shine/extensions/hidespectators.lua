local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	TGNSScoreboardPlayerHider.RegisterHidingPredicate(function(targetPlayer, message)
		return TGNS.IsTeamNumberSpectator(message.teamNumber) and not TGNS.ClientAction(targetPlayer, TGNS.IsClientAdmin) and not TGNS.IsPlayerSpectator(targetPlayer)
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("hidespectators", Plugin )