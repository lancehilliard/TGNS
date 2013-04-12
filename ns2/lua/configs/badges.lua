//badges

local function SetupDefaultConfig()
	//DAK.config.Badges = { }
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "badges", DefaultConfig = SetupDefaultConfig })