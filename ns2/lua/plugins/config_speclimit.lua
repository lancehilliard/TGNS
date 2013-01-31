//SpecLimit config

kDAKRevisions["speclimit"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.SpecLimit = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "speclimit", DefaultConfig = SetupDefaultConfig })