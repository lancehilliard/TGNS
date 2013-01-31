//unstuck config

kDAKRevisions["unstuck"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.Unstuck = { }
	kDAKConfig.Unstuck.kMinimumWaitTime = 5
	kDAKConfig.Unstuck.kTimeBetweenUntucks = 30
	kDAKConfig.Unstuck.kUnstuckAmount = 0.5
	kDAKConfig.Unstuck.kUnstuckChatCommands = { "stuck", "unstuck", "/stuck", "/unstuck" }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "unstuck", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kUnstuckMoved"] 							= "You moved since issuing unstuck command?"
	DefaultLangStrings["kUnstuck"] 									= "Unstuck!"
	DefaultLangStrings["kUnstuckIn"] 								= "You will be unstuck in %s seconds."
	DefaultLangStrings["kUnstuckRecently"] 							= "You have unstucked too recently, please wait %.1f seconds."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)