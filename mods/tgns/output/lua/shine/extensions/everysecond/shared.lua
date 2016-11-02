local timeOfLastEverySecondHookCallInSeconds = 0
local timeOfLastEveryMinuteHookCallInSeconds = 0

local Plugin = {}

-- Plugin.FOO = "everysecond_FOO"

-- TGNS.RegisterNetworkMessage(Plugin.FOO, {})

function Plugin:Think()
	local secondsSinceLastEverySecondHookCall = TGNS.GetSecondsSinceMapLoaded() - timeOfLastEverySecondHookCallInSeconds
	if secondsSinceLastEverySecondHookCall >= 1 then
		TGNS.ExecuteEventHooks("OnEverySecond", secondsSinceLastEverySecondHookCall)
		timeOfLastEverySecondHookCallInSeconds = TGNS.GetSecondsSinceMapLoaded()
	end

	local secondsSinceLastEveryMinuteHookCall = TGNS.GetSecondsSinceMapLoaded() - timeOfLastEveryMinuteHookCallInSeconds
	if secondsSinceLastEveryMinuteHookCall >= TGNS.ConvertMinutesToSeconds(1) then
		TGNS.ExecuteEventHooks("OnEveryMinute", secondsSinceLastEveryMinuteHookCall)
		timeOfLastEveryMinuteHookCallInSeconds = TGNS.GetSecondsSinceMapLoaded()
	end
end

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("everysecond", Plugin )