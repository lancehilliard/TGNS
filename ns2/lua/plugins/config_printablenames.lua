//PrintableNames config

kDAKRevisions["printablenames"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.PrintableNames = { }
	kDAKConfig.PrintableNames.kPrintableNamesWarnMessage = "Your name must use only printable characters."
	kDAKConfig.PrintableNames.kPrintableNamesKickMessage = "Player names must use all printable characters."
end
DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "printablenames", DefaultConfig = SetupDefaultConfig })