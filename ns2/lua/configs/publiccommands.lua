Script.Load("lua/TGNSCommon.lua")

local defaultConfig = {}
defaultConfig.Commands = {}
defaultConfig.Commands["timeleft"] = { }
defaultConfig.Commands["timeleft"].command = "timeleft"
defaultConfig.Commands["timeleft"].throttle = 30
defaultConfig.Commands["nextmap"] = { }
defaultConfig.Commands["nextmap"].command = "nextmap"
defaultConfig.Commands["nextmap"].throttle = 30

TGNS.RegisterPluginConfig("publiccommands", "0.1", defaultConfig)