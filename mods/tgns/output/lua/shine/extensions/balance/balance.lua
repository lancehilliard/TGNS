if Server or Client then

	kTechData = nil
	ClearCachedTechData()
	-- local originalkHeavyMachineGunTechResearchTime = kHeavyMachineGunTechResearchTime
	-- kHeavyMachineGunTechResearchTime = kHeavyMachineGunTechResearchTime / 2
	-- local originalkBoneShieldMaxDuration = kBoneShieldMaxDuration
	-- kBoneShieldMaxDuration = kBoneShieldMaxDuration * 0.75

	local md
	local pdr
	local AddScorePerMinuteData
	local updateTotalGamesPlayedCache
	local balanceCache
	local onosBalanceAdvisory

	local Plugin = {}

	if Client then

	end

	if Server then

		Plugin.HasConfig = true
		Plugin.ConfigName = "balance.json"


		onosBalanceAdvisory = string.format("Onos cost %s. Bone Shield only heals if taking damage, and saps energy while healing.", kOnosCost)
		local playerBanks = {}

		-- playerBanks[60671349] = 10245838991233900000
		-- Shared.Message("---------------------------------------------------------------------------------------------------------------- playerBanks[60671349]: " .. tostring(playerBanks[60671349]))
		-- playerBanks[60671349] = playerBanks[60671349] + 1
		-- Shared.Message("---------------------------------------------------------------------------------------------------------------- playerBanks[60671349]: " .. tostring(playerBanks[60671349]))

		Balance = {}

		local balanceLog = {}
		local balanceInProgress = false
		local lastBalanceStartTimeInSeconds = 0
		local SCORE_PER_MINUTE_DATAPOINTS_TO_KEEP = 30
		local RECENT_BALANCE_DURATION_IN_SECONDS = 15
		local NS2STATS_SCORE_PER_MINUTE_VALID_DATA_THRESHOLD = 30
		local LOCAL_DATAPOINTS_COUNT_THRESHOLD = 10
		local totalGamesPlayedCache = {}
		balanceCache = {}
		local mayBalanceAt = 0
		local FIRSTCLIENT_TIME_BEFORE_BALANCE = 30
		local GAMEEND_TIME_BEFORE_BALANCE = TGNS.ENDGAME_TIME_TO_READYROOM + 3
		local BALANCE_VOICECOMM_TOLERANCE_IN_SECONDS = 2
		local firstClientProcessed = false
		local lanesMd = TGNSMessageDisplayer.Create("LANES")
		local lanesAdvisoryLastShownAt = {}
		local onosBalanceAdvisoryLastShownAt = {}

		-- local commanderSteamIds = {}
		-- local bestPlayerSteamIds = {}
		-- local betterPlayerSteamIds = {}
		-- local goodPlayerSteamIds = {}
		local balanceDataInitializer = function(balance)
			balance.wins = balance.wins ~= nil and balance.wins or 0
			balance.losses = balance.losses ~= nil and balance.losses or 0
			balance.total = balance.total ~= nil and balance.total or 0
			balance.scoresPerMinute = balance.scoresPerMinute ~= nil and balance.scoresPerMinute or {}
			return balance
		end
		--local npdr
		local preventTeamJoinMessagesDueToRecentEndGame
		local harvesterDecayEnabled = false
		local balanceCacheData = {}
		local lastTeamNumbers = {}

		pdr = TGNSPlayerDataRepository.Create("balance", balanceDataInitializer)
		md = TGNSMessageDisplayer.Create("BALANCE")

		function Balance.IsInProgress()
			return balanceInProgress
		end
		function Balance.GetTotalGamesPlayedBySteamId(steamId)
			local result
			if steamId ~= nil and steamId ~= 0 then
				result = totalGamesPlayedCache[steamId]
			end
			return result or 0
		end
		function Balance.GetTotalGamesPlayed(client)
			local steamId = TGNS.GetClientSteamId(client)
			local result = Balance.GetTotalGamesPlayedBySteamId(steamId)
			return result
		end
		function Balance.GetClientWeight(client)
			local steamId = TGNS.GetClientSteamId(client)
			local bestWeight = TGNS.Has(bestPlayerSteamIds, steamId) and 3 or 0
			local betterWeight = TGNS.Has(betterPlayerSteamIds, steamId) and 2 or 0
			local goodWeight = TGNS.Has(goodPlayerSteamIds, steamId) and 1 or 0
			local result = goodWeight + betterWeight + bestWeight
			return result
		end

		local function BalanceStartedRecently()
			local result = Shared.GetTime() > RECENT_BALANCE_DURATION_IN_SECONDS and Shared.GetTime() - lastBalanceStartTimeInSeconds < RECENT_BALANCE_DURATION_IN_SECONDS
			return result
		end

		AddScorePerMinuteData = function(balance, scorePerMinute)
			table.insert(balance.scoresPerMinute, scorePerMinute)
			local scoresPerMinuteToKeep = {}
			TGNS.DoForReverse(balance.scoresPerMinute, function(scorePerMinute)
				if #scoresPerMinuteToKeep < SCORE_PER_MINUTE_DATAPOINTS_TO_KEEP then
					table.insert(scoresPerMinuteToKeep, scorePerMinute)
				end
			end)
			balance.scoresPerMinute = scoresPerMinuteToKeep
		end

		local function GetWinLossRatio(player, balance)
			local result = 0.5
			if balance ~= nil then
				local totalGames = balance.losses + balance.wins
				local notEnoughGamesToMatter = totalGames < LOCAL_DATAPOINTS_COUNT_THRESHOLD
				if notEnoughGamesToMatter then
					result = TGNS.PlayerIsRookie(player) and 0 or .5
				else
					result = balance.wins / totalGames
				end
			end
			return result
		end

		local function GetPlayerBalance(player)
			local result = balanceCache[TGNS.GetClient(player)] or balanceDataInitializer({})
			return result
		end

		local function GetPlayerScorePerMinuteAverage(player)
			local balance = GetPlayerBalance(player)
			local result = #balance.scoresPerMinute >= LOCAL_DATAPOINTS_COUNT_THRESHOLD and TGNSAverageCalculator.CalculateFor(balance.scoresPerMinute) or nil
			if result == nil then
				local steamId = TGNS.ClientAction(player, TGNS.GetClientSteamId)
				local ns2StatsPlayerRecord = TGNSNs2StatsProxy.GetPlayerRecord(steamId)
				if ns2StatsPlayerRecord.HasData then
					local cumulativeScore = ns2StatsPlayerRecord.GetCumulativeScore()
					local timePlayedInMinutes = TGNS.ConvertSecondsToMinutes(ns2StatsPlayerRecord.GetTimePlayedInSeconds())
					result = TGNSAverageCalculator.Calculate(cumulativeScore, timePlayedInMinutes)
					result = result < NS2STATS_SCORE_PER_MINUTE_VALID_DATA_THRESHOLD and result or nil
				end
			end
			return result or 0
		end

		local function GetPlayerWinLossRatio(player)
			local balance = GetPlayerBalance(player)
			local result = GetWinLossRatio(player, balance)
			return result
		end

		local function GetPlayerProjectionAverage(clients, playerProjector)
			local values = TGNS.Select(clients, function(c)
				return TGNS.PlayerAction(c, playerProjector)
			end)
			local result = TGNSAverageCalculator.CalculateFor(values)
			return result
		end

		local function GetHiveRankAverage(clients)
			local result = GetPlayerProjectionAverage(clients, TGNS.GetPlayerHiveSkillRank) or 0
			return result
		end

		local function GetScorePerMinuteAverage(clients)
			local result = GetPlayerProjectionAverage(clients, GetPlayerScorePerMinuteAverage) or 0
			return result
		end

		local function GetWinLossAverage(clients)
			local result = GetPlayerProjectionAverage(clients, GetPlayerWinLossRatio) or 0
			return result
		end

		local function PrintBalanceLog()
			TGNS.DoFor(balanceLog, function(logline)
				md:ToAdminConsole(logline)
			end)
		end

		local function SendNextPlayer()
			local wantToUseWinLossToBalance = false

			local sortedPlayersGetter
			local teamAverageGetter

			local playerSortValueGetter = TGNS.GetPlayerHiveSkillRank

			if wantToUseWinLossToBalance then
				sortedPlayersGetter = function(playerList)
					local playersWithFewerThanTenGames = TGNS.GetPlayers(TGNS.GetMatchingClients(playerList, function(c,p) return GetPlayerBalance(p).total < LOCAL_DATAPOINTS_COUNT_THRESHOLD end))
					local playersWithTenOrMoreGames = TGNS.GetPlayers(TGNS.GetMatchingClients(playerList, function(c,p) return GetPlayerBalance(p).total >= LOCAL_DATAPOINTS_COUNT_THRESHOLD end))
					TGNS.SortDescending(playersWithTenOrMoreGames, GetPlayerWinLossRatio)
					local result = playersWithFewerThanTenGames
					TGNS.DoFor(playersWithTenOrMoreGames, function(p)
						table.insert(result, p)
					end)
					return result
				end
				teamAverageGetter = GetWinLossAverage
			else
				sortedPlayersGetter = function(playerList)
					-- local result = {}
					-- local commanders = TGNS.Take(TGNS.GetRandomizedElements(TGNS.Where(playerList, function(p) return TGNS.Has(commanderSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)), 2)
					-- local bestPlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and TGNS.Has(bestPlayerSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
					-- local betterPlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and TGNS.Has(betterPlayerSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
					-- local goodPlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and TGNS.Has(goodPlayerSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
					-- local rookiePlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and not TGNS.Has(goodPlayers, p) and TGNS.PlayerIsRookie(p) end)
					-- local nonRookieStrangers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and not TGNS.Has(goodPlayers, p) and not TGNS.Has(rookiePlayers, p) and TGNS.ClientAction(p, TGNS.IsClientStranger) end)
					-- local nonRookieRegulars = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and not TGNS.Has(goodPlayers, p) and not TGNS.Has(rookiePlayers, p) and not TGNS.Has(nonRookieStrangers, p) end)
					-- local sortAction = math.random() < 0.5 and TGNS.SortDescending or TGNS.SortAscending
					-- sortAction(commanders, playerSortValueGetter)
					-- sortAction(bestPlayers, playerSortValueGetter)
					-- sortAction(betterPlayers, playerSortValueGetter)
					-- sortAction(goodPlayers, playerSortValueGetter)
					-- sortAction(rookiePlayers, playerSortValueGetter)
					-- sortAction(nonRookieStrangers, playerSortValueGetter)
					-- sortAction(nonRookieRegulars, playerSortValueGetter)
					-- local playerGroups = { commanders, bestPlayers, betterPlayers, goodPlayers, rookiePlayers, nonRookieStrangers, nonRookieRegulars }
					-- local addPlayerToResult = function(p) table.insert(result, p) end
					-- TGNS.DoFor(playerGroups, function(g) TGNS.DoFor(g, addPlayerToResult) end)
					-- return result

					local result = playerList
					local sortAction = math.random() < 0.5 and TGNS.SortDescending or TGNS.SortAscending
					sortAction(result, playerSortValueGetter)
					return result
				end
				teamAverageGetter = GetHiveRankAverage
			end

			local afkPlayerNamesCommaDelimited = TGNS.Join(TGNS.Select(TGNS.Where(TGNS.GetPlayerList(), TGNS.IsPlayerAFK), TGNS.GetPlayerName), ", ")
			table.insert(balanceLog, string.format("AFK players: %s", afkPlayerNamesCommaDelimited))
			local playerList = (Shine.Plugins.communityslots and Shine.Plugins.communityslots.GetPlayersForNewGame) and Shine.Plugins.communityslots:GetPlayersForNewGame() or TGNS.GetPlayerList()
			if Shine.Plugins.sidebar and Shine.Plugins.sidebar.PlayerIsInSidebar then
				playerList = TGNS.Where(playerList, function(p) return not Shine.Plugins.sidebar:PlayerIsInSidebar(p) end)
			end
			local sortedPlayers = sortedPlayersGetter(playerList)
			local eligiblePlayers = sortedPlayers -- TGNS.Where(sortedPlayers, function(p) return TGNS.IsPlayerReadyRoom(p) and not TGNS.IsPlayerAFK(p) end)
			local gamerules = GetGamerules()
			local numberOfMarines = gamerules:GetTeam(kTeam1Index):GetNumPlayers()
			local numberOfAliens = gamerules:GetTeam(kTeam2Index):GetNumPlayers()
			TGNS.DoFor(eligiblePlayers, function(player)
				local teamNumber = numberOfMarines <= numberOfAliens and kMarineTeamType or kAlienTeamType
				if (teamNumber == kMarineTeamType and numberOfMarines < 8) or (teamNumber == kAlienTeamType and numberOfAliens < 8) then
					local actionMessage = string.format("sent to %s", TGNS.GetTeamName(teamNumber))
					table.insert(balanceLog, string.format("%s: %s (NS2 Hive Skill ranking) with %s games = %s", TGNS.GetPlayerName(player), playerSortValueGetter(player), GetPlayerBalance(player).total, actionMessage))
					TGNS.SendToTeam(player, teamNumber, true)
					if teamNumber == kMarineTeamType then
						numberOfMarines = numberOfMarines + 1
					else
						numberOfAliens = numberOfAliens + 1
					end
				end
			end)



			md:ToAdminConsole("Balance finished.")
			balanceInProgress = false
			local playerList = TGNS.GetPlayerList()
			local marineClients = TGNS.GetMarineClients(playerList)
			local alienClients = TGNS.GetAlienClients(playerList)
			local marineAvg = teamAverageGetter(marineClients)
			local alienAvg = teamAverageGetter(alienClients)
			local averagesReport = string.format("MarineAvg Hive Skill: %s | AlienAvg Hive Skill: %s", marineAvg, alienAvg)
			table.insert(balanceLog, averagesReport)
			TGNS.ScheduleAction(1, PrintBalanceLog)
		end

		local function BeginBalance()
			balanceLog = {}
			if Shine.Plugins.mapvote:VoteStarted() then
				md:ToAllNotifyError("Halted. Map vote in progress.")
				balanceInProgress = false
			else
				SendNextPlayer()
			end
		end

		local function svBalance(client, forcePlayersToReadyRoom)
			local player = client and TGNS.GetPlayer(client) or nil
			if balanceInProgress then
				md:ToPlayerNotifyError(player, "Balance is already in progress.")
			elseif BalanceStartedRecently() then
				md:ToPlayerNotifyError(player, string.format("Balance has a server-wide cooldown of %s seconds.", RECENT_BALANCE_DURATION_IN_SECONDS))
			elseif (Shine.Plugins.captains and Shine.Plugins.captains.IsCaptainsModeEnabled and Shine.Plugins.captains.IsCaptainsModeEnabled()) then
				md:ToPlayerNotifyError(player, "You may not Balance during Captains.")
			elseif mayBalanceAt > Shared.GetTime() and not forcePlayersToReadyRoom and not (Shared.GetTime() < 120 and TGNS.GetNumberOfConnectingPlayers() == 0) then
				md:ToPlayerNotifyError(player, "Wait a bit to let players join teams of choice.")
			elseif Shine.Plugins.mapvote:VoteStarted() then
				md:ToPlayerNotifyError(player, "You may not balance while a map vote is in progress.")
			else
				local gameState = GetGamerules():GetGameState()
				if gameState == kGameState.NotStarted or gameState == kGameState.PreGame or gameState == kGameState.WarmUp then
					local playingClients = TGNS.GetPlayingClients(TGNS.GetPlayerList())
					if #playingClients < Shine.Plugins.communityslots.Config.PublicSlots then
						md:ToAllNotifyInfo(string.format("%s is sending players to teams. Chat 'switch' if you want the other team.", client and TGNS.GetClientName(client) or "Server"))
						if forcePlayersToReadyRoom then
							TGNS.DoFor(playingClients, function(c) TGNS.ExecuteClientCommand(c, "readyroom") end)
						end
						balanceInProgress = true
						lastBalanceStartTimeInSeconds = Shared.GetTime()
						TGNS.ScheduleAction(5, BeginBalance)
						local playAfkPingSoundToAllReadyRoomPlayers = function(level)
							TGNS.DoFor(TGNS.GetClientList(TGNS.IsClientReadyRoom), function(c)
								TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(c), Shine.Plugins.arclight.HILL_SOUND, {i=level})
							end)
						end
						TGNS.DoTimes(3, function(i)
							TGNS.ScheduleAction(i-1, function() playAfkPingSoundToAllReadyRoomPlayers(4-i) end)
						end)

						-- TGNS.ScheduleAction(5, function()
						-- 	local originalGetAllPlayers = Shine.GetAllPlayers
						-- 	Shine.GetAllPlayers = function(shineSelf)
						-- 		local playersForNewGame = Shine.Plugins.communityslots:GetPlayersForNewGame()
						-- 		local players = {}
						-- 		local count = 0
						-- 		TGNS.DoFor(playersForNewGame, function(p)
						-- 			count = count + 1
						-- 			players[count] = p
						-- 		end)
						-- 		return players, count
						-- 	end
						-- 	Shine.Plugins.voterandom:ShuffleTeams()
						-- 	Shine.GetAllPlayers = originalGetAllPlayers
						-- end)
					else
						md:ToPlayerNotifyError(player, string.format("There are already %s players.", Shine.Plugins.communityslots.Config.PublicSlots))
					end
				else
					md:ToPlayerNotifyError(player, "Balance cannot be used during a game.")
				end
			end
		end

		-- local function extraShouldBeEnforcedToMarines()
		-- 	local playerList = TGNS.GetPlayerList()
		-- 	local numberOfReadyRoomClients = #TGNS.GetReadyRoomClients(playerList)
		-- 	local numberOfMarineClients = GetGamerules():GetTeam(kTeam1Index):GetNumPlayers()
		-- 	local numberOfAlienClients = GetGamerules():GetTeam(kTeam2Index):GetNumPlayers()
		-- 	local captainsModeEnabled = (Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled())
		-- 	local atLeastOneBotFound = TGNS.Any(TGNS.GetClientList(), TGNS.GetIsClientVirtual)
		-- 	local result = numberOfAlienClients > 0 and numberOfReadyRoomClients < 6 and numberOfMarineClients == numberOfAlienClients and not captainsModeEnabled and not atLeastOneBotFound
		-- 	return result
		-- end

		local readyRoomPlayerLastSpokeAt = 0
		local executeBalanceAfterFinishedTalking
		executeBalanceAfterFinishedTalking = function()
			if not TGNS.IsGameInProgress() then
				if Shared.GetTime() - readyRoomPlayerLastSpokeAt > BALANCE_VOICECOMM_TOLERANCE_IN_SECONDS then
					svBalance()	
				else
					TGNS.ScheduleAction(1, executeBalanceAfterFinishedTalking)
				end
			end
		end

		local originalGetCanPlayerHearPlayer
		originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
			local result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
			if TGNS.IsPlayerReadyRoom(speakerPlayer) then
				readyRoomPlayerLastSpokeAt = Shared.GetTime()
			end
			return result
		end)


		function Plugin:EndGame(gamerules, winningTeam)
			if Shine.GetGamemode() == "ns2" then
				mayBalanceAt = Shared.GetTime() + GAMEEND_TIME_BEFORE_BALANCE
				if not Shine.Plugins.captains:IsCaptainsNight() and not Shine.Plugins.captains:IsCaptainsMorning() then
					TGNS.ScheduleAction(GAMEEND_TIME_BEFORE_BALANCE + BALANCE_VOICECOMM_TOLERANCE_IN_SECONDS, function()
						if #TGNS.Where(TGNS.GetReadyRoomPlayers(TGNS.GetPlayerList()), function(p) return not TGNS.IsPlayerAFK(p) end) > 0 then
							executeBalanceAfterFinishedTalking()
						end
					end)
				end
				preventTeamJoinMessagesDueToRecentEndGame = true
				TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
					preventTeamJoinMessagesDueToRecentEndGame = false
				end)
				-- harvesterDecayEnabled = false
			end
		end

		function Plugin:MapChange()
			if Shine.GetGamemode() == "ns2" then
				if self.LaneInfosError then
					TGNS.DebugPrint(string.format("balance: LaneInfos configuration error - %s - %s", TGNS.GetCurrentMapName(), self.LaneInfosError), false, "laneinfos")
				end
			end
		end

		function Plugin:GetOpenLaneMessage(player)
			local teamNumber = TGNS.GetPlayerTeamNumber(player)
			-- TGNS.Log("GetOpenLaneMessage...")
			local result

			self.LaneInfosError = "no laneinfos defined for map"
			local laneInfos = {}
			TGNS.DoForPairs(self.Config.LaneInfos, function(mapName, mapInfos)
				if TGNS.GetCurrentMapName() == mapName then
					self.LaneInfosError = nil
					local mapLocationNames = TGNS.Select(GetLocations(), function(l) return l:GetName() end)
					TGNS.DoForPairs(mapInfos, function(spawnLocationName, spawnLocationInfos)
						TGNS.DoForPairs(spawnLocationInfos, function(laneName, laneLocationNames)
							local spawnLocationNameFoundInMapLocationNames = TGNS.Has(mapLocationNames, spawnLocationName)
							local allLaneLocationNamesFoundInMapLocationNames = TGNS.All(laneLocationNames, function(n) return TGNS.Has(mapLocationNames, n) end)
							if spawnLocationNameFoundInMapLocationNames and allLaneLocationNamesFoundInMapLocationNames then
								table.insert(laneInfos, {spawnLocationName=spawnLocationName, displayName=laneName, locationNames=laneLocationNames})
							else
								self.LaneInfosError = spawnLocationNameFoundInMapLocationNames and "at least one lane location not found" or string.format("%s spawn location not found", spawnLocationName)
							end
						end)
					end)
				end
			end)

			if TGNS.Any(laneInfos) then
				local spawnLocationName
				local potentialSpawnEntities = {}
				if teamNumber == kMarineTeamType then
					potentialSpawnEntities = GetEntitiesForTeam("InfantryPortal", kMarineTeamType)
				elseif teamNumber == kAlienTeamType then
					potentialSpawnEntities = GetEntitiesForTeam("Egg", kAlienTeamType)
				end
				-- TGNS.Log(string.format("potentialSpawnEntities: %s", #potentialSpawnEntities))
				potentialSpawnEntities = TGNS.Where(potentialSpawnEntities, TGNS.StructureIsAlive)
				-- TGNS.Log(string.format("potentialSpawnEntities: %s", #potentialSpawnEntities))
				local possibleSpawnLocationNames = {}
				TGNS.DoFor(potentialSpawnEntities, function(e)
					-- TGNS.Log("potentialSpawnEntities: " .. tostring(TGNS.GetEntityLocationName(e)))
					TGNS.InsertDistinctly(possibleSpawnLocationNames, TGNS.GetEntityLocationName(e))
				end)
				-- TGNS.Log("#possibleSpawnLocationNames: " .. #possibleSpawnLocationNames)
				if #possibleSpawnLocationNames == 1 then
					local spawnLocationName = TGNS.GetFirst(possibleSpawnLocationNames)
					-- TGNS.Log("spawnLocationName: " .. tostring(spawnLocationName))
					local aliveTeamNonCommanderPlayers = TGNS.Where(TGNS.GetPlayers(TGNS.Where(TGNS.GetTeamClients(teamNumber), function(c) return not TGNS.IsClientCommander(c) end)), TGNS.IsPlayerAlive)
					-- TGNS.Log("#aliveTeamNonCommanderPlayers: " .. tostring(#aliveTeamNonCommanderPlayers))
					local occupiedLocations = TGNS.Select(aliveTeamNonCommanderPlayers, TGNS.GetPlayerLocationName)
					-- TGNS.Log("occupiedLocations: " .. TGNS.Join(occupiedLocations, ", "))
					laneInfos = TGNS.Where(laneInfos, function(i) return i.spawnLocationName == spawnLocationName and not TGNS.Has(occupiedLocations, spawnLocationName) and TGNS.All(i.locationNames, function(n) return not TGNS.Has(occupiedLocations, n) end) end)
					-- TGNS.Log("#laneInfos: " .. tostring(#laneInfos))
					if #laneInfos == 1 then
						if math.random() < .2 then
							result = "Which lane is open?"
						else
							result = string.format("Is %s lane open?", TGNS.GetFirst(laneInfos).displayName)
						end
					end
				end
			end
			if not result and TGNS.PlayerIsRookie(player) then
				result = "Which lanes are open? (If you don't know what a lane is, please ask!)"
			end

			-- TGNS.Log("result: " .. tostring(result))
			return result
		end

		function Plugin:OnEntityKilled(gamerules, victimEntity, attackerEntity, inflictorEntity, point, direction)
			if Shine.GetGamemode() == "ns2" then
				if TGNS.IsGameInProgress() and TGNS.GetCurrentGameDurationInSeconds() < TGNS.ConvertMinutesToSeconds(3) then
					if victimEntity then
						local victimClient = TGNS.GetClient(victimEntity)
						if victimClient then
							TGNS.ScheduleAction(3, function()
								if Shine:IsValidClient(victimClient) then
									local victimPlayer = TGNS.GetPlayer(victimClient)
									local playerIsAboutToSpawn
									if TGNS.ClientIsMarine(victimClient) then
										playerIsAboutToSpawn = victimPlayer.GetIsRespawning and victimPlayer:GetIsRespawning()
									elseif TGNS.ClientIsAlien(victimClient) then
										playerIsAboutToSpawn = victimPlayer:GetTeam():GetActiveEggCount() >= 2
									end
									if playerIsAboutToSpawn then
										if TGNS.IsGameInProgress() then
											if TGNS.GetCurrentGameDurationInSeconds() < TGNS.ConvertMinutesToSeconds(3) then
												local minimumDelayBetweenAdvisories = 60
												lanesAdvisoryLastShownAt[victimClient] = lanesAdvisoryLastShownAt[victimClient] or (minimumDelayBetweenAdvisories * -1)
												if lanesAdvisoryLastShownAt[victimClient] < Shared.GetTime() - minimumDelayBetweenAdvisories then
													local openLaneMessage = self:GetOpenLaneMessage(victimPlayer)
													if openLaneMessage then
														lanesMd:ToPlayerNotifyInfo(victimPlayer, openLaneMessage)
														lanesAdvisoryLastShownAt[victimClient] = Shared.GetTime()
													end
												end
											else
												local minimumDelayBetweenAdvisories = 180
												if TGNS.ClientIsAlien(victimClient) then
													local personalResources = TGNS.GetClientResources(victimClient)
													onosBalanceAdvisoryLastShownAt[victimClient] = onosBalanceAdvisoryLastShownAt[victimClient] or (minimumDelayBetweenAdvisories * -1)
													if personalResources >= kOnosCost * .72 and onosBalanceAdvisoryLastShownAt[victimClient] < Shared.GetTime() - minimumDelayBetweenAdvisories then
														md:ToPlayerNotifyInfo(victimPlayer, onosBalanceAdvisory)
													end
												end
											end
										end
									end
								end
							end)
						end
					end
				end
			end
		end

		function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
			local client = TGNS.GetClient(player)
			if not balanceInProgress and not preventTeamJoinMessagesDueToRecentEndGame and (TGNS.IsGameplayTeamNumber(oldTeamNumber) or TGNS.IsGameplayTeamNumber(newTeamNumber)) and not TGNS.GetIsClientVirtual(client) then
				-- local playerList = TGNS.GetPlayerList()
				-- local marinesCount = #TGNS.GetMarineClients(playerList)
				-- local aliensCount = #TGNS.GetAlienClients(playerList)
				md:ToAllConsole(string.format("%s: %s -> %s", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetTeamName(oldTeamNumber), TGNS.GetPlayerTeamName(player)))
				-- TGNS.DebugPrint(string.format("%s: %s -> %s (Marines: %s; Aliens: %s)", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetTeamName(oldTeamNumber), TGNS.GetPlayerTeamName(player), marinesCount, aliensCount))
			end
			lastTeamNumbers[client] = newTeamNumber
		end

		function Plugin:ClientDisconnect(client)
			if client then
			    md:ToAllConsole(string.format("%s: %s -> Disconnect", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetTeamName(lastTeamNumbers[client])))
			end
		end

		function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
			if Shine.GetGamemode() == "ns2" then
				if not (force or shineForce) then
					if balanceInProgress and not (TGNS.IsTeamNumberSpectator(newTeamNumber) or TGNS.IsPlayerSpectator(player)) then
						md:ToPlayerNotifyError(player, "Balance is currently assigning players to teams.")
						return false
					end
					-- local playerIsOnPlayingTeam = TGNS.PlayerIsOnPlayingTeam(player)
					-- local playerMustStayOnPlayingTeamUntilBalanceIsOver = not TGNS.ClientAction(player, TGNS.IsClientAdmin)
					-- if BalanceStartedRecently() and playerIsOnPlayingTeam and playerMustStayOnPlayingTeamUntilBalanceIsOver then
					-- 	local playerTeamIsSizedCorrectly = not TGNS.PlayerTeamIsOverbalanced(player, TGNS.GetPlayerList())
					-- 	if playerTeamIsSizedCorrectly then
					-- 		local message = string.format("%s may not switch teams within %s seconds of Balance.", TGNS.GetPlayerName(player), RECENT_BALANCE_DURATION_IN_SECONDS)
					-- 		md:ToPlayerNotifyError(player, message)
					-- 		return false
					-- 	end
					-- end


					-- if newTeamNumber == kAlienTeamType and extraShouldBeEnforcedToMarines() then
					-- 	md:ToPlayerNotifyError(player, "Marines get the extra player on this server. If you can quickly and")
					-- 	md:ToPlayerNotifyError(player, "politely persuade anyone to go Marines for you, feel free. Don't harass.")
					-- 	TGNS.RespawnPlayer(player)
					-- 	return false
					-- 	--return true, kMarineTeamType
					-- end

				end
			    local serverIsUpdatingToReadyRoom = Shine.Plugins.updatetoreadyroomhelper and Shine.Plugins.updatetoreadyroomhelper:IsServerUpdatingToReadyRoom()
				if TGNS.IsPlayerSpectator(player) and TGNS.IsPlayerAFK(player) and serverIsUpdatingToReadyRoom then
			    	return false
			   	end
			end
		end

		updateTotalGamesPlayedCache = function(client, totalGamesPlayed)
			local steamId = TGNS.GetClientSteamId(client)
			totalGamesPlayedCache[steamId] = totalGamesPlayed
		    if not TGNS.ClientIsInGroup(client, "primerwithgames_group") and TGNS.HasClientSignedPrimerWithGames(client) then
		        TGNS.AddTempGroup(client, "primerwithgames_group")
		    end
		end

		local function refreshBalanceData(client)
			if not TGNS.GetIsClientVirtual(client) then
				local steamId = TGNS.GetClientSteamId(client)
				local balanceCacheDataForClient = TGNS.FirstOrNil(balanceCacheData, function(d) return d.steamId == steamId end)
				if balanceCacheDataForClient then
					updateTotalGamesPlayedCache(client, balanceCacheDataForClient.data.total)
					balanceCache[client] = balanceCacheDataForClient.data
				end
				if balanceCache[client] == nil then
					pdr:Load(steamId, function(loadResponse)
						if loadResponse.success then
							if Shine:IsValidClient(client) then
								updateTotalGamesPlayedCache(client, loadResponse.value.total)
								balanceCache[client] = loadResponse.value
							end
						else
							TGNS.DebugPrint("balance ERROR: unable to access data", true)
						end
					end)
				end
			end
		end

		function Plugin:ClientConnect(client)
			lastTeamNumbers[client] = 0
			refreshBalanceData(client)
		end

		function Plugin:ClientConfirmConnect(client)

			if Shine.GetGamemode() == "ns2" then
				if not firstClientProcessed then
					mayBalanceAt = Shared.GetTime() + FIRSTCLIENT_TIME_BEFORE_BALANCE
					if not Shine.Plugins.captains:IsCaptainsNight() and not Shine.Plugins.captains:IsCaptainsMorning() then
						TGNS.ScheduleAction(FIRSTCLIENT_TIME_BEFORE_BALANCE, function()
							if #TGNS.Where(TGNS.GetReadyRoomPlayers(TGNS.GetPlayerList()), function(p) return not TGNS.IsPlayerAFK(p) end) > 0 then
								executeBalanceAfterFinishedTalking()
							end
						end)
					end
					firstClientProcessed = true
				end
				local playerHasTooFewLocalScoresPerMinute = TGNS.PlayerAction(client, function(p) return #(GetPlayerBalance(p).scoresPerMinute or {}) < LOCAL_DATAPOINTS_COUNT_THRESHOLD end)
				if playerHasTooFewLocalScoresPerMinute then
					local steamId = TGNS.GetClientSteamId(client)
					-- TGNSNs2StatsProxy.AddSteamId(steamId)
				end
				if balanceCache[client] == nil then
					refreshBalanceData(client)
				end
			end

		end

		-- local function toggleBucketClient(sourceClient, targetClient, bucketName)
		-- 	TGNS.ScheduleAction(0, function() md:ToClientConsole(sourceClient, "Adjusting buckets. Wait for confirmation message.") end)
		--     npdr.Load(nil, function(loadResponse)
		--         if loadResponse.success then
		--             notedPlayersData = loadResponse.value
		-- 			local targetSteamId = TGNS.GetClientSteamId(targetClient)
		-- 			local targetName = TGNS.GetClientName(targetClient)
		-- 			notedPlayersData[bucketName] = notedPlayersData[bucketName] or {}
		--             local playerAlreadyAdded = TGNS.Any(notedPlayersData[bucketName], function(x) return x.id == targetSteamId end)
		--             local message
		--             if playerAlreadyAdded then
		--             	notedPlayersData[bucketName] = TGNS.Where(notedPlayersData[bucketName], function(x) return x.id ~= targetSteamId end)
		-- 	            message = string.format("%s removed from %s bucket.", targetName, bucketName)
		-- 	        else
		-- 	        	table.insert(notedPlayersData[bucketName], {name=targetName,id=targetSteamId})
		-- 	        	message = string.format("%s added to %s bucket.", targetName, bucketName)
		--             end
		--             npdr.Save(notedPlayersData, nil, function(saveResponse)
		--             	if saveResponse.success then
		-- 		            commanderSteamIds = TGNS.Select(notedPlayersData.Commanders, function(x) return x.id end)
		-- 		            bestPlayerSteamIds = TGNS.Select(notedPlayersData.BestPlayers, function(x) return x.id end)
		-- 		            betterPlayerSteamIds = TGNS.Select(notedPlayersData.BetterPlayers, function(x) return x.id end)
		-- 		            goodPlayerSteamIds = TGNS.Select(notedPlayersData.GoodPlayers, function(x) return x.id end)
		--             	else
		--             		message = "Error saving bucket data."
		--             		Shared.Message("balance ERROR: unable to save notedplayers data.")
		--             	end
		--             	md:ToClientConsole(sourceClient, message)
		--             end)
		--         else
		--         	md:ToClientConsole(sourceClient, "Error accessing bucket data.")
		--             Shared.Message("balance ERROR: unable to access notedplayers data.")
		--         end
		--     end)
		-- end

		-- local function toggleBucketPlayer(client, playerPredicate, bucketName)
		-- 	if playerPredicate == nil or playerPredicate == "" then
		-- 		md:ToClientConsole(client, "You must specify a player.")
		-- 	else
		-- 		local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
		-- 		if targetPlayer ~= nil then
		-- 			local targetClient = TGNS.GetClient(targetPlayer)
		-- 			toggleBucketClient(client, targetClient, bucketName)
		-- 		else
		-- 			md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerPredicate))
		-- 		end
		-- 	end
		-- end

		function Plugin:CreateCommands()

			if Shine.GetGamemode() == "ns2" then
				local balanceCommand = self:BindCommand("sh_balance", "balance", function(client)
					local playerList = TGNS.GetPlayerList()
					local primerSignersPlayingCount = #TGNS.Where(TGNS.GetClientList(function(c) return not TGNS.IsClientSpectator(c) and not TGNS.IsClientAFK(c) end), TGNS.HasClientSignedPrimerWithGames)
					local serverIsPrimed = primerSignersPlayingCount >= 12
					svBalance(client, serverIsPrimed)
				end)
				balanceCommand:Help("Balance players across teams.")

				local balanceCommand = self:BindCommand("sh_forcebalance", "forcebalance", function(client) svBalance(client, true) end)
				balanceCommand:Help("Balance players across teams (after forced RR).")

				-- local commandersCommand = self:BindCommand("sh_comm", nil, function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "Commanders") end)
				-- commandersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
				-- commandersCommand:Help("<player> Toggle player in Comm bucket")

				-- local bestPlayersCommand = self:BindCommand("sh_best", nil, function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "BestPlayers") end)
				-- bestPlayersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
				-- bestPlayersCommand:Help("<player> Toggle player in Best bucket")

				-- local betterPlayersCommand = self:BindCommand("sh_better", nil, function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "BetterPlayers") end)
				-- betterPlayersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
				-- betterPlayersCommand:Help("<player> Toggle player in Better bucket")

				-- local goodPlayersCommand = self:BindCommand("sh_good", nil, function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "GoodPlayers") end)
				-- goodPlayersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
				-- goodPlayersCommand:Help("<player> Toggle player in Good bucket")
			end





			-- local decayedHarvestersCommand = self:BindCommand("sh_decayharvesters", nil, function(client)
			-- 	md:ToClientConsole(client, "Harvesters will decay until map end.")
			-- 	harvesterDecayEnabled = true
			-- end)
			-- decayedHarvestersCommand:Help("Enable experimental harvester decay (Wyz/IronHorse)")

		end

	end

	local function OnClientInitialise()
	end

	local function OnServerInitialise()

		local balanceTempfilePath = "config://tgns/temp/balance.json"

		TGNS.RegisterEventHook("FullGamePlayed", function(clients, winningTeam)

			if Shine.GetGamemode() == "ns2" then
				local addWinToBalance = function(balance)
					balance.wins = balance.wins + 1
					balance.total = balance.total + 1
					if balance.wins + balance.losses > 100 then
						balance.losses = balance.losses - 1
					end
				end
				local addLossToBalance = function(balance)
					balance.losses = balance.losses + 1
					balance.total = balance.total + 1
					if balance.wins + balance.losses > 100 then
						balance.wins = balance.wins - 1
					end
				end

				TGNS.DoFor(clients, function(c)
					local player = TGNS.GetPlayer(c)
					local changeBalanceFunction = TGNS.PlayerIsOnTeam(player, winningTeam) and addWinToBalance or addLossToBalance
					local steamId = TGNS.GetClientSteamId(c)
					pdr:Load(steamId, function(loadResponse)
						if loadResponse.success then
							local balance = loadResponse.value
							changeBalanceFunction(balance)
							AddScorePerMinuteData(balance, TGNS.GetPlayerScorePerMinute(player))
							pdr:Save(balance, function(saveResponse)
								if saveResponse.success then
									if Shine:IsValidClient(c) then
										updateTotalGamesPlayedCache(c, balance.total)
										balanceCache[c] = loadResponse.value
										


										balanceCacheData = Shine.LoadJSONFile(balanceTempfilePath) or {}
										TGNS.RemoveAllWhere(balanceCacheData, function(d) return d.steamId == steamId end)
										table.insert(balanceCacheData, {lastCachedWhen=TGNS.GetSecondsSinceEpoch(),steamId=steamId,data=balanceCache[c]})
										Shine.SaveJSONFile(balanceCacheData, balanceTempfilePath)

									end
								else
									TGNS.DebugPrint("balance ERROR: unable to save data", true)
								end
							end)
						else
							TGNS.DebugPrint("balance ERROR: unable to access data", true)
						end
					end)
				end)
			end

		end)
		-- npdr = TGNSDataRepository.Create("notedplayers", function(data)
	 --        data.Commanders = data.Commanders or {}
	 --        data.BestPlayers = data.BestPlayers or {}
	 --        data.BetterPlayers = data.BetterPlayers or {}
	 --        data.GoodPlayers = data.GoodPlayers or {}
	 --        return data
	 --    end)

		TGNS.ScheduleAction(3, function()
		    -- npdr.Load(nil, function(loadResponse)
		    --     if loadResponse.success then
		    --         notedPlayersData = loadResponse.value
		    --         commanderSteamIds = TGNS.Select(notedPlayersData.Commanders, function(x) return x.id end)
		    --         bestPlayerSteamIds = TGNS.Select(notedPlayersData.BestPlayers, function(x) return x.id end)
		    --         betterPlayerSteamIds = TGNS.Select(notedPlayersData.BetterPlayers, function(x) return x.id end)
		    --         goodPlayerSteamIds = TGNS.Select(notedPlayersData.GoodPlayers, function(x) return x.id end)
		    --     else
		    --         Shared.Message("balance ERROR: unable to access notedplayers data.")
		    --     end
		    -- end)
		end)

		if Shine.GetGamemode() == "ns2" then
			JoinRandomTeam = function(player)
		        local team1Players = GetGamerules():GetTeam(kTeam1Index):GetNumPlayers()
		        local team2Players = GetGamerules():GetTeam(kTeam2Index):GetNumPlayers()
		        Server.ClientCommand(player, team2Players < team1Players and "jointeamtwo" or "jointeamone")
		    end
		end

	    -- TGNS.ScheduleAction(10, function()
	    -- 		local minutesToDecayFullArmorToNoArmor = 4.5
			  --   TGNS.ScheduleActionInterval(1, function()
			  --   	if TGNS.IsGameInProgress() and harvesterDecayEnabled then
			  --   		local matureArmorlessHarvesterEntityIds = {}
			  --   		TGNS.DoFor(TGNS.GetEntitiesWithClassName("Harvester"), function(h)
			  --   			if (h:GetIsBuilt()) then
			  --   				if h:GetArmor() > 0 then
					--     			local decayAmountPerSecond = h:GetMatureMaxArmor() / minutesToDecayFullArmorToNoArmor / TGNS.ConvertMinutesToSeconds(1);
					--     			local currentArmor = h:GetArmor()
					--     			local newArmor = currentArmor - decayAmountPerSecond
					--     			newArmor = newArmor > 0 and newArmor or 0
					--     			h:SetArmor(newArmor, true)
					--     			if newArmor == 0 then
					--     				-- CreatePheromone(kTechId.NeedHealingMarker, h:GetOrigin(), kAlienTeamType)
					-- 	                -- -- flash structure on map
					-- 	                -- h:GetTeam():TriggerAlert(kTechId.AlienAlertNeedHealing, h)
					-- 	                -- -- play sound
					-- 	                -- TGNS.DoFor(TGNS.GetPlayerList(), function(p)
					-- 	                -- 	TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.ARMORDECAY1)
					-- 	                -- end)
					-- 		    		-- !!! Player:TriggerAlert(techId, entity)
					--     			end
					--     			--Shared.Message(string.format("balance harvester [%s]: currentArmor: %s; decayAmountPerSecond: %s; newArmor: %s", Shared.GetTime(), currentArmor, decayAmountPerSecond, newArmor))
			  --   				else
			  --   					table.insert(matureArmorlessHarvesterEntityIds, h:GetId())
			  --   				end
			  --   			end
			  --   		end)
			  --           TGNS.DoFor(TGNS.GetAlienPlayers(TGNS.GetPlayerList()), function(p)
			  --           	TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.ARMORLESS_HARVESTERS, {l=TGNS.Join(matureArmorlessHarvesterEntityIds, ",")})
			  --           end)
			  --   	end
			  --   end)
	    -- end)

		balanceCacheData = Shine.LoadJSONFile(balanceTempfilePath) or {}
		TGNS.RemoveAllWhere(balanceCacheData, function(d) return TGNS.GetSecondsSinceEpoch() - d.lastCachedWhen > TGNS.ConvertDaysToSeconds(14) end)
		Shine.SaveJSONFile(balanceCacheData, balanceTempfilePath)


		if Shine.GetGamemode() == "ns2" then
	    	local extraIpCost = kInfantryPortalCost/2
		    local originalMarineTeamSpawnInitialStructures = MarineTeam.SpawnInitialStructures
		    MarineTeam.SpawnInitialStructures = function(selfx, techPoint)
		    	local originalGetNumPlayers = selfx.GetNumPlayers
		    	-- if selfx:GetNumPlayers() == 8 then
			    	selfx.GetNumPlayers = function(selfy)
			    		return originalGetNumPlayers(selfy) + 9
			    	end
			    	selfx:AddTeamResources(-extraIpCost)
		    	-- end
		    	local tower, commandStation = originalMarineTeamSpawnInitialStructures(selfx, techPoint)

		    	selfx.GetNumPlayers = originalGetNumPlayers
		    	return tower, commandStation
			end

			local GetPointBetween = function(startPoint, endPoint) -- lua\CommanderTutorialUtility.lua
				local startPos = startPoint
				if type(startPoint) == "function" then
					startPos = startPoint()
				end

				local endPos = endPoint
				if type(endPoint) == "function" then
					endPos = endPoint()
				end

				if not startPos or not endPos then
					return nil
				end

				local path = PointArray()
				local reachAble = Pathing.GetPathPoints(startPos, endPos, path)
				local centerPoint = nil

				if reachAble then
					local pathLength = GetPointDistance(path)
					local currentDistance = 0
					local prevPoint = path[1]
					centerPoint = path[#path]
					if #path > 2 then
						for i = 2, #path do
							currentDistance = currentDistance + (prevPoint - path[i]):GetLength()
							prevPoint = path[i]
							if currentDistance >= pathLength * 0.5 then
								centerPoint = path[i]
								break
							end
						end
					end
				end

				return centerPoint
			end

			local spawnWelderNear = function(entity)
				local locationName = TGNS.GetEntityLocationName(entity)
				local armories = GetEntitiesForTeam("Armory", kMarineTeamType)
				local nearbyOperationalArmory = TGNS.FirstOrNil(armories, function(a) return TGNS.GetEntityLocationName(a) == locationName and TGNS.StructureIsOperational(a) end)
				if nearbyOperationalArmory then
					local pointBetween = GetPointBetween(nearbyOperationalArmory:GetOrigin(), entity:GetOrigin())
					local pos = pointBetween and GetRandomBuildPosition( kTechId.Welder, pointBetween, 3 ) or GetRandomBuildPosition( kTechId.Welder, nearbyOperationalArmory:GetOrigin(), 1 )
					if pos then
						local weldersNearby = GetEntitiesForTeamWithinRange("Welder", kMarineTeamType, pos, 40)
						local unclaimedWeldersNearby = TGNS.Where(weldersNearby, function(w) return w:GetParent() == nil end)
						if #unclaimedWeldersNearby < 3 then
							CreateEntity("welder", pos, kMarineTeamType)
						end
					end
				end
			end
			
			local originalPlayingTeamReplaceRespawnPlayer
			originalPlayingTeamReplaceRespawnPlayer = TGNS.ReplaceClassMethod("PlayingTeam", "ReplaceRespawnPlayer", function(playingTeamSelf, player, origin, angles, mapName)
				local success, player = originalPlayingTeamReplaceRespawnPlayer(playingTeamSelf, player, origin, angles, mapName)
				if success and player:isa("Marine") then
					spawnWelderNear(player)
				end
				return success, player
			end)

			local originalInfantryPortalStartSpinning
			originalInfantryPortalStartSpinning = TGNS.ReplaceClassMethod("InfantryPortal", "StartSpinning", function(infantryPortalSelf)
				originalInfantryPortalStartSpinning(infantryPortalSelf)
				spawnWelderNear(infantryPortalSelf)
			end)

			TGNS.RegisterEventHook("GameCountdownStarted", function(secondsSinceEpoch)
				md:ToAllNotifyInfo(string.format("Marines start with 2 IPs (-%s team res). Armories near IPs drop free welders.", extraIpCost))
				-- md:ToAllNotifyInfo(onosBalanceAdvisory)
				-- md:ToAllNotifyInfo("These messages are printed in your console (` key).")
			end)
		end

		-- spawn IPs farther from one another (WIP; build 309)
		-- local originalGetRandomBuildPosition = GetRandomBuildPosition
		-- GetRandomBuildPosition = function(techId, aroundPos, maxDist)
		-- 	local getRandomBuildPositionResult
		-- 	local originalGetRandomPointsWithinRadius = GetRandomPointsWithinRadius
		-- 	local originalGetRandomSpawnForCapsule = GetRandomSpawnForCapsule
		-- 	if techId == kTechId.InfantryPortal then
		-- 		GetRandomPointsWithinRadius = function(center, minRadius, maxRadius, maxHeight, numPoints, minDistance, filter, validationFunc)
		-- 			return originalGetRandomPointsWithinRadius(center, minRadius, maxRadius, maxHeight, numPoints, 20, filter, validationFunc)
		-- 		end
		-- 		GetRandomSpawnForCapsule = function(capsuleHeight, capsuleRadius, origin, minRange, maxRange, filter, validationFunc)
		-- 			local getRandomSpawnForCapsuleResult = originalGetRandomSpawnForCapsule(capsuleHeight, capsuleRadius, origin, maxRange, maxRange, filter, validationFunc)
		-- 			if not getRandomSpawnForCapsuleResult then
		-- 				Shared.Message("Unable to find distant IPs... reverting to stock behavior...")
		-- 				getRandomSpawnForCapsuleResult = originalGetRandomSpawnForCapsule(capsuleHeight, capsuleRadius, origin, minRange, maxRange, filter, validationFunc)
		-- 			end
		-- 			return getRandomSpawnForCapsuleResult
		-- 		end
		-- 	end
		-- 	getRandomBuildPositionResult = originalGetRandomBuildPosition(techId, aroundPos, maxDist)
		-- 	GetRandomSpawnForCapsule = originalGetRandomSpawnForCapsule
		-- 	GetRandomPointsWithinRadius = originalGetRandomPointsWithinRadius
		-- 	return getRandomBuildPositionResult
		-- end

	    return true

	end

	function Plugin:Initialise()
		self.Enabled = true

		if Client then OnClientInitialise() end
		if Server then
			self:CreateCommands()
			OnServerInitialise()

			-- if not TGNS.IsProduction() then
			-- 	TGNS.ScheduleActionInterval(3, function()
			-- 		local client = TGNS.GetFirst(TGNS.GetClientList())
			-- 		local message = self:GetOpenLaneMessage(TGNS.GetPlayer(client))
			-- 		if message then
			-- 			local debugMd = TGNSMessageDisplayer.Create("LANESDEBUG")
			-- 			debugMd:ToAllNotifyInfo(message)
			-- 		end
			-- 	end)
			-- end
			
		end

		-- local extraMarineTeamRes = {}
		-- local extraMarinePersonalRes = {}

		-- local originalPlayingTeamAddTeamResources
		-- originalPlayingTeamAddTeamResources = TGNS.ReplaceClassMethod("PlayingTeam", "AddTeamResources", function(playingTeamSelf, amount, isIncome)
		-- 	if isIncome and playingTeamSelf:GetTeamType() == kMarineTeamType and amount > 0 then
		-- 		local gameStartTime = NS2Gamerules:GetGameStartTime()
		-- 		extraMarineTeamRes[gameStartTime] = (extraMarineTeamRes[gameStartTime] or 0) + ((amount * Shine.Plugins.balance.Config.MarineResourcesMultiplier) - amount)
		-- 		while extraMarineTeamRes[gameStartTime] >= 1 do
		-- 			amount = amount + 1
		-- 			extraMarineTeamRes[gameStartTime] = extraMarineTeamRes[gameStartTime] - 1
		-- 		end
		-- 	end
		-- 	originalPlayingTeamAddTeamResources(playingTeamSelf, amount, isIncome)
		-- end)

		-- local originalPlayerAddResources
		-- originalPlayerAddResources = TGNS.ReplaceClassMethod("Player", "AddResources", function(playerSelf, amount)
		-- 	if playerSelf:GetTeamNumber() == kMarineTeamType and amount > 0 then
		-- 		local gameStartTime = NS2Gamerules:GetGameStartTime()
		-- 		local playerId = playerSelf:GetId()
		-- 		extraMarinePersonalRes[gameStartTime] = extraMarinePersonalRes[gameStartTime] or {}
		-- 		extraMarinePersonalRes[gameStartTime][playerSelf] = (extraMarinePersonalRes[gameStartTime][playerSelf] or 0) + ((amount * Shine.Plugins.balance.Config.MarineResourcesMultiplier) - amount)
		-- 		while extraMarinePersonalRes[gameStartTime][playerSelf] >= 1 do
		-- 			amount = amount + 1
		-- 			extraMarinePersonalRes[gameStartTime][playerSelf] = extraMarinePersonalRes[gameStartTime][playerSelf] - 1
		-- 		end
		-- 	end
		-- 	local result = originalPlayerAddResources(playerSelf, amount)
		-- 	return result
		-- end)


		return true
	end

	function Plugin:Cleanup()
	    --Cleanup your extra stuff like timers, data etc.
	    self.BaseClass.Cleanup( self )
	end

	Shine:RegisterExtension("balance", Plugin )
end