local Plugin = {}

-- Plugin.FOO = "restartwhenempty_FOO"

-- TGNS.RegisterNetworkMessage(Plugin.FOO, {})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("restartwhenempty", Plugin )