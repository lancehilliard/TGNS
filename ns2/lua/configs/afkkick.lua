//afkkick default config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kAFKKickDelay = 150
	DefaultConfig.kAFKKickCheckDelay = 5
	DefaultConfig.kAFKKickMinimumPlayers = 5
	DefaultConfig.kAFKKickWarning1 = 30
	DefaultConfig.kAFKKickWarning2 = 10
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "afkkick", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["AFKKickClientMessage"] 						= "You are being kicked for idling for more than %d seconds."
	DefaultLangStrings["AFKKickMessage"] 							= "%s kicked from the server for idling more than %d seconds."
	DefaultLangStrings["AFKKickDisconnectReason"] 					= "Kicked from the server for idling more than %d seconds."
	DefaultLangStrings["AFKKickReturnMessage"] 						= "You are no longer flagged as idle."
	DefaultLangStrings["AFKKickWarningMessage1"] 					= "You will be kicked in %d seconds for idling."
	DefaultLangStrings["AFKKickWarningMessage2"] 					= "You will be kicked in %d seconds for idling."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)