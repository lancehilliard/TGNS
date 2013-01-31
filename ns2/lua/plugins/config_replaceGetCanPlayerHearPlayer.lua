//replaceGetCanPlayerHearPlayer config

kDAKRevisions["replaceGetCanPlayerHearPlayer"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.replaceGetCanPlayerHearPlayer = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "replaceGetCanPlayerHearPlayer", DefaultConfig = SetupDefaultConfig })