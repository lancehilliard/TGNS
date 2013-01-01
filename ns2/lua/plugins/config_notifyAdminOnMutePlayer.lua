//NotifyAdminOnMutePlayer config

kDAKRevisions["NotifyAdminOnMutePlayer"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.NotifyAdminOnMutePlayer == nil then
		kDAKConfig.NotifyAdminOnMutePlayer = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "NotifyAdminOnMutePlayer", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })