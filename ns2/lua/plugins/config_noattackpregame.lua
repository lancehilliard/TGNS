//NoAttackPregame config

kDAKRevisions["noattackpregame"] = "1.0"
local function SetupDefaultConfig(Save)
	kDAKConfig.NoAttackPregame = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "noattackpregame", DefaultConfig = SetupDefaultConfig })