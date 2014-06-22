local md = TGNSMessageDisplayer.Create("VOTE")

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

local Plugin = {}

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 17, showVoteReminders)
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
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("mapvotehelper", Plugin )