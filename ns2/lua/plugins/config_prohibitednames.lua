//ProhibitedNames config

kDAKRevisions["ProhibitedNames"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.ProhibitedNames == nil then
		kDAKConfig.ProhibitedNames = { }
	end
	kDAKConfig.ProhibitedNames.kProhibitedNames = {"NSPlayer"}
	kDAKConfig.ProhibitedNames.kProhibitedNamesWarnMessage = "Your player name is not allowed. Choose another name to stay."
	kDAKConfig.ProhibitedNames.kProhibitedNamesKickMessage = "Player name not allowed."
	
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "ProhibitedNames", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })