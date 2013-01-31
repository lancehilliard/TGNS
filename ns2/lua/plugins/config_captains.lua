//Captains config

kDAKRevisions["captains"] = "1.0"
local function SetupDefaultConfig(Save)
	kDAKConfig.Captains = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "captains", DefaultConfig = SetupDefaultConfig })