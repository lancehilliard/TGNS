//reservedslots config

kDAKRevisions["reservedslots"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.ReservedSlots = { }
	kDAKConfig.ReservedSlots.kReservedSlots = 2
	kDAKConfig.ReservedSlots.kMinimumSlots = 1
	kDAKConfig.ReservedSlots.kDelayedSyncTime = 3
	kDAKConfig.ReservedSlots.kDelayedKickTime = 2
	kDAKConfig.ReservedSlots.kReservePassword = ""
	kDAKConfig.ReservedSlots.kReserveSlotKickedDisconnectReason = "Kicked due to a reserved slot."
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "reservedslots", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kReserveSlotServerFullDisconnectReason"] 	= "Server is full."
	DefaultLangStrings["kReserveSlotKickedDisconnectReason"] 		= "Kicked due to a reserved slot."
	DefaultLangStrings["kReserveSlotServerFull"] 					= "Server is full - You must have a reserved slot to connect."
	DefaultLangStrings["kReserveSlotKickedForRoom"] 				= "**You're being kicked due to a reserved slot, this is automatically determined**"
	DefaultLangStrings["kReserveSlotGranted"] 						= "Player %s added to reserve players list."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)