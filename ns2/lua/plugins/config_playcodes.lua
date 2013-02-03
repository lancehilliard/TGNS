//PlayCodes config

kDAKRevisions["playcodes"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.PlayCodes = { }
end
DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "playcodes", DefaultConfig = SetupDefaultConfig })