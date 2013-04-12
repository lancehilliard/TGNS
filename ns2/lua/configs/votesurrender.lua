//votesurrender config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kVoteSurrenderMinimumPercentage = 60
	DefaultConfig.kVoteSurrenderVotingTime = 120
	DefaultConfig.kVoteSurrenderAlertDelay = 20
	DefaultConfig.kSurrenderChatCommands = { "surrender" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "votesurrender", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["SurrenderTeamQuit"] 						= "Team %s has voted to surrender."
	DefaultLangStrings["SurrenderVoteStarted"] 						= "A vote has started for your team to surrender. %s votes are needed."
	DefaultLangStrings["SurrenderVoteExpired"] 						= "The surrender vote for your team has expired."
	DefaultLangStrings["SurrenderVoteUpdate"] 						= "%s votes to surrender, %s needed, %s seconds left. type surrender to vote"
	DefaultLangStrings["SurrenderVoteCancelled"] 					= "Surrender vote for team %s has been cancelled."
	DefaultLangStrings["SurrenderVoteToSurrender"]					= "You have voted to surrender."
	DefaultLangStrings["SurrenderVoteAlreadyVoted"] 				= "You already voted for to surrender."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)