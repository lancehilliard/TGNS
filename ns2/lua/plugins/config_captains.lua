//Captains config

kDAKRevisions["Captains"] = 1.0
local function SetupDefaultConfig(Save)
	if kDAKConfig.Captains == nil then
		kDAKConfig.Captains = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "Captains", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })