local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	local command = self:BindCommand("sh_forceroundstart", "forceroundstart", function(client)
		local gamerules = GetGamerules()
		gamerules:ResetGame()
		gamerules:SetGameState(kGameState.Countdown)      
		TGNS.DoFor(TGNS.GetPlayerList(), function(p) p:ResetScores() end)
		gamerules.countdownTime = kCountDownLength 
		gamerules.lastCountdownPlayed = nil 
	end)
	command:Help("Force the beginning of the round.")
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("forceroundstart", Plugin )