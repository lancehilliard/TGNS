local Plugin = Plugin

function Plugin:Initialise()
	self.Enabled = true
    TGNS.HookNetworkMessage(self.COMMAND, function(message)
        Shared.ConsoleCommand(message.c)
    end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end