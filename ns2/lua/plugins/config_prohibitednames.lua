//ProhibitedNames config

kDAKRevisions["prohibitednames"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.ProhibitedNames = { }
	kDAKConfig.ProhibitedNames.kProhibitedNames = {"NSPlayer"}
	kDAKConfig.ProhibitedNames.kProhibitedNamesWarnMessage = "Your player name is not allowed. Choose another name to stay."
	kDAKConfig.ProhibitedNames.kProhibitedNamesKickMessage = "Player name not allowed."
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "prohibitednames", DefaultConfig = SetupDefaultConfig })