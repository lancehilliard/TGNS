local md = TGNSMessageDisplayer.Create()
local mapNominations = {}
local mapSetSelected = false
local gamesPlayedOnCurrentMap = 0
local earnedVoteKarma = {}

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
				-- Shine:SendText(c, Shine.BuildScreenMessage(101, 0.5, 0.65, , 8, 0, 255, 0, 1, 4, 0))
				Shine.ScreenText.Add(101, {X = 0.5, Y = 0.65, Text = " Please take a moment to vote for the next map.\n( instructions are at the top right of your screen )", Duration = 8, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 4, FadeIn = 0, IgnoreFormat = true}, c)
			end
		end)
	end
end

local function checkForMaxNominations()
	local nominationsNeededToForceTheVote = Shine.Plugins.mapvote.MaxNominations
	if #Shine.Plugins.mapvote.Vote.Nominated >= nominationsNeededToForceTheVote then
		if not TGNS.IsGameInProgress() and not Shine.Plugins.mapvote:VoteStarted() and gamesPlayedOnCurrentMap >= 2 and not Shine.Plugins.captains:IsCaptainsModeEnabled() then
			Shine.Plugins.mapvote.MapCycle.time = 0
			Shine.Commands.sh_forcemapvote.Func()
			TGNS.ForcePlayersToReadyRoom(TGNS.Where(TGNS.GetPlayerList(), function(p) return not TGNS.IsPlayerReadyRoom(p) end))
		end
	end
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "mapvotehelper.json"

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 17, showVoteReminders)
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, checkForMaxNominations)
	gamesPlayedOnCurrentMap = gamesPlayedOnCurrentMap + 1
end

function Plugin:CreateCommands()
	local setmapvoteCommand = self:BindCommand("sh_setmapvote", nil, function(client, setName)
		local player = TGNS.GetPlayer(client)
		if TGNS.HasNonEmptyValue(setName) then
			local mapSetNames = self.Config.MapSets[setName]
			if mapSetNames then
				if #mapSetNames > 0 then
					local mapSetNamesNotFoundInMapcycle = TGNS.Where(mapSetNames, function(n) return not TGNS.Has(TGNS.GetMapCycleMapNames(), n) end)
					if not TGNS.Any(mapSetNamesNotFoundInMapcycle) then
						Shine.Plugins.mapvote.Vote.Nominated = {}
						Shine.Plugins.mapvote.Config.ForcedMaps = {}
						TGNS.DoFor(mapSetNames, function(n) Shine.Plugins.mapvote.Config.ForcedMaps[n] = true end)
						Shine.Plugins.mapvote.ForcedMapCount = #mapSetNames
						Shine.Plugins.mapvote.Config.MaxOptions = Shine.Plugins.mapvote.ForcedMapCount
						Shine.Plugins.mapvote.Config.ExcludeLastMaps = 0
						Shine.Plugins.mapvote.Config.AllowExtend = true
						Shine.Plugins.mapvote.GetLastMaps = function(mapvotePlugin) return nil end
						Shine.Plugins.mapvote.CanExtend = function(mapvotePlugin) return TGNS.Has(mapSetNames, TGNS.GetCurrentMapName()) end
						TGNS.GetVoteableMapNames = function() return {} end
						Shine.Plugins.mapvote.ExtendMap = function(self, time, nextmap)
							local winningMap = Shine.Plugins.mapvote.NextMap.Winner
							Shine.Plugins.mapvote:Notify( nil, "Map changing in %s.", true, string.TimeToString( Shine.Plugins.mapvote.Config.ChangeDelay ) )
							TGNS.ScheduleAction(Shine.Plugins.mapvote.Config.ChangeDelay, function() MapCycle_ChangeMap( winningMap ) end)
						end
						mapSetSelected = true
						md:ToPlayerNotifyInfo(player, string.format("MapSet '%s' for next map vote: %s", setName, TGNS.Join(mapSetNames, ", ")))
					else
						md:ToPlayerNotifyError(player, string.format("MapSet '%s' has '%s' not found in MapCycle.", setName, TGNS.Join(mapSetNamesNotFoundInMapcycle, ", ")))
					end
				else
					md:ToPlayerNotifyError(player, string.format("MapSet '%s' doesn't seem to include any maps.", setName))
				end
			else
				md:ToPlayerNotifyError(player, string.format("No MapSet was found matching the name '%s'.", setName))
			end
		else
			md:ToPlayerNotifyError(player, "Specify the name of a MapSet when using sh_setmapvote.")
		end
	end)
	setmapvoteCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	setmapvoteCommand:Help("<mapSetName> Configure the map vote for a named set of maps.")
end

function Plugin:Initialise()
    self.Enabled = true
	self:CreateCommands()
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
					TGNS.DoFor(TGNS.GetPlayerList(), TGNS.AlertApplicationIconForPlayer)
					showAll()
				end
			end
		end
	end)

	TGNS.ScheduleAction(5, function()
		local originalVoteFunc = Shine.Commands.sh_vote.Func
		Shine.Commands.sh_vote.Func = function(client, mapName)
			local originalNotify = Shine.Plugins.mapvote.Notify
			Shine.Plugins.mapvote.Notify = function(notifySelf, player, message, format, ...)
				if message ~= "You %s %s (%s for this, %i total)" then
					originalNotify(notifySelf, player, message, format, ...)
				end
				local steamId = TGNS.GetClientSteamId(client)
				if not earnedVoteKarma[steamId] then
					TGNS.ScheduleAction(10, function()
						TGNS.Karma(steamId, "MapVoting")
					end)
					earnedVoteKarma[steamId] = true
				end
			end
			originalVoteFunc(client, mapName)
			Shine.Plugins.mapvote.Notify = originalNotify
		end

		local originalNominateFunc = Shine.Commands.sh_nominate.Func
		Shine.Commands.sh_nominate.Func = function(client, mapName)
			local steamId = TGNS.GetClientSteamId(client)
			local player = TGNS.GetPlayer(client)
			if mapSetSelected then
				md:ToPlayerNotifyError(player, "An admin has pre-selected map vote options and disallowed nominations.")
			elseif mapNominations[steamId] then
				md:ToPlayerNotifyError(player, string.format("You may nominate only one map. You have already nominated %s.", mapNominations[steamId]))
			elseif Shine.Plugins.mapvote.Config.ExcludeLastMaps > 0 and TGNS.Has(Shine.Plugins.mapvote.LastMapData, mapName) then
				md:ToPlayerNotifyError(player, string.format("%s was played too recently to be nominated now.", mapName))
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

		local originalForceMapVoteFunc = Shine.Commands.sh_forcemapvote.Func
		Shine.Commands.sh_forcemapvote.Func = function(client)
			if TGNS.IsGameInProgress() then
				local player = TGNS.GetPlayer(client)
				md:ToPlayerNotifyError(player, "This command is not available during gameplay.")
			else
				originalForceMapVoteFunc(client)
			end
		end

		local originalExtendMap = Shine.Plugins.mapvote.ExtendMap
		Shine.Plugins.mapvote.ExtendMap = function(mapVoteSelf, time, nextMap)
			originalExtendMap(mapVoteSelf, time, nextMap)
			Shine:RemoveText(nil, { ID = 66 } )
			Shine:RemoveText(nil, { ID = 67 } )
			Shine:RemoveText(nil, { ID = 68 } )
		end
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("mapvotehelper", Plugin )