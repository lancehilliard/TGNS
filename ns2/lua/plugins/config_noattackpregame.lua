//NoAttackPregame config

kDAKRevisions["NoAttackPregame"] = 1.0
local function SetupDefaultConfig(Save)
	if kDAKConfig.NoAttackPregame == nil then
		kDAKConfig.NoAttackPregame = { }
	end
	
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "NoAttackPregame", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })