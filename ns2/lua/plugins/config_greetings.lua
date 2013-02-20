//Greetings config

kDAKRevisions["greetings"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.Greetings = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "greetings", DefaultConfig = SetupDefaultConfig })