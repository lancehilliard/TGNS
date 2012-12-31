//reservedslots config

kDAKRevisions["VoteRandom"] = 1.8
local function SetupDefaultConfig(Save)
	if kDAKConfig.VoteRandom == nil then
		kDAKConfig.VoteRandom = { }
	end
	kDAKConfig.VoteRandom.kVoteRandomInstantly = false
	kDAKConfig.VoteRandom.kVoteRandomDuration = 30
	kDAKConfig.VoteRandom.kVoteRandomMinimumPercentage = 60
	kDAKConfig.VoteRandom.kVoteRandomEnabled = "Random teams have been enabled, the round will restart."
	kDAKConfig.VoteRandom.kVoteRandomEnabledDuration = "Random teams have been enabled for the next %s Minutes"
	kDAKConfig.VoteRandom.kVoteRandomConnectAlert = "Random teams are enabled, you are being randomed to a team."
	kDAKConfig.VoteRandom.kVoteRandomVoteCountAlert = "%s voted for random teams. (%s votes, needed %s)."
	kDAKConfig.VoteRandom.kVoteRandomChatCommands = { "voterandom", "random" }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "VoteRandom", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })