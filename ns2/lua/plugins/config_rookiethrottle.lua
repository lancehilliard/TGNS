//RookieThrottle config

kDAKRevisions["RookieThrottle"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.RookieThrottle == nil then
		kDAKConfig.RookieThrottle = { }
	end
	kDAKConfig.RookieThrottle.kPlayerCountThreshold = 10
	kDAKConfig.RookieThrottle.kRookieCountThreshold = 4
	kDAKConfig.RookieThrottle.kPreKickChatMessage = "Training in progress. Please come back later!"
	kDAKConfig.RookieThrottle.kKickReason = "Training in progress."
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "RookieThrottle", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })