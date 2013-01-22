//TempAdmin config

kDAKRevisions["TempAdmin"] = 0.1

local function SetupDefaultConfig(Save)
	if kDAKConfig.TempAdmin == nil then
		kDAKConfig.TempAdmin = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "TempAdmin", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })