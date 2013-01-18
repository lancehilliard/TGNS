//Scoreboard Icons config

kDAKRevisions["ScoreboardIcons"] = 1.0
local function SetupDefaultConfig(Save)
	if kDAKConfig.ScoreboardIcons == nil then
		kDAKConfig.ScoreboardIcons = { }
	end
		kDAKConfig.ScoreboardIcons.GroupIcons = {}
		kDAKConfig.ScoreboardIcons.GroupIcons["admin_group"] = "\226\152\133"
		kDAKConfig.ScoreboardIcons.CatchAll = "\239\188\159"
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "ScoreboardIcons", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })