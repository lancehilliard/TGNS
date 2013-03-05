Script.Load("lua/TGNSCommon.lua")

local defaultConfig = {}
defaultConfig.kPrintableNamesWarnMessage = "Your name must use only printable characters."
defaultConfig.kPrintableNamesKickMessage = "Player names must use all printable characters."

TGNS.RegisterPluginConfig("printablenames", "0.1", defaultConfig)