local Plugin = {}
local commands = { "sh_timeleft", "sh_nextmap" }

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.DoFor(TGNS.GetClientList(), function(c)
		TGNS.ScheduleAction(10, function() TGNS.ExecuteClientCommand(c, "sh_nextmap") end)
	end)
end

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("endgamecommands", Plugin )