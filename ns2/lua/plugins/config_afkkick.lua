//afkkick default config

kDAKRevisions["afkkick"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.AFKKicker = { }
	kDAKConfig.AFKKicker.kAFKKickDelay = 150
	kDAKConfig.AFKKicker.kAFKKickCheckDelay = 5
	kDAKConfig.AFKKicker.kAFKKickMinimumPlayers = 5
	kDAKConfig.AFKKicker.kAFKKickWarning1 = 30
	kDAKConfig.AFKKicker.kAFKKickWarning2 = 10
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "afkkick", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kAFKKickClientMessage"] 					= "You are being kicked for idling for more than %d seconds."
	DefaultLangStrings["kAFKKickMessage"] 							= "%s kicked from the server for idling more than %d seconds."
	DefaultLangStrings["kAFKKickDisconnectReason"] 					= "Kicked from the server for idling more than %d seconds."
	DefaultLangStrings["kAFKKickReturnMessage"] 					= "You are no longer flagged as idle."
	DefaultLangStrings["kAFKKickWarningMessage1"] 					= "You will be kicked in %d seconds for idling."
	DefaultLangStrings["kAFKKickWarningMessage2"] 					= "You will be kicked in %d seconds for idling."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)