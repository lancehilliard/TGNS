//Hide Spectators config

kDAKRevisions["hidespectators"] = "1.0"

local function SetupDefaultConfig(Save)
	kDAKConfig.HideSpectators = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "hidespectators", DefaultConfig = SetupDefaultConfig })