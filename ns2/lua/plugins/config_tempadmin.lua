//TempAdmin config

kDAKRevisions["tempadmin"] = "0.1"

local function SetupDefaultConfig(Save)
	kDAKConfig.TempAdmin = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "tempadmin", DefaultConfig = SetupDefaultConfig })