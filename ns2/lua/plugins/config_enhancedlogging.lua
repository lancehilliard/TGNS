//enhanced logging default config

kDAKRevisions["EnhancedLogging"] = 1.8
local function SetupDefaultConfig(Save)
	if kDAKConfig.EnhancedLogging == nil then
		kDAKConfig.EnhancedLogging = { }
	end
	kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir = "Logs"
	kDAKConfig.EnhancedLogging.kServerTimeZoneAdjustment = 0
	kDAKConfig.EnhancedLogging.kLogWriteDelay = 1
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "EnhancedLogging", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })