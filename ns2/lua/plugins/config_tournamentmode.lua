//tournamentmode config

kDAKRevisions["tournamentmode"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.TournamentMode = { }
	kDAKConfig.TournamentMode.kTournamentModePubMode = false
	kDAKConfig.TournamentMode.kTournamentModeOverrideCanJoinTeam = true
	kDAKConfig.TournamentMode.kTournamentModePubMinPlayersPerTeam = 3
	kDAKConfig.TournamentMode.kTournamentModePubMinPlayersOnline = 8
	kDAKConfig.TournamentMode.kTournamentModePubGameStartDelay = 15
	kDAKConfig.TournamentMode.kTournamentModeAlertDelay = 30
	kDAKConfig.TournamentMode.kTournamentModeReadyDelay = 2
	kDAKConfig.TournamentMode.kTournamentModeGameStartDelay = 15
	kDAKConfig.TournamentMode.kTournamentModeCountdownDelay = 5
	kDAKConfig.TournamentMode.kTournamentModeFriendlyFirePercent = 0.33
	kDAKConfig.TournamentMode.kReadyChatCommands = { "ready" }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "tournamentmode", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kTournamentModeTeamReadyAlert"] 			= "Team %s is ready, waiting on team %s to start game."
	DefaultLangStrings["kTournamentModeCountdown"] 					= "Game will start in %s seconds!"
	DefaultLangStrings["kTournamentModePubPlayerWarning"] 			= "Game will start once each team has %s players."
	DefaultLangStrings["kTournamentModeReadyAlert"] 				= "Both teams need to ready for game to start."
	DefaultLangStrings["kTournamentModeTeamReady"] 					= "%s has %s for Team %s."
	DefaultLangStrings["kTournamentModeGameCancelled"]				= "Game start cancelled."
	DefaultLangStrings["kTournamentModeOfficialsMode"] 				= "Official Mode set, team captains ARE required."
	DefaultLangStrings["kTournamentModePCWMode"] 					= "PCW Mode set, team captains not required."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)