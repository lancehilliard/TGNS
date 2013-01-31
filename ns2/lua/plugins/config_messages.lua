//Messages config

kDAKRevisions["messages"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.Messages = { }
	kDAKConfig.Messages.kMessagesPerTick = 5
	kDAKConfig.Messages.kMessageTickDelay = 6
	kDAKConfig.Messages.kMessageInterval = 10
	kDAKConfig.Messages.kMessageStartDelay = 1
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "messages", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local kMessages = { }
	table.insert(kMessages, "********************************************************************")
	table.insert(kMessages, "****************** Welcome to the XYZ NS2 Servers ******************")
	table.insert(kMessages, "*********** You can also visit our forums at 123.NS2.COM ***********")
	table.insert(kMessages, "********************************************************************")
	local DefaultLangStrings = { }
	DefaultLangStrings["kPeriodicMessages"]	= kMessages
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)