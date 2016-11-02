local Plugin = {}

Plugin.RECORDING_BOUNDARY = "recordinghelper_RECORDING_BOUNDARY"

TGNS.RegisterNetworkMessage(Plugin.RECORDING_BOUNDARY, {b="string(100)",d="float", t="string(100)", p="string(30)", s="integer"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("recordinghelper", Plugin )