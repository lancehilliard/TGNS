//votesurrender config

kDAKRevisions["votesurrender"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.VoteSurrender = { }
	kDAKConfig.VoteSurrender.kVoteSurrenderMinimumPercentage = 60
	kDAKConfig.VoteSurrender.kVoteSurrenderVotingTime = 120
	kDAKConfig.VoteSurrender.kVoteSurrenderAlertDelay = 20
	kDAKConfig.VoteSurrender.kSurrenderChatCommands = { "surrender" }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "votesurrender", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kSurrenderTeamQuit"] 						= "Team %s has voted to surrender."
	DefaultLangStrings["kSurrenderVoteStarted"] 					= "A vote has started for your team to surrender. %s votes are needed."
	DefaultLangStrings["kSurrenderVoteExpired"] 					= "The surrender vote for your team has expired."
	DefaultLangStrings["kSurrenderVoteUpdate"] 						= "%s votes to surrender, %s needed, %s seconds left. type surrender to vote"
	DefaultLangStrings["kSurrenderVoteCancelled"] 					= "Surrender vote for team %s has been cancelled."
	DefaultLangStrings["kSurrenderVoteToSurrender"]					= "You have voted to surrender."
	DefaultLangStrings["kSurrenderVoteAlreadyVoted"] 				= "You already voted for to surrender."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)