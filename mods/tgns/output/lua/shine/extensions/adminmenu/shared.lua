Script.Load("lua/tgns/TGNS.lua")

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "adminmenu.json"

Plugin.ADMIN_MENU_REQUESTED = "adminMenu_ADMIN_MENU_REQUESTED"
Plugin.MENU_DATA = "adminMenu_MENU_DATA"

TGNS.RegisterNetworkMessage(Plugin.ADMIN_MENU_REQUESTED, {commandName="string(50)", argName="string(50)", argValue="string(100)"})
TGNS.RegisterNetworkMessage(Plugin.MENU_DATA, {argName="string(50)", pageId="string(50)", pageName="string(50)", backPageId="string(50)", helpText="string(100)", buttonsJson = "string(650)"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("adminmenu", Plugin )