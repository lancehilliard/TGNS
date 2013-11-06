local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
    TGNS.ScheduleAction(5, function()
    	if TGNS.GetSecondsSinceServerProcessStarted() < 30 then
    		TGNS.SwitchToMap(TGNS.GetCurrentMapName())
    	end
    end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("hidefullmodlist", Plugin )