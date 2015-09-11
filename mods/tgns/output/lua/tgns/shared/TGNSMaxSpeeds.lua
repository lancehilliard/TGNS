TGNS = TGNS or {}

function TGNS.SetAlienMaxSpeeds(alienMaxSpeedMultiplier)
    local originalOnosGetMaxSpeed
	originalOnosGetMaxSpeed = Class_ReplaceMethod("Onos", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = originalOnosGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedMultiplier
		return result
	end)

    local originalFadeGetMaxSpeed
	originalFadeGetMaxSpeed = Class_ReplaceMethod("Fade", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = originalFadeGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedMultiplier
		return result
	end)

    local originalLerkGetMaxSpeed
	originalLerkGetMaxSpeed = Class_ReplaceMethod("Lerk", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = originalLerkGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedMultiplier
		return result
	end)

    local originalGorgeGetMaxSpeed
	originalGorgeGetMaxSpeed = Class_ReplaceMethod("Gorge", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = originalGorgeGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedMultiplier
		return result
	end)

    local originalSkulkGetMaxSpeed
	originalSkulkGetMaxSpeed = Class_ReplaceMethod("Skulk", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = originalSkulkGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedMultiplier
		return result
	end)
end