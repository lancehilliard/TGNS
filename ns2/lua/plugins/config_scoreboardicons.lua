//Scoreboard Icons config

kDAKRevisions["scoreboardicons"] = "1.0"
local function SetupDefaultConfig(Save)
	kDAKConfig.ScoreboardIcons = { }
	kDAKConfig.ScoreboardIcons.GroupIcons = {
			{group = "admin_group", icon = "\226\152\133", sort = 1},
			{group = "mod_group", icon = "MOD", sort = 2}
		}
	kDAKConfig.ScoreboardIcons.CatchAll = "\239\188\159"
	kDAKConfig.ScoreboardIcons.AFK = "!"
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "scoreboardicons", DefaultConfig = SetupDefaultConfig })