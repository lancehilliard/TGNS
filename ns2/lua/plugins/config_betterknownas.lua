//BetterKnownAs config

kDAKRevisions["BetterKnownAs"] = 0.1

local function SetupDefaultConfig(Save)
	if kDAKConfig.BetterKnownAs == nil then
		kDAKConfig.BetterKnownAs = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "BetterKnownAs", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })