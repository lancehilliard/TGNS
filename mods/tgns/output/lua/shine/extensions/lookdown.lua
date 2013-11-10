local lastKnownStatuses = {}

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:OnProcessMove(player, input)
	local playerIsLookingDown = not TGNS.IsPlayerSpectator(player) and (input.pitch < 1.6 and input.pitch > 1.2)
	if lastKnownStatuses[player] ~= playerIsLookingDown then
		TGNS.ExecuteEventHooks("LookDownChanged", player, playerIsLookingDown)
		lastKnownStatuses[player] = playerIsLookingDown
	end
end

function Plugin:IsPlayerLookingDown(player)
	local result = lastKnownStatuses[player] == true
	return result
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("lookdown", Plugin )