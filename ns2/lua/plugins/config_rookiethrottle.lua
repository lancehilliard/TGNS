//RookieThrottle config

kDAKRevisions["rookiethrottle"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.RookieThrottle = { }
	kDAKConfig.RookieThrottle.kPlayerCountThreshold = 10
	kDAKConfig.RookieThrottle.kRookieCountThreshold = 4
	kDAKConfig.RookieThrottle.kPreKickChatMessage = "Training in progress. Please come back later!"
	kDAKConfig.RookieThrottle.kKickReason = "Training in progress."
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "rookiethrottle", DefaultConfig = SetupDefaultConfig })