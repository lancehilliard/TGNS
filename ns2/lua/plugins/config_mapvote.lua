//mapvote config

kDAKRevisions["MapVote"] = 2.0
local function SetupDefaultConfig(Save)
	if kDAKConfig.MapVote == nil then
		kDAKConfig.MapVote = { }
	end
	kDAKConfig.MapVote.kRoundEndDelay = 2
	kDAKConfig.MapVote.kVoteStartDelay = 8
	kDAKConfig.MapVote.kVotingDuration = 30
	kDAKConfig.MapVote.kMapsToSelect = 7
	kDAKConfig.MapVote.kDontRepeatFor = 4
	kDAKConfig.MapVote.kVoteNotifyDelay = 6
	kDAKConfig.MapVote.kVoteChangeDelay = 4
	kDAKConfig.MapVote.kVoteMinimumPercentage = 25
	kDAKConfig.MapVote.kRTVMinimumPercentage = 50
	kDAKConfig.MapVote.kExtendDuration = 15
	kDAKConfig.MapVote.kPregameLength = 15
	kDAKConfig.MapVote.kPregameNotifyDelay = 5
	kDAKConfig.MapVote.kMaximumExtends = 3
	kDAKConfig.MapVote.kTimeleftChatCommands = { "timeleft" }
	kDAKConfig.MapVote.kRockTheVoteChatCommands = { "rtv", "rockthevote" }
	kDAKConfig.MapVote.kVoteChatCommands = { "vote" }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "MapVote", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })