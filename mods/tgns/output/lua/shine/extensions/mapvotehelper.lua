local md = TGNSMessageDisplayer.Create()
local mapNominations = {}

local function show(mapVoteSummaries, totalVotes)
	local titleSumText = string.format("%s/%s", totalVotes, #TGNS.GetClientList())
	TGNS.ShowPanel(mapVoteSummaries, TGNS.GetClientList(), 66, 67, 68, 0.30, "Votes", titleSumText, 30, "(None)")
end

local function showAll()
	local mapVoteSummaries = {}
	local totalVotes = 0
	TGNS.DoForPairs(Shine.Plugins.mapvote.Vote.VoteList, function(mapName, voteCount)
		table.insert(mapVoteSummaries, string.format("%s: %s", mapName, voteCount))
		totalVotes = totalVotes + voteCount
	end)
	show(mapVoteSummaries, totalVotes)
end

local function measurableVoteIsInProgress()
	return Shine.Plugins.mapvote and Shine.Plugins.mapvote.Enabled and Shine.Plugins.mapvote.Vote and Shine.Plugins.mapvote.Vote.Voted and Shine.Plugins.mapvote:VoteStarted()
end

local function clientHasVoted(client)
	return Shine.Plugins.mapvote.Vote.Voted[client] ~= nil
end

local function showVoteReminders()
	if measurableVoteIsInProgress() then
		TGNS.DoFor(TGNS.GetClientList(), function(c)
			if not clientHasVoted(c) then
				Shine:SendText(c, Shine.BuildScreenMessage(101, 0.5, 0.65, " Please take a moment to vote for the next map.\n( instructions are at the top right of your screen )", 8, 0, 255, 0, 1, 4, 0))
			end
		end)
	end
end

local function checkForMaxNominations()
	local nominationsNeededToForceTheVote = Shine.Plugins.mapvote.MaxNominations
	if #Shine.Plugins.mapvote.Vote.Nominated >= nominationsNeededToForceTheVote then
		if not TGNS.IsGameInProgress() and not Shine.Plugins.mapvote:VoteStarted() and TGNS.GetSecondsSinceMapLoaded() > 600 then
			Shine.Plugins.mapvote.MapCycle.time = 0
			Shine.Commands.sh_forcemapvote.Func()
			TGNS.ForcePlayersToReadyRoom(TGNS.Where(TGNS.GetPlayerList(), function(p) return not TGNS.IsPlayerReadyRoom(p) end))
		end
	end
end

local Plugin = {}

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 17, showVoteReminders)
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, checkForMaxNominations)
end

function Plugin:Initialise()
    self.Enabled = true

	TGNS.ScheduleAction(5, function()
		if Shine.Plugins.mapvote and Shine.Plugins.mapvote.Enabled and Shine.Plugins.mapvote.AddVote then
			local originalAddVote = Shine.Plugins.mapvote.AddVote
			Shine.Plugins.mapvote.AddVote = function( plugin, Client, Map, Revote )
				local success, choice = originalAddVote( plugin, Client, Map, Revote )
				if success then
					showAll()
				end
				return success, choice
			end

			local originalStartVote = Shine.Plugins.mapvote.StartVote
			Shine.Plugins.mapvote.StartVote = function( plugin, NextMap, Force )
				originalStartVote( plugin, NextMap, Force )
				if Shine.Plugins.mapvote:VoteStarted() then
					showAll()
				end
			end
		end
	end)

	TGNS.ScheduleAction(5, function()
		local originalNominateFunc = Shine.Commands.sh_nominate.Func
		Shine.Commands.sh_nominate.Func = function(client, mapName)
			local steamId = TGNS.GetClientSteamId(client)
			local player = TGNS.GetPlayer(client)
			if mapNominations[steamId] then
				md:ToPlayerNotifyError(player, string.format("You may nominate only one map. You have already nominated %s.", mapNominations[steamId]))
			else
				local mapVoteNominationsCollectionContainedMapNameBeforeExecutingOriginalFunc = table.contains(Shine.Plugins.mapvote.Vote.Nominated, mapName)
				originalNominateFunc(client, mapName)
				local mapVoteNominationsCollectionContainedMapNameAfterExecutingOriginalFunc = table.contains(Shine.Plugins.mapvote.Vote.Nominated, mapName)
				if mapVoteNominationsCollectionContainedMapNameAfterExecutingOriginalFunc then
					if not mapVoteNominationsCollectionContainedMapNameBeforeExecutingOriginalFunc then
						mapNominations[steamId] = mapName
						checkForMaxNominations()
					end
				end
			end
		end
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("mapvotehelper", Plugin )