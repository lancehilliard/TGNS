//Messages config

DAK.revisions["messages"] = "0.1.302a"

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMessagesPerTick = 5
	DefaultConfig.kMessageTickDelay = 6
	DefaultConfig.kMessageInterval = 10
	DefaultConfig.kMessageStartDelay = 1
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "messages", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local kMessages = { }
	table.insert(kMessages, "********************************************************************")
	table.insert(kMessages, "****************** Welcome to the XYZ NS2 Servers ******************")
	table.insert(kMessages, "*********** You can also visit our forums at 123.NS2.COM ***********")
	table.insert(kMessages, "********************************************************************")
	local DefaultLangStrings = { }
	DefaultLangStrings["PeriodicMessages"]	= kMessages
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)