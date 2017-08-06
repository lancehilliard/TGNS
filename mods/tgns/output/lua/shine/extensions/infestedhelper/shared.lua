local Plugin = {}

-- Plugin.FOO = "infestedhelper_FOO"

-- TGNS.RegisterNetworkMessage(Plugin.FOO, {})

function Plugin:IsSaturdayNightFever()
	local result = (TGNS.GetAbbreviatedDayOfWeek() == "Sat" and TGNS.GetCurrentHour() >= 23 and TGNS.GetCurrentMinute() >= 46) or (TGNS.GetAbbreviatedDayOfWeek() == "Sun" and TGNS.GetCurrentHour() <= 6)
	return result
end

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("infestedhelper", Plugin )