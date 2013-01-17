//Balance config

kDAKRevisions["Balance"] = 0.1

local function SetupDefaultConfig(Save)
	if kDAKConfig.Balance == nil then
		kDAKConfig.Balance = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "Balance", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })