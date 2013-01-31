//NotifyAdminOnMutePlayer config

kDAKRevisions["notifyAdminOnMutePlayer"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.NotifyAdminOnMutePlayer = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "notifyAdminOnMutePlayer", DefaultConfig = SetupDefaultConfig })