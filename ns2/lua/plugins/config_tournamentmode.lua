//tournamentmode config

kDAKRevisions["TournamentMode"] = 1.8
local function SetupDefaultConfig(Save)
	if kDAKConfig.TournamentMode == nil then
		kDAKConfig.TournamentMode = { }
	end
	kDAKConfig.TournamentMode.kTournamentModePubMode = false
	kDAKConfig.TournamentMode.kTournamentModeOverrideCanJoinTeam = true
	kDAKConfig.TournamentMode.kTournamentModePubMinPlayersPerTeam = 3
	kDAKConfig.TournamentMode.kTournamentModePubMinPlayersOnline = 8
	kDAKConfig.TournamentMode.kTournamentModeAlertDelay = 30
	kDAKConfig.TournamentMode.kTournamentModeReadyDelay = 2
	kDAKConfig.TournamentMode.kTournamentModeGameStartDelay = 15
	kDAKConfig.TournamentMode.kTournamentModePubGameStartDelay = 15
	kDAKConfig.TournamentMode.kTournamentModeCountdownDelay = 5
	kDAKConfig.TournamentMode.kReadyChatCommands = { "ready" }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "TournamentMode", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })