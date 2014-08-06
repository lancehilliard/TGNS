Script.Load("lua/tgns/TGNS.lua")

local Plugin = {}
Plugin.MINIMUM_CHAT_WIDTH_PERCENTAGE = 10
Plugin.MAXIMUM_CHAT_WIDTH_PERCENTAGE = 100


Plugin.WRAPLENGTH_DATA = "wraplength_WRAPLENGTH_DATA"

TGNS.RegisterNetworkMessage(Plugin.WRAPLENGTH_DATA, {l="integer"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("wraplength", Plugin )