//serverredirect default config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.Servers = { "127.0.0.1:27015" }
	DefaultConfig.SwitchServersChatCommands = { "switchserver" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "serverredirect", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["RedirectMessage"] 							= "You are being re-directed to %s."
	DefaultLangStrings["AvailableServers"] 							= "Server - %s, Number %s"
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)