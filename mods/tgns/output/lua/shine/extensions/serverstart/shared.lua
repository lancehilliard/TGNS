local Plugin = {}

Plugin.RECONNECT = "serverstart_RECONNECT"

TGNS.RegisterNetworkMessage(Plugin.RECONNECT, {})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("serverstart", Plugin )