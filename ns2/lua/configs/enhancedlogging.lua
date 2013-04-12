//enhanced logging default config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kEnhancedLoggingSubDir = "Logs"
	DefaultConfig.kLogWriteDelay = 1
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "enhancedlogging", DefaultConfig = SetupDefaultConfig })