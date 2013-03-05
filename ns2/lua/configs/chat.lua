Script.Load("lua/TGNSCommon.lua")

local defaultConfig = {}
defaultConfig.Channels = {}
defaultConfig.Channels["sv_chat"] = { label = "PMADMIN", triggerChar = "@", help = "<Message>  Sends a message to every admin on the server.", canPM = true }

TGNS.RegisterPluginConfig("chat", "0.1", defaultConfig)