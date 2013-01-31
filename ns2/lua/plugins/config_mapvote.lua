//mapvote config

kDAKRevisions["mapvote"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.MapVote = { }
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
	kDAKConfig.MapVote.kMaximumTies = 1
	kDAKConfig.MapVote.kTimeleftChatCommands = { "timeleft" }
	kDAKConfig.MapVote.kRockTheVoteChatCommands = { "rtv", "rockthevote" }
	kDAKConfig.MapVote.kVoteChatCommands = { "vote" }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "mapvote", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["kVoteMapRockTheVote"] 						= "%s rock'd the vote. (%s votes, needed %s)."
	DefaultLangStrings["kVoteMapExtended"] 							= "******    Voting has ended, extending current map for %s minutes.   ******"
	DefaultLangStrings["kVoteMapNoWinner"] 							= "******               Voting has ended, no map won.                      ******"
	DefaultLangStrings["kVoteMapStarted"] 							= "******            Map vote has begun. (%s%% votes needed to win)           ******"
	DefaultLangStrings["kVoteMapBeginning"] 						= "******                 Map vote will begin in %s seconds.                 ******"
	DefaultLangStrings["kVoteMapHowToVote"] 						= "******     You can vote for the map you want by typing vote #     ******"
	DefaultLangStrings["kVoteMapWinner"] 							= "******       Voting has ended, %s won with %s votes.         ******"
	DefaultLangStrings["kVoteMapMapListing"] 						= "******                vote %s for %s                              ******"
	DefaultLangStrings["kVoteMapTie"] 								= "******  Voting has ended with a tie, A new vote will start in %s seconds  ******"
	DefaultLangStrings["kVoteMapTieBreaker"]						= "****** Voting has ended with a tie, %s was selected as the nextmap. ******"
	DefaultLangStrings["kVoteMapInsufficientMaps"] 					= "******           Not enough maps for a vote.         ******"
	DefaultLangStrings["kVoteMapCurrentMapVotes"] 					= "******      %s votes for %s (to vote, type vote %s)   ******"
	DefaultLangStrings["kVoteMapCancelled"] 						= "******           Map vote has been cancelled.         ******"
	DefaultLangStrings["kVoteMapAutomaticChange"] 					= "******      Advancing to next map in mapcycle.      ******"
	DefaultLangStrings["kPregameNotification"] 						= "******      %.1f seconds remaining before game begins!     ******"
	DefaultLangStrings["kVoteMapMinimumNotMet"] 					= "******%s had the most votes with %s, but the minimum required is %s.******"
	DefaultLangStrings["kVoteMapTimeLeft"] 							= "******              %.1f seconds are left to vote           ******"
	DefaultLangStrings["kVoteMapAlreadyVoted"] 						= "You already voted for %s."
	DefaultLangStrings["kVoteMapCastVote"] 							= "Vote cast for %s."
	DefaultLangStrings["kVoteMapAlreadyRTVd"] 						= "You already voted for a mapvote."
	DefaultLangStrings["kVoteMapAlreadyRunning"] 					= "Map vote already running."
	DefaultLangStrings["kVoteMapNotRunning"] 						= "Map vote not running."
	DefaultLangStrings["kVoteMapTimeRemaining"] 					= "%.1f Minutes Remaining."
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)