local md = TGNSMessageDisplayer.Create()
local mapNominations = {}
local mapSetSelected = false
local gamesPlayedOnCurrentMap = 0
local earnedVoteKarma = {}
local mapVoteSummaryChannelIds = {}
local INFESTED_PLAYER_THRESHOLD = 24

local function show(mapVoteSummaries, totalVotes)
	mapVoteSummaryChannelIds = {}
	local channelId = 67
	local y = 0.30
	local spaces = string.rep("   ", 16)
	local playerCount = #TGNS.GetPlayerList()
	Shine.ScreenText.Add(channelId, {X = 1.0, Y = y, Text = string.format("%s%s", string.format("Voters: %s/%s (%s%% got Karma)", totalVotes, playerCount, math.floor(totalVotes/playerCount*100)), spaces), Duration = 60, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMax, Size = 3, FadeIn = 0, IgnoreFormat = true})
	table.insert(mapVoteSummaryChannelIds, channelId)
	channelId = channelId + 1
	y = y + 0.05
	TGNS.DoFor(mapVoteSummaries, function(s)
		spaces = string.rep("   ", 16 - s.c)
		Shine.ScreenText.Add(channelId, {X = 1.0, Y = y, Text = string.format("%s%s", string.format("%s (%s/%s)", s.d, s.c, totalVotes), spaces), Duration = 60, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMax, Size = 3, FadeIn = 0, IgnoreFormat = true})
		table.insert(mapVoteSummaryChannelIds, channelId)
		channelId = channelId + 1
		y = y + 0.05
	end)
	
end

