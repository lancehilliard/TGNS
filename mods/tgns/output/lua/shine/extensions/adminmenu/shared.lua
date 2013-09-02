Script.Load("lua/tgns/TGNS.lua")

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "adminmenu.json"

Plugin.ADMIN_MENU_REQUESTED = "adminMenu_ADMIN_MENU_REQUESTED"
Plugin.MENU_DATA = "adminMenu_MENU_DATA"

TGNS.RegisterNetworkMessage(Plugin.ADMIN_MENU_REQUESTED, {commandIndex="integer", argName="string(50)", argValue="string(100)"})
TGNS.RegisterNetworkMessage(Plugin.MENU_DATA, {commandIndex="integer", argName="string(20)", pageId="string(20)", pageName="string(30)", backPageId="string(20)", chatCmd="string(10)", buttonsJson = "string(850)"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("adminmenu", Plugin )