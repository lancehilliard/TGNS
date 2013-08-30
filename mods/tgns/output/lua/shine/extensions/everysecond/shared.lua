local timeOfLastHookCallInSeconds = 0

local Plugin = {}

function Plugin:Think()
	local secondsSinceLastHookCall = TGNS.GetSecondsSinceMapLoaded() - timeOfLastHookCallInSeconds
	if secondsSinceLastHookCall >= 1 then
		TGNS.ExecuteEventHooks("OnEverySecond", secondsSinceLastHookCall)
		timeOfLastHookCallInSeconds = TGNS.GetSecondsSinceMapLoaded()
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

Shine:RegisterExtension("everysecond", Plugin)