local function showAll()
	local mapVoteSummaries = {}
	local totalVotes = 0
	TGNS.DoForPairs(Shine.Plugins.mapvote.Vote.VoteList, function(mapName, voteCount)
		table.insert(mapVoteSummaries, {d=string.format("%s", mapName, voteCount),c=voteCount})
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
				Shine.ScreenText.Add(41, {X = 0.5, Y = 0.35, Text = " Please take a moment to vote for the next map.\n( instructions are at the top right of your screen )", Duration = 8, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
			end
		end)
	end
end

local function checkForMaxNominations()
	local nominationsNeededToForceTheVote = Shine.Plugins.mapvote.MaxNominations
	if #Shine.Plugins.mapvote.Vote.Nominated >= nominationsNeededToForceTheVote then
		local minimumRoundCount = Shine.GetGamemode() == "ns2" and 2 or 6
		if not TGNS.IsGameInProgress() and not Shine.Plugins.mapvote:VoteStarted() and gamesPlayedOnCurrentMap >= minimumRoundCount and not Shine.Plugins.captains:IsCaptainsModeEnabled() then
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
						Shine.Plugins.mapvote.Config.ExcludeLastMaps.Min = 0
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

-- function Plugin:OnProcessMove(player, input)
-- 	voteMoveModifier(player, input)
-- end

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
				local prepareMapVoteForNs2 = function()
					if Server.GetNumPlayersTotal() <= 10 and Shine.Plugins.arclight and Shine.Plugins.arclight.GetArclightMapname and not TGNS.Has(Shine.Plugins.mapvote.Vote.Nominated, Shine.Plugins.arclight:GetArclightMapname()) then
						table.insert(Shine.Plugins.mapvote.Vote.Nominated, Shine.Plugins.arclight:GetArclightMapname())
					end
					if Server.GetNumPlayersTotal() < 20 then
						TGNS.DoForReverse(Shine.Plugins.mapvote.Vote.Nominated, function(mapName, i)
							if TGNS.StartsWith(mapName, "infest_") then
								table.remove(Shine.Plugins.mapvote.Vote.Nominated, i)
							end
						end)
					end
				end
				local prepareMapVoteForSaturdayNightFever = function()
					local originalBuildMapChoices = Shine.Plugins.mapvote.BuildMapChoices
					Shine.Plugins.mapvote.BuildMapChoices = function(mapVotePluginSelf)
						local forcedMaps = {}
						TGNS.DoForPairs(Shine.Plugins.mapvote.Config.ForcedMaps, function(mapName, isForced)
							if isForced then
								table.insert(forcedMaps, mapName)
							end
						end)
						local result = TGNS.Where(forcedMaps, function(m) return TGNS.StartsWith(m, "infest_") end)
						local mapCountStillNeeded = Shine.Plugins.mapvote.Config.MaxOptions - #result
						if mapCountStillNeeded > 0 then
							local mapNames = TGNS.Select(Shine.Plugins.mapvote.MapChoices, function(map) return map.map or map end)
							local validMapNames = TGNS.Where(mapNames, function(m) return TGNS.StartsWith(m, "infest_") and not TGNS.Has(result, m) and TGNS.Replace(TGNS.GetCurrentMapName(), "ns2_", "infest_") ~= m end)
							local randomMapNames = TGNS.Take(TGNS.GetRandomizedElements(validMapNames), mapCountStillNeeded)
							TGNS.DoFor(randomMapNames, function(mapName)
								table.insert(result, mapName)
							end)
						end
						if #result == 0 then
							table.insertunique(result, "infest_tram")
							table.insertunique(result, "infest_summit")
							table.insertunique(result, "infest_veil")
						end
						return result
					end
				end
				if Shine.Plugins.infestedhelper:IsSaturdayNightFever() then
					prepareMapVoteForSaturdayNightFever()
					TGNS.ScheduleAction(1, function() md:ToAllNotifyInfo("Saturday Night Fever! Choose an Infested map!") end)
				else
					prepareMapVoteForNs2()
				end

				local convertNominationsToForcedMaps = function()
					local forcedMaps = {}
					TGNS.DoForPairs(Shine.Plugins.mapvote.Config.ForcedMaps, function(mapName, isForced)
						if isForced then
							table.insert(forcedMaps, mapName)
						end
					end)
					TGNS.DoFor(Shine.Plugins.mapvote.Vote.Nominated, function(mapName)
						if not TGNS.Has(forcedMaps, mapName) then
							Shine.Plugins.mapvote.Config.ForcedMaps[mapName] = true
							Shine.Plugins.mapvote.ForcedMapCount = (Shine.Plugins.mapvote.ForcedMapCount or 0) + 1
						end
					end)
					Shine.Plugins.mapvote.Vote.Nominated = {}
				end
				convertNominationsToForcedMaps()

				originalStartVote( plugin, NextMap, Force )
				if Shine.Plugins.mapvote:VoteStarted() then
					local playerList = TGNS.GetPlayerList()
					TGNS.DoFor(playerList, TGNS.AlertApplicationIconForPlayer)
					showAll()
					TGNS.DoForPairs(mapNominations, function(steamId, mapNames)
						local player = TGNS.GetPlayerMatchingSteamId(steamId)
						if player and TGNS.IsPlayerSM(player) then
							TGNS.DoFor(mapNames, function(m)
								local votePerformed
								TGNS.DoForPairs(Shine.Plugins.mapvote.Vote.VoteList, function(mapName, voteCount)
									if m == mapName then
										TGNS.ScheduleAction(0, function()
											local client = TGNS.GetClient(player)
											if client and Shine:IsValidClient(client) then
												TGNS.ExecuteClientCommand(client, string.format("sh_vote %s", mapName))
											end
										end)
										votePerformed = true
										return votePerformed
									end
								end)
								return votePerformed
							end)
						end
					end)
				end
			end
		end
	end)

	TGNS.ScheduleAction(5, function()
		local originalVoteFunc = Shine.Commands.sh_vote.Func
		Shine.Commands.sh_vote.Func = function(client, mapName)
			local originalVote = Shine.Plugins.mapvote.Vote.Voted[client]
			originalVoteFunc(client, mapName)
			if originalVote ~= Shine.Plugins.mapvote.Vote.Voted[client] then
				local steamId = TGNS.GetClientSteamId(client)
				if not earnedVoteKarma[steamId] then
					TGNS.Karma(steamId, "MapVoting")
					earnedVoteKarma[steamId] = true
				end
				Shine.ScreenText.End(41)
			end
		end

		local originalNominateFunc = Shine.Commands.sh_nominate.Func
		Shine.Commands.sh_nominate.Func = function(client, mapName)
			local steamId = TGNS.GetClientSteamId(client)
			mapNominations[steamId] = mapNominations[steamId] or {}
			local player = TGNS.GetPlayer(client)
			local infestedNominations = TGNS.Where(Shine.Plugins.mapvote.Vote.Nominated, function(mapName) return TGNS.StartsWith(mapName, "infest_") end)
			if mapSetSelected then
				md:ToPlayerNotifyError(player, "An admin has pre-selected map vote options and disallowed nominations.")
			elseif #mapNominations[steamId] > 0 and not TGNS.IsClientSM(client) then
				md:ToPlayerNotifyError(player, string.format("You may nominate only one map (SMs may nominate two). You have already nominated %s.", mapNominations[steamId][1]))
			elseif #mapNominations[steamId] > 1 and TGNS.IsClientSM(client) then
				md:ToPlayerNotifyError(player, string.format("SMs may nominate only two maps each. You have already nominated %s and %s.", mapNominations[steamId][1], mapNominations[steamId][2]))
			-- elseif Shine.Plugins.mapvote.Config.ExcludeLastMaps.Min > 0 and TGNS.Has(TGNS.Take(TGNS.TableReverse(Shine.Plugins.mapvote.LastMapData), Shine.Plugins.mapvote.Config.ExcludeLastMaps.Min), mapName) then
			-- 	md:ToPlayerNotifyError(player, string.format("%s was played too recently to be nominated now.", mapName))
			elseif #infestedNominations >= 2 and TGNS.StartsWith(mapName, "infest_") and not Shine.Plugins.infestedhelper:IsSaturdayNightFever() then
				md:ToPlayerNotifyError(player, string.format("%s and %s are already nominated. Only two Infested maps may be nominated.", infestedNominations[1], infestedNominations[2]))
			elseif TGNS.StartsWith(TGNS.GetCurrentMapName(), "infest_") and TGNS.StartsWith(mapName, "infest_") and not Shine.Plugins.infestedhelper:IsSaturdayNightFever() then
				md:ToPlayerNotifyError(player, "Infested nominations are not allowed on Infested maps.")
			elseif Shine.Plugins.infestedhelper:IsSaturdayNightFever() and not TGNS.StartsWith(mapName, "infest_") then
				md:ToPlayerNotifyError(player, "Saturday Night Fever! Nominate an Infested map!")
			else
				local mapVoteNominationsCollectionContainedMapNameBeforeExecutingOriginalFunc = table.contains(Shine.Plugins.mapvote.Vote.Nominated, mapName)
				originalNominateFunc(client, mapName)
				local mapVoteNominationsCollectionContainedMapNameAfterExecutingOriginalFunc = table.contains(Shine.Plugins.mapvote.Vote.Nominated, mapName)
				if mapVoteNominationsCollectionContainedMapNameAfterExecutingOriginalFunc then
					if not mapVoteNominationsCollectionContainedMapNameBeforeExecutingOriginalFunc then
						table.insert(mapNominations[steamId], mapName)
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
			TGNS.DoFor(mapVoteSummaryChannelIds, function(i)
				Shine.ScreenText.End(i)
			end)
		end

		local originalIsValidMapChoice = Shine.Plugins.mapvote.IsValidMapChoice
		Shine.Plugins.mapvote.IsValidMapChoice = function(mapVoteSelf, map, playerCount)
			local result = originalIsValidMapChoice(mapVoteSelf, map, playerCount)
			if result and (Shine.IsType(map, "table") or Shine.IsType(map, "string")) and not Shine.Plugins.infestedhelper:IsSaturdayNightFever() then
				if TGNS.GetHumanPlayerCount() < INFESTED_PLAYER_THRESHOLD then
					local mapName = map.map or map
					if Shine.IsType(mapName, "string") then
						local mapIsInfested = TGNS.StartsWith(mapName, "infest_")
						if mapIsInfested then
							result = false
						end
					end
				end
			end
			return result
		end
	end)

	local blacklistedLastMaps
	local originalGetBlacklistedLastMaps = Shine.Plugins.mapvote.GetBlacklistedLastMaps
	Shine.Plugins.mapvote.GetBlacklistedLastMaps = function(mapVotePluginSelf, numAvailable, numSelected)
		if blacklistedLastMaps == nil then
			local lastMaps = mapVotePluginSelf:GetLastMaps()
			TGNS.TableReverse(lastMaps)
			blacklistedLastMaps = TGNS.Take(lastMaps, mapVotePluginSelf.Config.ExcludeLastMaps.Min)
		end
		return blacklistedLastMaps
	end

	-- local lastMapsFileName = "config://shine/temp/lastmaps.json"
	-- local originalLoadJSONFile = Shine.LoadJSONFile
	-- Shine.LoadJSONFile = function(path)
	-- 	local result, err = originalLoadJSONFile(path)
	-- 	if path == lastMapsFileName then
	-- 		TGNS.PrintTable(result, "loadstock loadstock loadstock loadstock loadstock loadstock loadstock loadstock loadstock loadstock loadstock")
	-- 		if #result > 0 then
	-- 			if Shine.IsType(result[1], "table") then
	-- 				TGNS.SortAscending(result, function(x) return x.ChronologicalOrder end)
	-- 				result = TGNS.Select(result, function(x) return x.MapName end)
	-- 			end
	-- 		end
	-- 		TGNS.PrintTable(result, "loadmodded loadmodded loadmodded loadmodded loadmodded loadmodded loadmodded loadmodded loadmodded loadmodded")
	-- 	end
	-- 	return result, err
	-- end
	-- Shine.Plugins.mapvote:LoadLastMaps()

	-- local originalSaveJSONFile = Shine.SaveJSONFile
	-- Shine.SaveJSONFile = function(table, path, settings)
	-- 	if path == lastMapsFileName then
	-- 		TGNS.PrintTable(table, "savestock savestock savestock savestock savestock savestock savestock savestock savestock savestock savestock")
	-- 		if #table > 0 then
	-- 			if Shine.IsType(table[1], "string") then
	-- 				local chronologicalOrder = 1
	-- 				table = TGNS.Select(table, function(x)
	-- 					local result = {}
	-- 					result.ChronologicalOrder = chronologicalOrder
	-- 					result.MapName = x
	-- 					chronologicalOrder = chronologicalOrder + 1
	-- 					return result
	-- 				end)
	-- 			end
	-- 		end
	-- 		TGNS.PrintTable(table, "savemodded savemodded savemodded savemodded savemodded savemodded savemodded savemodded savemodded savemodded")
	-- 	end
	-- 	return originalSaveJSONFile(table, path, settings)
	-- end

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("mapvotehelper", Plugin )