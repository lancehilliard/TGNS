Script.Load("lua/TGNSCommon.lua")

local defaultConfig = {}
defaultConfig.kWinOrLoseMinimumPercentage = 60
defaultConfig.kWinOrLoseVotingTime = 120
defaultConfig.kWinOrLoseAlertDelay = 20
defaultConfig.kWinOrLoseNoAttackDuration = 180
defaultConfig.kWinOrLoseWarningInterval = 10
defaultConfig.kWinOrLoseChatCommands = { "winorlose" }

TGNS.RegisterPluginConfig("winorlose", "0.1", defaultConfig)