-- local lastKnownLocations = {}

-- local Plugin = {}

-- function Plugin:OnProcessMove(player, input)
-- 	local location = player:GetLocationName()
-- 	if location ~= lastKnownLocations[player] then
-- 		lastKnownLocations[player] = location
-- 		TGNS.ExecuteEventHooks("PlayerLocationChanged", player, location)
-- 	end
-- end

-- function Plugin:Initialise()
--     self.Enabled = true
--     return true
-- end

-- function Plugin:Cleanup()
--     --Cleanup your extra stuff like timers, data etc.
--     self.BaseClass.Cleanup( self )
-- end

-- Shine:RegisterExtension("playerlocationchanged", Plugin )