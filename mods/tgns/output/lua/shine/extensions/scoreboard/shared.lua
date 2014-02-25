local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "scoreboard.json"

Plugin.SCOREBOARD_DATA = "scoreboard_SCOREBOARD_DATA"

TGNS.RegisterNetworkMessage(Plugin.SCOREBOARD_DATA, {i="integer", p="string(6)", c="boolean"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("scoreboard", Plugin )