//reservedslots config

kDAKRevisions["VoteRandom"] = 1.8
local function SetupDefaultConfig(Save)
	if kDAKConfig.VoteRandom == nil then
		kDAKConfig.VoteRandom = { }
	end
	kDAKConfig.VoteRandom.kVoteRandomInstantly = false
	kDAKConfig.VoteRandom.kVoteRandomDuration = 30
	kDAKConfig.VoteRandom.kVoteRandomMinimumPercentage = 60
	kDAKConfig.VoteRandom.kVoteRandomChatCommands = { "voterandom", "random" }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "VoteRandom", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })