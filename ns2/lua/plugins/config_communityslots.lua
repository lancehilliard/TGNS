//communityslots default config

kDAKRevisions["CommunitySlots"] = 0.1

local function SetupDefaultConfig(Save)
	if kDAKConfig.CommunitySlots == nil then
		kDAKConfig.CommunitySlots = { }
	end
	kDAKConfig.CommunitySlots.kMaximumSlots = 24
	kDAKConfig.CommunitySlots.kCommunitySlots = 2
	kDAKConfig.CommunitySlots.kMinimumStrangers = 8
	kDAKConfig.CommunitySlots.kBumpReason = "%s was bumped by reserved slots. This server is full at %s/%s."
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "CommunitySlots", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })