local lastKnownAfkStatuses = {}

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:OnProcessMove(player, input)
	local playerIsAfk = TGNS.IsPlayerAFK(player)
	if lastKnownAfkStatuses[player] ~= playerIsAfk then
		TGNS.ExecuteEventHooks("AfkChanged", player, playerIsAfk)
		lastKnownAfkStatuses[player] = playerIsAfk
	end
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("afkchanged", Plugin )