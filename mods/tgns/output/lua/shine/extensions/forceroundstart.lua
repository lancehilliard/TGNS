local Plugin = {}

function Plugin:ForceRoundStart()
	TGNS.ForceGameStart()
end

function Plugin:Initialise()
    self.Enabled = true
	local command = self:BindCommand("sh_forceroundstart", "forceroundstart", function(client)
		self:ForceRoundStart()
	end)
	command:Help("Force the beginning of the round.")
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("forceroundstart", Plugin )