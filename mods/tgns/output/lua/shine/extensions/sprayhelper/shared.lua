local Plugin = {}

Plugin.SPRAY_REQUESTED = "sprayhelper_SPRAY_REQUESTED"

TGNS.RegisterNetworkMessage(Plugin.SPRAY_REQUESTED, {})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("sprayhelper", Plugin )