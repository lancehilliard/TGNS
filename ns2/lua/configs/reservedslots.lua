//reservedslots config

DAK.revisions["reservedslots"] = "0.1.302a"

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMaximumSlots = 0
	DefaultConfig.kReservedSlots = 2
	DefaultConfig.kMinimumSlots = 1
	DefaultConfig.kDelayedSyncTime = 1
	DefaultConfig.kDelayedKickTime = 2
	DefaultConfig.kReservePassword = ""
	DefaultConfig.kReserveSlotKickedDisconnectReason = "Kicked due to a reserved slot."
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "reservedslots", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["ReserveSlotServerFullDisconnectReason"] 	= "Server is full."
	DefaultLangStrings["ReserveSlotKickedDisconnectReason"] 		= "Kicked due to a reserved slot."
	DefaultLangStrings["ReserveSlotServerFull"] 					= "Server is full - You must have a reserved slot to connect."
	DefaultLangStrings["ReserveSlotKickedForRoom"] 					= "**You're being kicked due to a reserved slot, this is automatically determined**"
	DefaultLangStrings["ReserveSlotGranted"] 						= "Player %s added to reserve players list."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)