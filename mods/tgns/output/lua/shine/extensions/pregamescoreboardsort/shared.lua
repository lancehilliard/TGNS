local Plugin = {}

Plugin.WINRATE = "pregamescoreboardsort_WINRATE"

TGNS.RegisterNetworkMessage(Plugin.WINRATE, {i="integer",m="float", a="float"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("pregamescoreboardsort", Plugin )