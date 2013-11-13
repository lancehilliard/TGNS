-- local lastKnownStatuses = {}

-- local Plugin = {}

-- function Plugin:Initialise()
--     self.Enabled = true
--     return true
-- end

-- function Plugin:OnProcessMove(player, input)
-- 	local status = bit.band(input.commands, Move.Reload) ~= 0 and bit.band(input.commands, Move.Use) ~= 0
-- 	if lastKnownStatuses[player] ~= status then
-- 		TGNS.ExecuteEventHooks("RelUseChanged", player, status)
-- 		lastKnownStatuses[player] = status
-- 	end
-- end

-- function Plugin:IsPlayerRelUsing(player)
-- 	local result = lastKnownStatuses[player] == true
-- 	return result
-- end

-- function Plugin:Cleanup()
--     --Cleanup your extra stuff like timers, data etc.
--     self.BaseClass.Cleanup( self )
-- end

-- Shine:RegisterExtension("reluse", Plugin )