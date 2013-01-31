//reservedslots config

kDAKRevisions["voterandom"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.VoteRandom = { }
	kDAKConfig.VoteRandom.kVoteRandomInstantly = false
	kDAKConfig.VoteRandom.kVoteRandomAlwaysEnabled = false
	kDAKConfig.VoteRandom.kVoteRandomOnGameStart = false
	kDAKConfig.VoteRandom.kVoteRandomDuration = 30
	kDAKConfig.VoteRandom.kVoteRandomMinimumPercentage = 60
	kDAKConfig.VoteRandom.kVoteRandomChatCommands = { "voterandom", "random" }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "voterandom", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kVoteRandomConnectAlert"] 					= "Random teams are enabled, you are being randomed to a team."
	DefaultLangStrings["kVoteRandomVoteCountAlert"] 				= "%s voted for random teams. (%s votes, needed %s)."
	DefaultLangStrings["kVoteRandomEnabledDuration"] 				= "Random teams have been enabled for the next %s Minutes"
	DefaultLangStrings["kVoteRandomEnabled"] 						= "Random teams have been enabled, the round will restart."
	DefaultLangStrings["kVoteRandomTeamJoinBlock"] 					= "Random teams are enabled, you will be randomed to a team shortly."
	DefaultLangStrings["kVoteRandomDisabled"] 						= "Random teams have been disabled."
	DefaultLangStrings["kVoteRandomAlreadyVoted"] 					= "You already voted for random teams."
	DefaultLangStrings["kVoteRandomAlreadyEnabled"] 				= "Random teams already enabled."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)