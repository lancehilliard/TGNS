Script.Load("lua/TGNSCommon.lua")

local defaultConfig = {}
defaultConfig.kProhibitedNames = {"NSPlayer"}
defaultConfig.kProhibitedNamesWarnMessage = "Your player name is not allowed. Choose another name to stay."
defaultConfig.kProhibitedNamesKickMessage = "Player name not allowed."

TGNS.RegisterPluginConfig("prohibitednames", "0.1", defaultConfig)