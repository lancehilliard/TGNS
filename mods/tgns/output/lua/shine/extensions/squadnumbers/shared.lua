local Plugin = {}

Plugin.GAME_IN_PROGRESS = "squadnumbers_GAME_IN_PROGRESS"
Plugin.SQUAD_REQUESTED = "squadnumbers_SQUAD_REQUESTED"
Plugin.SQUAD_CONFIRMED = "squadnumbers_SQUAD_CONFIRMED"

TGNS.RegisterNetworkMessage(Plugin.GAME_IN_PROGRESS, {b="boolean"})
TGNS.RegisterNetworkMessage(Plugin.SQUAD_REQUESTED, {c="integer",d="integer"});
TGNS.RegisterNetworkMessage(Plugin.SQUAD_CONFIRMED, {c="integer",s="integer"});

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("squadnumbers", Plugin )