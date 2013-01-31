//Balance config

kDAKRevisions["balance"] = "0.1"

local function SetupDefaultConfig(Save)
	kDAKConfig.Balance = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "balance", DefaultConfig = SetupDefaultConfig })