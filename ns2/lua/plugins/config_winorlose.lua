//WinOrLose config

kDAKRevisions["WinOrLose"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.WinOrLose == nil then
		kDAKConfig.WinOrLose = { }
	end
	kDAKConfig.WinOrLose.kWinOrLoseMinimumPercentage = 60
	kDAKConfig.WinOrLose.kWinOrLoseVotingTime = 120
	kDAKConfig.WinOrLose.kWinOrLoseAlertDelay = 20
	kDAKConfig.WinOrLose.kWinOrLoseNoAttackDuration = 180
	kDAKConfig.WinOrLose.kWinOrLoseWarningInterval = 10
	kDAKConfig.WinOrLose.kWinOrLoseChatCommands = { "winorlose" }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "WinOrLose", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })