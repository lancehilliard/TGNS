//unstuck config

DAK.revisions["unstuck"] = "0.1.302a"

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMinimumWaitTime = 5
	DefaultConfig.kTimeBetweenUntucks = 30
	DefaultConfig.kUnstuckAmount = 1
	DefaultConfig.kUnstuckChatCommands = { "stuck", "unstuck", "/stuck", "/unstuck" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "unstuck", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["UnstuckMoved"] 								= "You moved since issuing unstuck command?"
	DefaultLangStrings["Unstuck"] 									= "Unstuck!"
	DefaultLangStrings["UnstuckIn"] 								= "You will be unstuck in %s seconds."
	DefaultLangStrings["UnstuckRecently"] 							= "You have unstucked too recently, please wait %.1f seconds."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)