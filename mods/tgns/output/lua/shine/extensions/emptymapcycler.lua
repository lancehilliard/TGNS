local mapMightBeBroken = true

local Plugin = {}

function Plugin:ClientConfirmConnect()
	mapMightBeBroken = false
end

function Plugin:Initialise()
    self.Enabled = true
    TGNS.ScheduleAction(120, function()
    	if mapMightBeBroken == true then
            local nextMapName = TGNS.GetNextMapName()
            TGNS.DebugPrint(string.format("emptymapcycler cycling to %s...", nextMapName), true)
	    	TGNS.SwitchToMap(nextMapName)
    	end
    end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("emptymapcycler", Plugin )