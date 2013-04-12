//mapvote config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kRoundEndDelay = 2
	DefaultConfig.kVoteStartDelay = 8
	DefaultConfig.kVotingDuration = 30
	DefaultConfig.kMapsToSelect = 7
	DefaultConfig.kDontRepeatFor = 4
	DefaultConfig.kVoteNotifyDelay = 6
	DefaultConfig.kVoteChangeDelay = 4
	DefaultConfig.kVoteMinimumPercentage = 25
	DefaultConfig.kRTVMinimumPercentage = 50
	DefaultConfig.kExtendDuration = 15
	DefaultConfig.kPregameLength = 15
	DefaultConfig.kMaxGameNotStartedTime = 0
	DefaultConfig.kPregameNotifyDelay = 5
	DefaultConfig.kMaximumExtends = 3
	DefaultConfig.kMaximumTies = 1
	DefaultConfig.kTimeleftChatCommands = { "timeleft" }
	DefaultConfig.kRockTheVoteChatCommands = { "rtv", "rockthevote" }
	DefaultConfig.kVoteChatCommands = { "vote" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "mapvote", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["VoteMapRockTheVote"] 						= "%s rock'd the vote. (%s votes, needed %s)."
	DefaultLangStrings["VoteMapExtended"] 							= "******    Voting has ended, extending current map for %s minutes.   ******"
	DefaultLangStrings["VoteMapNoWinner"] 							= "******               Voting has ended, no map won.                      ******"
	DefaultLangStrings["VoteMapStarted"] 							= "******            Map vote has begun. (%s%% votes needed to win)           ******"
	DefaultLangStrings["VoteMapBeginning"] 							= "******                 Map vote will begin in %s seconds.                 ******"
	DefaultLangStrings["VoteMapHowToVote"] 							= "******     You can vote for the map you want by typing vote #     ******"
	DefaultLangStrings["VoteMapWinner"] 							= "******       Voting has ended, %s won with %s votes.         ******"
	DefaultLangStrings["VoteMapMapListing"] 						= "******                vote %s for %s                              ******"
	DefaultLangStrings["VoteMapTie"] 								= "******  Voting has ended with a tie, A new vote will start in %s seconds  ******"
	DefaultLangStrings["VoteMapTieBreaker"]							= "****** Voting has ended with a tie, %s was selected as the nextmap. ******"
	DefaultLangStrings["VoteMapInsufficientMaps"] 					= "******           Not enough maps for a vote.         ******"
	DefaultLangStrings["VoteMapCurrentMapVotes"] 					= "******      %s votes for %s (to vote, type vote %s)   ******"
	DefaultLangStrings["VoteMapCancelled"] 							= "******           Map vote has been cancelled.         ******"
	DefaultLangStrings["VoteMapAutomaticChange"] 					= "******      Advancing to next map in mapcycle.      ******"
	DefaultLangStrings["PregameNotification"] 						= "******      %.1f seconds remaining before game begins!     ******"
	DefaultLangStrings["VoteMapMinimumNotMet"] 						= "******%s had the most votes with %s, but the minimum required is %s.******"
	DefaultLangStrings["VoteMapTimeLeft"] 							= "******              %.1f seconds are left to vote           ******"
	DefaultLangStrings["VoteMapAlreadyVoted"] 						= "You already voted for %s."
	DefaultLangStrings["VoteMapCastVote"] 							= "Vote cast for %s."
	DefaultLangStrings["VoteMapAlreadyRTVd"] 						= "You already voted for a mapvote."
	DefaultLangStrings["VoteMapAlreadyRunning"] 					= "Map vote already running."
	DefaultLangStrings["VoteMapNotRunning"] 						= "Map vote not running."
	DefaultLangStrings["VoteMapTimeRemaining"] 						= "%.1f Minutes Remaining."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)