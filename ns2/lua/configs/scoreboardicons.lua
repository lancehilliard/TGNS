Script.Load("lua/TGNSCommon.lua")
local defaultConfig = {}
defaultConfig.GroupIcons = {
		{group = "admin_group", icon = "\226\152\133", sort = 1},
		{group = "mod_group", icon = "MOD", sort = 2}
	}
defaultConfig.CatchAll = "\239\188\159"
defaultConfig.AFK = "!"
TGNS.RegisterPluginConfig("scoreboardicons", "1.0", defaultConfig)