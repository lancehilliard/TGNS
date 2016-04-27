local lastKnownStatuses = {}

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
    return true
end

-- function Plugin:OnProcessMove(player, input)
-- 	if player then
-- 		local playerIsLookingDown = not TGNS.IsPlayerSpectator(player) and (input.pitch < 1.6 and input.pitch > 1.2)
-- 		local clientIndex = player:GetClientIndex()
-- 		if clientIndex then
-- 			if lastKnownStatuses[clientIndex] ~= playerIsLookingDown then
-- 				TGNS.ExecuteEventHooks("LookDownChanged", player, playerIsLookingDown)
-- 				lastKnownStatuses[clientIndex] = playerIsLookingDown
-- 			end
-- 		end
-- 	end
-- end

-- function Plugin:IsPlayerLookingDown(player)
-- 	local result = player and lastKnownStatuses[player:GetClientIndex()] == true
-- 	return result
-- end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("lookdown", Plugin )