//reservedslots config

DAK.revisions["voterandom"] = "0.1.302a"

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kVoteRandomInstantly = false
	DefaultConfig.kVoteRandomAlwaysEnabled = false
	DefaultConfig.kVoteRandomOnGameStart = false
	DefaultConfig.kVoteRandomDuration = 30
	DefaultConfig.kVoteRandomMinimumPercentage = 60
	DefaultConfig.kVoteRandomChatCommands = { "voterandom", "random" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "voterandom", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["VoteRandomConnectAlert"] 					= "Random teams are enabled, you are being randomed to a team."
	DefaultLangStrings["VoteRandomVoteCountAlert"] 					= "%s voted for random teams. (%s votes, needed %s)."
	DefaultLangStrings["VoteRandomEnabledDuration"] 				= "Random teams have been enabled for the next %s Minutes"
	DefaultLangStrings["VoteRandomEnabled"] 						= "Random teams have been enabled, the round will restart."
	DefaultLangStrings["VoteRandomTeamJoinBlock"] 					= "Random teams are enabled, you will be randomed to a team shortly."
	DefaultLangStrings["VoteRandomDisabled"] 						= "Random teams have been disabled."
	DefaultLangStrings["VoteRandomAlreadyVoted"] 					= "You already voted for random teams."
	DefaultLangStrings["VoteRandomAlreadyEnabled"] 					= "Random teams already enabled."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)