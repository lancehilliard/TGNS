// Block Mutes config

kDAKRevisions["blockmutes"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.BlockMutes = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "blockmutes", DefaultConfig = SetupDefaultConfig })