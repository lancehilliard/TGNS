//BetterKnownAs config

kDAKRevisions["betterknownas"] = "0.1"

local function SetupDefaultConfig(Save)
	kDAKConfig.BetterKnownAs = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "betterknownas", DefaultConfig = SetupDefaultConfig })