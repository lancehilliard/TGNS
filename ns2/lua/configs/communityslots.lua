Script.Load("lua/TGNSCommon.lua")

local defaultConfig = {}
defaultConfig.kMaximumSlots = 24
defaultConfig.kCommunitySlots = 2
defaultConfig.kMinimumStrangers = 4
defaultConfig.kMinimumPrimerOnlys = 4
defaultConfig.kBumpReason = "%s was bumped by reserved slots. This server is full at %s/%s."
TGNS.RegisterPluginConfig("communityslots", "0.1", defaultConfig)