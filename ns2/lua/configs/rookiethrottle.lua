Script.Load("lua/TGNSCommon.lua")

local defaultConfig = {}
defaultConfig.kPlayerCountThreshold = 10
defaultConfig.kRookieCountThreshold = 4
defaultConfig.kPreKickChatMessage = "Training in progress. Please come back later!"
defaultConfig.kKickReason = "Training in progress."

TGNS.RegisterPluginConfig("rookiethrottle", "0.1", defaultConfig)