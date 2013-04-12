//automapcycle default config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kAutoMapCycleDuration = 30
	DefaultConfig.kMaximumPlayers = 0
	DefaultConfig.kUseStandardMapCycle = true
	DefaultConfig.kMapCycleMaps = { "ns2_tram", "ns2_summit", "ns2_veil" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "automapcycle", DefaultConfig = SetupDefaultConfig })