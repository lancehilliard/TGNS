local Plugin = {}

-- Plugin.FOO = "gorgetunnelhelper_FOO"

-- TGNS.RegisterNetworkMessage(Plugin.FOO, {x="integer",y="integer"});

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("gorgetunnelhelper", Plugin )