Script.Load("lua/tgns/TGNS.lua")

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "adminmenu.json"

Plugin.ADMIN_MENU_REQUESTED = "adminMenu_ADMIN_MENU_REQUESTED"
Plugin.MENU_DATA = "adminMenu_MENU_DATA"
Plugin.HELP_TEXT = "adminMenu_HELP_TEXT"

TGNS.RegisterNetworkMessage(Plugin.ADMIN_MENU_REQUESTED, {commandIndex="integer", argName="string(50)", argValue="string(100)"})
TGNS.RegisterNetworkMessage(Plugin.MENU_DATA, {commandIndex="integer", argName="string(20)", pageId="string(30)", pageName="string(30)", backPageId="string(30)", chatCmd="string(10)", buttonsJson = "string(830)"})
TGNS.RegisterNetworkMessage(Plugin.HELP_TEXT, {pageName="string(30)", helpText="string(100)"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("adminmenu", Plugin )