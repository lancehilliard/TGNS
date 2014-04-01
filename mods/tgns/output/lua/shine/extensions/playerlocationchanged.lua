local lastKnownLocationNames = {}

local Plugin = {}

function Plugin:OnProcessMove(player, input)
	local locationName = player:GetLocationName()
	if locationName ~= lastKnownLocationNames[player] then
		lastKnownLocationNames[player] = locationName
		TGNS.ExecuteEventHooks("PlayerLocationChanged", player, locationName)
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

Shine:RegisterExtension("playerlocationchanged", Plugin )