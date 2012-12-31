//baseadmincommands default config

kDAKRevisions["BaseAdminCommands"] = 1.8
local function SetupDefaultConfig(Save)
	if kDAKConfig.BaseAdminCommands == nil then
		kDAKConfig.BaseAdminCommands = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "BaseAdminCommands", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })