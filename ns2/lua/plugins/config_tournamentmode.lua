//tournamentmode config

kDAKRevisions["TournamentMode"] = 1.8
local function SetupDefaultConfig(Save)
	if kDAKConfig.TournamentMode == nil then
		kDAKConfig.TournamentMode = { }
	end
	kDAKConfig.TournamentMode.kTournamentModePubMode = false
	kDAKConfig.TournamentMode.kTournamentModePubMinPlayersPerTeam = 3
	kDAKConfig.TournamentMode.kTournamentModePubMinPlayersOnline = 8
	kDAKConfig.TournamentMode.kTournamentModePubPlayerWarning = "Game will start once each team has %s players."
	kDAKConfig.TournamentMode.kTournamentModeAlertDelay = 30
	kDAKConfig.TournamentMode.kTournamentModeReadyDelay = 2
	kDAKConfig.TournamentMode.kTournamentModeGameStartDelay = 15
	kDAKConfig.TournamentMode.kTournamentModePubGameStartDelay = 15
	kDAKConfig.TournamentMode.kTournamentModeCountdown = "Game will start in %s seconds!"
	kDAKConfig.TournamentMode.kTournamentModeCountdownDelay = 5
	kDAKConfig.TournamentMode.kTournamentModeReadyAlert = "Both teams need to ready for game to start."
	kDAKConfig.TournamentMode.kTournamentModeTeamReadyAlert = "Team %s is ready, waiting on team %s to start game."
	kDAKConfig.TournamentMode.kReadyChatCommands = { "ready" }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "TournamentMode", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })