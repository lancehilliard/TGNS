//badges

kDAKRevisions["Badges"] = 1.0
local function SetupDefaultConfig(Save)
	if kDAKConfig.Badges == nil then
		kDAKConfig.Badges = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "Badges", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })