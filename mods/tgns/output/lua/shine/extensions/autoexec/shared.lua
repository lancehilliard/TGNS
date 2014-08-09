Script.Load("lua/tgns/TGNS.lua")

local Plugin = {}
Plugin.COMMAND = "autoexec_Command"

TGNS.RegisterNetworkMessage(Plugin.COMMAND, {c="string(30)"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("autoexec", Plugin )