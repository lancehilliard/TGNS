local Plugin = Plugin

TGNS.HookNetworkMessage(Shine.Plugins.autoexec.COMMAND, function(message)
    Shared.ConsoleCommand(message.c)
end)

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end