//automapcycle default config

kDAKRevisions["AutoMapCycle"] = 1.0
local function SetupDefaultConfig(Save)
	if kDAKConfig.AutoMapCycle == nil then
		kDAKConfig.AutoMapCycle = { }
	end
	kDAKConfig.AutoMapCycle.kAutoMapCycleDuration = 30
	kDAKConfig.AutoMapCycle.kMaximumPlayers = 0
	kDAKConfig.AutoMapCycle.kUseStandardMapCycle = true
	kDAKConfig.AutoMapCycle.kMapCycleMaps = { "ns2_tram", "ns2_summit", "ns2_veil" }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "AutoMapCycle", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })