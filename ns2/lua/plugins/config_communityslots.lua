//communityslots default config

kDAKRevisions["CommunitySlots"] = 0.1

local function SetupDefaultConfig(Save)
	if kDAKConfig.CommunitySlots == nil then
		kDAKConfig.CommunitySlots = { }
	end
	kDAKConfig.CommunitySlots.kMaximumSlots = 24
	kDAKConfig.CommunitySlots.kCommunitySlots = 2
	kDAKConfig.CommunitySlots.kMinimumStrangers = 8
	kDAKConfig.CommunitySlots.kKickedForRoom = "** ): You're being auto-kicked due to reserved slots :( **"
	kDAKConfig.CommunitySlots.kKickedDisconnectReason = "Kicked due to a reserved slot."
	kDAKConfig.CommunitySlots.kServerFull = "Server is full - You must have a reserved slot to connect."
	kDAKConfig.CommunitySlots.kServerFullDisconnectReason = "Server is full."
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "CommunitySlots", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })