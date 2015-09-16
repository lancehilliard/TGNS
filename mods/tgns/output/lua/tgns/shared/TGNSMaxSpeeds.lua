TGNS = TGNS or {}

function TGNS.ModifyAlienMaxSpeeds(alienMaxSpeedModifier)
    local originalOnosGetMaxSpeed
	originalOnosGetMaxSpeed = Class_ReplaceMethod("Onos", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = alienMaxSpeedModifier(originalOnosGetMaxSpeed(alienUnitSelf, possible))
		return result
	end)

    local originalFadeGetMaxSpeed
	originalFadeGetMaxSpeed = Class_ReplaceMethod("Fade", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = alienMaxSpeedModifier(originalFadeGetMaxSpeed(alienUnitSelf, possible))
		return result
	end)

    local originalLerkGetMaxSpeed
	originalLerkGetMaxSpeed = Class_ReplaceMethod("Lerk", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = alienMaxSpeedModifier(originalLerkGetMaxSpeed(alienUnitSelf, possible))
		return result
	end)

    local originalGorgeGetMaxSpeed
	originalGorgeGetMaxSpeed = Class_ReplaceMethod("Gorge", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = alienMaxSpeedModifier(originalGorgeGetMaxSpeed(alienUnitSelf, possible))
		return result
	end)

    local originalSkulkGetMaxSpeed
	originalSkulkGetMaxSpeed = Class_ReplaceMethod("Skulk", "GetMaxSpeed", function(alienUnitSelf, possible)
		local result = alienMaxSpeedModifier(originalSkulkGetMaxSpeed(alienUnitSelf, possible))
		return result
	end)
end