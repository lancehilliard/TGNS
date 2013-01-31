//Taglines config

kDAKRevisions["taglines"] = "0.1"

local function SetupDefaultConfig(Save)
	kDAKConfig.Taglines = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "taglines", DefaultConfig = SetupDefaultConfig })