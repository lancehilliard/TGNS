//enhanced logging default config

kDAKRevisions["enhancedlogging"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.EnhancedLogging = { }
	kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir = "Logs"
	kDAKConfig.EnhancedLogging.kServerTimeZoneAdjustment = 0
	kDAKConfig.EnhancedLogging.kLogWriteDelay = 1
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "enhancedlogging", DefaultConfig = SetupDefaultConfig })