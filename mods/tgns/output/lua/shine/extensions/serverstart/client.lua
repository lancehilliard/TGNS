local Plugin = Plugin

TGNS.HookNetworkMessage(Plugin.RECONNECT, function(message)
	Shine.Plugins.crashreconnect:SetReconnectAlreadyInProgress()
	Shine.Plugins.serverstart:Reconnect(5)
end)

function Plugin:Reconnect(additionalDelayInSeconds)
	local delayInSeconds = 7 + additionalDelayInSeconds + math.random() * 3
	Shine.Timer.Simple(delayInSeconds, function() 
		Shared.ConsoleCommand("connect tgns.tacticalgamer.com")
	end)
end

function Plugin:Initialise()
	self.Enabled = true

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end