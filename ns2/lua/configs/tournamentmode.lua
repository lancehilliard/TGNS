//tournamentmode config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kTournamentModePubMode = false
	DefaultConfig.kTournamentModeOverrideCanJoinTeam = true
	DefaultConfig.kTournamentModePubMinPlayersPerTeam = 3
	DefaultConfig.kTournamentModePubMinPlayersOnline = 8
	DefaultConfig.kTournamentModePubGameStartDelay = 15
	DefaultConfig.kTournamentModeAlertDelay = 30
	DefaultConfig.kTournamentModeReadyDelay = 2
	DefaultConfig.kTournamentModeRestartDuration = 120
	DefaultConfig.kTournamentModeGameStartDelay = 15
	DefaultConfig.kTournamentModeCountdownDelay = 5
	DefaultConfig.kTournamentModeFriendlyFirePercent = 0.33
	DefaultConfig.kReadyChatCommands = { "ready" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "tournamentmode", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["TournamentModeTeamReadyAlert"] 				= "Team %s is ready, waiting on team %s to start game."
	DefaultLangStrings["TournamentModeCountdown"] 					= "Game will start in %s seconds!"
	DefaultLangStrings["TournamentModePubPlayerWarning"] 			= "Game will start once each team has %s players."
	DefaultLangStrings["TournamentModeReadyAlert"] 					= "Both teams need to ready for game to start."
	DefaultLangStrings["TournamentModeTeamReady"] 					= "%s has %s for Team %s."
	DefaultLangStrings["TournamentModeGameCancelled"]				= "Game start cancelled."
	DefaultLangStrings["TournamentModeOfficialsMode"] 				= "Official Mode set, team captains ARE required."
	DefaultLangStrings["TournamentModePCWMode"] 					= "PCW Mode set, team captains not required."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)