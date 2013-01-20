//SpecLimit config

kDAKRevisions["SpecLimit"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.SpecLimit == nil then
		kDAKConfig.SpecLimit = { }
	end
	
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "SpecLimit", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })