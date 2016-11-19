local Plugin = {}

Plugin.CLIENTBADGE = "tgnsbadges_CLIENTBADGE"
Plugin.BADGEDESCRIPTION = "tgnsbadges_BADGEDESCRIPTION"

TGNS.RegisterNetworkMessage(Plugin.CLIENTBADGE, {i="integer", n="string(10)"})
TGNS.RegisterNetworkMessage(Plugin.BADGEDESCRIPTION, {n="string(10)", d="string(250)"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("tgnsbadges", Plugin )