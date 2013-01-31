//afkkick default config

kDAKRevisions["pause"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.Pause = { }
	kDAKConfig.Pause.kPauseChangeDelay = 5
	kDAKConfig.Pause.kPauseMaxPauses = 3
	kDAKConfig.Pause.kPausedReadyNotificationDelay = 10
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "pause", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kPauseResumeMessage"] 					= "Game Resumed.  Team %s has %s pauses remaining"
	DefaultLangStrings["kPausePausedMessage"] 					= "Game Paused."
	DefaultLangStrings["kPauseWarningMessage"] 					= "Game will %s in %.1f seconds."
	DefaultLangStrings["kPausePlayerMessage"] 					= "%s executed a game pause."
	DefaultLangStrings["kPauseTeamReadiedMessage"] 				= "%s readied for Team %s, resuming game."
	DefaultLangStrings["kPauseTeamReadyMessage"] 				= "%s readied for Team %s, waiting for Team %s."
	DefaultLangStrings["kPauseTeamReadyPeriodicMessage"] 		= "Team %s is ready, waiting for Team %s."
	DefaultLangStrings["kPauseNoTeamReadyMessage"] 				= "No team is ready to resume, type unpause in console to ready for your team."
	DefaultLangStrings["kPauseCancelledMessage"] 				= "Game Pause Cancelled."
	DefaultLangStrings["kPauseTooManyPausesMessage"] 			= "Your team is out of pauses."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)