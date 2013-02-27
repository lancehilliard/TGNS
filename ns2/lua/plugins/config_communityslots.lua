//communityslots default config

kDAKRevisions["communityslots"] = "0.1"

local function SetupDefaultConfig(Save)
	kDAKConfig.CommunitySlots = { }
	kDAKConfig.CommunitySlots.kMaximumSlots = 24
	kDAKConfig.CommunitySlots.kCommunitySlots = 2
	kDAKConfig.CommunitySlots.kMinimumStrangers = 4
	kDAKConfig.CommunitySlots.kMinimumPrimerOnlys = 4
	kDAKConfig.CommunitySlots.kBumpReason = "%s was bumped by reserved slots. This server is full at %s/%s."
end
DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "communityslots", DefaultConfig = SetupDefaultConfig })