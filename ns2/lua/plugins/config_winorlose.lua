//WinOrLose config

kDAKRevisions["winorlose"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.WinOrLose = { }
	kDAKConfig.WinOrLose.kWinOrLoseMinimumPercentage = 60
	kDAKConfig.WinOrLose.kWinOrLoseVotingTime = 120
	kDAKConfig.WinOrLose.kWinOrLoseAlertDelay = 20
	kDAKConfig.WinOrLose.kWinOrLoseNoAttackDuration = 180
	kDAKConfig.WinOrLose.kWinOrLoseWarningInterval = 10
	kDAKConfig.WinOrLose.kWinOrLoseChatCommands = { "winorlose" }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "winorlose", DefaultConfig = SetupDefaultConfig })