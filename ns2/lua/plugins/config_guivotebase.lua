//GUIMenuBase config

kDAKRevisions["GUIMenuBase"] = 1.0

local function SetupDefaultConfig(Save)
	if kDAKConfig.GUIMenuBase == nil then
		kDAKConfig.GUIMenuBase = { }
	end
	kDAKConfig.GUIMenuBase.kVoteUpdateRate = 2
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "GUIMenuBase", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })