//autoconcede default config

kDAKRevisions["autoconcede"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.AutoConcede = { }
	kDAKConfig.AutoConcede.kImbalanceDuration = 30
	kDAKConfig.AutoConcede.kImbalanceNotification = 10
	kDAKConfig.AutoConcede.kImbalanceAmount = 4
	kDAKConfig.AutoConcede.kMinimumPlayers = 6
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "autoconcede", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kConcedeMessage"] 							= "Round ended due to imbalanced teams."
	DefaultLangStrings["kConcedeCancelledMessage"] 					= "Teams within autoconcede limits."
	DefaultLangStrings["kConcedeWarningMessage"] 					= "Round will end in %s seconds due to imbalanced teams."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)