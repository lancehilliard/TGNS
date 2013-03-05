//GUIMenuBase config

DAK.revisions["guimenubase"] = "0.1.302a"

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMenuUpdateRate = 5
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "guimenubase", DefaultConfig = SetupDefaultConfig })