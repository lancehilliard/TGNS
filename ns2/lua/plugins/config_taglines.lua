//Taglines config

kDAKRevisions["Taglines"] = 0.1

local function SetupDefaultConfig(Save)
	if kDAKConfig.Taglines == nil then
		kDAKConfig.Taglines = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "Taglines", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })