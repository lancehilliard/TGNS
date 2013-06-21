Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSScoreboardPlayerHider.lua")

TGNSScoreboardPlayerHider.RegisterHidingPredicate(function(targetPlayer, message)
	return TGNS.IsTeamNumberSpectator(message.teamNumber) and not TGNS.ClientAction(targetPlayer, TGNS.IsClientAdmin)
end)