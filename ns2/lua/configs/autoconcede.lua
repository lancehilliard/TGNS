//autoconcede default config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kImbalanceDuration = 30
	DefaultConfig.kImbalanceNotification = 10
	DefaultConfig.kImbalanceAmount = 4
	DefaultConfig.kMinimumPlayers = 6
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "autoconcede", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["ConcedeMessage"] 							= "Round ended due to imbalanced teams."
	DefaultLangStrings["ConcedeCancelledMessage"] 					= "Teams within autoconcede limits."
	DefaultLangStrings["ConcedeWarningMessage"] 					= "Round will end in %s seconds due to imbalanced teams."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)