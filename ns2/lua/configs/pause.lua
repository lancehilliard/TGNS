//afkkick default config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kPauseChangeDelay = 5
	DefaultConfig.kPauseMaxPauses = 3
	DefaultConfig.kPausedReadyNotificationDelay = 30
	DefaultConfig.kPausedMaxDuration = 0
	DefaultConfig.kPauseChatCommands = { "pause" }
	DefaultConfig.kUnPauseChatCommands = { "unpause" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "pause", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["PauseResumeMessage"] 					= "Game Resumed.  %s have %s pauses remaining"
	DefaultLangStrings["PausePausedMessage"] 					= "Game Paused."
	DefaultLangStrings["PauseWarningMessage"] 					= "Game will %s in %.1f seconds."
	DefaultLangStrings["PauseResumeWarningMessage"] 			= "Game will automatically resume in %.1f seconds."
	DefaultLangStrings["PausePlayerMessage"] 					= "%s has paused the game."
	DefaultLangStrings["PauseTeamReadiedMessage"] 				= "%s readied for %s, resuming game."
	DefaultLangStrings["PauseTeamReadyMessage"] 				= "%s readied for %s, waiting for the %s."
	DefaultLangStrings["PauseTeamReadyPeriodicMessage"] 		= "%s are ready, waiting for the %s."
	DefaultLangStrings["PauseNoTeamReadyMessage"] 				= "No team is ready to resume, type unpause in console to ready for your team."
	DefaultLangStrings["PauseCancelledMessage"] 				= "Game Pause Cancelled."
	DefaultLangStrings["PauseTooManyPausesMessage"] 			= "Your team is out of pauses."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)