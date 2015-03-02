local balanceLog = {}
local balanceInProgress = false
local lastBalanceStartTimeInSeconds = 0
local SCORE_PER_MINUTE_DATAPOINTS_TO_KEEP = 30
local RECENT_BALANCE_DURATION_IN_SECONDS = 15
local NS2STATS_SCORE_PER_MINUTE_VALID_DATA_THRESHOLD = 30
local LOCAL_DATAPOINTS_COUNT_THRESHOLD = 10
local totalGamesPlayedCache = {}
local balanceCache = {}
local mayBalanceAt = 0
local FIRSTCLIENT_TIME_BEFORE_BALANCE = 30
local GAMEEND_TIME_BEFORE_BALANCE = TGNS.ENDGAME_TIME_TO_READYROOM + 3
local firstClientProcessed = false
local commanderSteamIds = {}
local bestPlayerSteamIds = {}
local betterPlayerSteamIds = {}
local goodPlayerSteamIds = {}
local balanceDataInitializer = function(balance)
	balance.wins = balance.wins ~= nil and balance.wins or 0
	balance.losses = balance.losses ~= nil and balance.losses or 0
	balance.total = balance.total ~= nil and balance.total or 0
	balance.scoresPerMinute = balance.scoresPerMinute ~= nil and balance.scoresPerMinute or {}
	return balance
end
local npdr

local pdr = TGNSPlayerDataRepository.Create("balance", balanceDataInitializer)

local md = TGNSMessageDisplayer.Create("BALANCE")

Balance = {}
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

local function BalanceStartedRecently()
	local result = Shared.GetTime() > RECENT_BALANCE_DURATION_IN_SECONDS and Shared.GetTime() - lastBalanceStartTimeInSeconds < RECENT_BALANCE_DURATION_IN_SECONDS
	return result
end

local function AddScorePerMinuteData(balance, scorePerMinute)
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

	local playerSortValueGetter = TGNS.GetPlayerHiveSkillRank -- GetPlayerScorePerMinuteAverage

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
			local result = {}
			local commanders = TGNS.Take(TGNS.GetRandomizedElements(TGNS.Where(playerList, function(p) return TGNS.Has(commanderSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)), 2)
			local bestPlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and TGNS.Has(bestPlayerSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
			local betterPlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and TGNS.Has(betterPlayerSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
			local goodPlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and TGNS.Has(goodPlayerSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
			local rookiePlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and not TGNS.Has(goodPlayers, p) and TGNS.PlayerIsRookie(p) end)
			local nonRookieStrangers = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and not TGNS.Has(goodPlayers, p) and not TGNS.Has(rookiePlayers, p) and TGNS.ClientAction(p, TGNS.IsClientStranger) end)
			local nonRookieRegulars = TGNS.Where(playerList, function(p) return not TGNS.Has(commanders, p) and not TGNS.Has(bestPlayers, p) and not TGNS.Has(betterPlayers, p) and not TGNS.Has(goodPlayers, p) and not TGNS.Has(rookiePlayers, p) and not TGNS.Has(nonRookieStrangers, p) end)
			local sortAction = math.random() < 0.5 and TGNS.SortDescending or TGNS.SortAscending
			sortAction(commanders, playerSortValueGetter)
			sortAction(bestPlayers, playerSortValueGetter)
			sortAction(betterPlayers, playerSortValueGetter)
			sortAction(goodPlayers, playerSortValueGetter)
			sortAction(rookiePlayers, playerSortValueGetter)
			sortAction(nonRookieStrangers, playerSortValueGetter)
			sortAction(nonRookieRegulars, playerSortValueGetter)
			local playerGroups = { commanders, bestPlayers, betterPlayers, goodPlayers, rookiePlayers, nonRookieStrangers, nonRookieRegulars }
			local addPlayerToResult = function(p) table.insert(result, p) end
			TGNS.DoFor(playerGroups, function(g) TGNS.DoFor(g, addPlayerToResult) end)
			return result
		end
		teamAverageGetter = GetScorePerMinuteAverage
	end

	local playerList = (Shine.Plugins.communityslots and Shine.Plugins.communityslots.GetPlayersForNewGame) and Shine.Plugins.communityslots:GetPlayersForNewGame() or TGNS.GetPlayerList()
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
	local averagesReport = string.format("MarineAvg SPM: %s | AlienAvg SPM: %s", marineAvg, alienAvg)
	table.insert(balanceLog, averagesReport)
	TGNS.ScheduleAction(1, PrintBalanceLog)
end

-- local function pickTeamForExtraPlayer(player)
-- 	local result
-- 	local client = TGNS.GetClient(player)
-- 	if client then
-- 		local playerList = TGNS.GetPlayerList()
-- 		local marinePlayers = TGNS.GetMarinePlayers(playerList)
-- 		local alienPlayers = TGNS.GetAlienPlayers(playerList)
-- 		local marinesCurrentGameSpms = TGNS.Select(marinePlayers, TGNS.GetPlayerScorePerMinute)
-- 		local aliensCurrentGameSpms = TGNS.Select(alienPlayers, TGNS.GetPlayerScorePerMinute)
-- 		local marinesCurrentGameAverageSpm = TGNSAverageCalculator.CalculateFor(marinesCurrentGameSpms)
-- 		local aliensCurrentGameAverageSpm = TGNSAverageCalculator.CalculateFor(aliensCurrentGameSpms)

-- 		local marineClients = TGNS.GetClients(marinePlayers)
-- 		local alienClients = TGNS.GetClients(alienPlayers)
-- 		local marinesHistoricalAverageSpm = GetScorePerMinuteAverage(marineClients)
-- 		local aliensHistoricalAverageSpm = GetScorePerMinuteAverage(alienClients)

-- 		local marinesCertainlyNeedExtraPlayer = (marinesCurrentGameAverageSpm < aliensCurrentGameAverageSpm) and (marinesHistoricalAverageSpm < aliensHistoricalAverageSpm)
-- 		local aliensCertainlyNeedExtraPlayer = (marinesCurrentGameAverageSpm < aliensCurrentGameAverageSpm) and (marinesHistoricalAverageSpm < aliensHistoricalAverageSpm)

-- 		if marinesCertainlyNeedExtraPlayer then
-- 			result = kMarineTeamType
-- 		elseif aliensCertainlyNeedExtraPlayer then
-- 			result = kAlienTeamType
-- 		end

-- 	end
-- 	return result
-- end

local function BeginBalance(originatingPlayer)
	balanceLog = {}
	if Shine.Plugins.mapvote:VoteStarted() then
		md:ToPlayerNotifyError(originatingPlayer, "Halted. Map vote in progress.")
	else
		SendNextPlayer()
	end
end

local function svBalance(client, forcePlayersToReadyRoom)
	local player = TGNS.GetPlayer(client)
	if balanceInProgress then
		md:ToPlayerNotifyError(player, "Balance is already in progress.")
	elseif BalanceStartedRecently() then
		md:ToPlayerNotifyError(player, string.format("Balance has a server-wide cooldown of %s seconds.", RECENT_BALANCE_DURATION_IN_SECONDS))
	elseif (Shine.Plugins.captains and Shine.Plugins.captains.IsCaptainsModeEnabled and Shine.Plugins.captains.IsCaptainsModeEnabled()) then
		md:ToPlayerNotifyError(player, "You may not Balance during Captains.")
	elseif mayBalanceAt > Shared.GetTime() and not forcePlayersToReadyRoom then
		md:ToPlayerNotifyError(player, "Wait a bit to let players join teams of choice.")
	elseif Shine.Plugins.mapvote:VoteStarted() then
		md:ToPlayerNotifyError(player, "You may not balance while a map vote is in progress.")
	else
		local gameState = GetGamerules():GetGameState()
		if gameState == kGameState.NotStarted or gameState == kGameState.PreGame then
			md:ToAllNotifyInfo(string.format("%s is sending players to teams.", TGNS.GetClientName(client)))
			local playingClients = TGNS.GetPlayingClients(TGNS.GetPlayerList())
			if forcePlayersToReadyRoom then
				TGNS.DoFor(playingClients, function(c) TGNS.ExecuteClientCommand(c, "readyroom") end)
			end
			balanceInProgress = true
			lastBalanceStartTimeInSeconds = Shared.GetTime()
			TGNS.ScheduleAction(5, function() BeginBalance(player) end)
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

local Plugin = {}

function Plugin:EndGame(gamerules, winningTeam)
	mayBalanceAt = Shared.GetTime() + GAMEEND_TIME_BEFORE_BALANCE
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if not balanceInProgress and (TGNS.IsGameplayTeamNumber(oldTeamNumber) or TGNS.IsGameplayTeamNumber(newTeamNumber)) then
		local client = TGNS.GetClient(player)
		md:ToAllConsole(string.format("%s: %s -> %s", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetTeamName(oldTeamNumber), TGNS.GetPlayerTeamName(player)))
	end
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	if not (force or shineForce) then
		if balanceInProgress and not TGNS.IsTeamNumberSpectator(newTeamNumber) then
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
end

local function updateTotalGamesPlayedCache(client, totalGamesPlayed)
	local steamId = TGNS.GetClientSteamId(client)
	totalGamesPlayedCache[steamId] = totalGamesPlayed
	TGNS.ExecuteEventHooks("TotalPlayedGamesCountUpdated", client, totalGamesPlayedCache[steamId])
end

function Plugin:ClientConnect(client)
	if not TGNS.GetIsClientVirtual(client) then
		local steamId = TGNS.GetClientSteamId(client)
		pdr:Load(steamId, function(loadResponse)
			if loadResponse.success then
				if Shine:IsValidClient(client) then
					updateTotalGamesPlayedCache(client, loadResponse.value.total)
					balanceCache[client] = loadResponse.value
				end
			else
				Shared.Message("balance ERROR: unable to access data")
			end
		end)
	end
end

function Plugin:ClientConfirmConnect(client)
	if not firstClientProcessed then
		mayBalanceAt = Shared.GetTime() + FIRSTCLIENT_TIME_BEFORE_BALANCE
		firstClientProcessed = true
	end
	local playerHasTooFewLocalScoresPerMinute = TGNS.PlayerAction(client, function(p) return #(GetPlayerBalance(p).scoresPerMinute or {}) < LOCAL_DATAPOINTS_COUNT_THRESHOLD end)
	if playerHasTooFewLocalScoresPerMinute then
		local steamId = TGNS.GetClientSteamId(client)
		TGNSNs2StatsProxy.AddSteamId(steamId)
	end
end

local function toggleBucketClient(sourceClient, targetClient, bucketName)
	TGNS.ScheduleAction(0, function() md:ToClientConsole(sourceClient, "Adjusting buckets. Wait for confirmation message.") end)
    npdr.Load(nil, function(loadResponse)
        if loadResponse.success then
            notedPlayersData = loadResponse.value
			local targetSteamId = TGNS.GetClientSteamId(targetClient)
			local targetName = TGNS.GetClientName(targetClient)
			notedPlayersData[bucketName] = notedPlayersData[bucketName] or {}
            local playerAlreadyAdded = TGNS.Any(notedPlayersData[bucketName], function(x) return x.id == targetSteamId end)
            local message
            if playerAlreadyAdded then
            	notedPlayersData[bucketName] = TGNS.Where(notedPlayersData[bucketName], function(x) return x.id ~= targetSteamId end)
	            message = string.format("%s removed from %s bucket.", targetName, bucketName)
	        else
	        	table.insert(notedPlayersData[bucketName], {name=targetName,id=targetSteamId})
	        	message = string.format("%s added to %s bucket.", targetName, bucketName)
            end
            npdr.Save(notedPlayersData, nil, function(saveResponse)
            	if saveResponse.success then
		            commanderSteamIds = TGNS.Select(notedPlayersData.Commanders, function(x) return x.id end)
		            bestPlayerSteamIds = TGNS.Select(notedPlayersData.BestPlayers, function(x) return x.id end)
		            betterPlayerSteamIds = TGNS.Select(notedPlayersData.BetterPlayers, function(x) return x.id end)
		            goodPlayerSteamIds = TGNS.Select(notedPlayersData.GoodPlayers, function(x) return x.id end)
            	else
            		message = "Error saving bucket data."
            		Shared.Message("balance ERROR: unable to save notedplayers data.")
            	end
            	md:ToClientConsole(sourceClient, message)
            end)
        else
        	md:ToClientConsole(sourceClient, "Error accessing bucket data.")
            Shared.Message("balance ERROR: unable to access notedplayers data.")
        end
    end)
end

local function toggleBucketPlayer(client, playerPredicate, bucketName)
	if playerPredicate == nil or playerPredicate == "" then
		md:ToClientConsole(client, "You must specify a player.")
	else
		local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
		if targetPlayer ~= nil then
			local targetClient = TGNS.GetClient(targetPlayer)
			toggleBucketClient(client, targetClient, bucketName)
		else
			md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerPredicate))
		end
	end
end

function Plugin:CreateCommands()
	local balanceCommand = self:BindCommand("sh_balance", "balance", svBalance)
	balanceCommand:Help("Balance players across teams.")

	local balanceCommand = self:BindCommand("sh_forcebalance", "forcebalance", function(client) svBalance(client, true) end)
	balanceCommand:Help("Balance players across teams (after forced RR).")

	local commandersCommand = self:BindCommand("sh_comm", "comm", function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "Commanders") end)
	commandersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
	commandersCommand:Help("<player> Toggle player in Comm bucket")

	local bestPlayersCommand = self:BindCommand("sh_best", "best", function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "BestPlayers") end)
	bestPlayersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
	bestPlayersCommand:Help("<player> Toggle player in Best bucket")

	local betterPlayersCommand = self:BindCommand("sh_better", "better", function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "BetterPlayers") end)
	betterPlayersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
	betterPlayersCommand:Help("<player> Toggle player in Better bucket")

	local goodPlayersCommand = self:BindCommand("sh_good", "good", function(client, playerPredicate) toggleBucketPlayer(client, playerPredicate, "GoodPlayers") end)
	goodPlayersCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
	goodPlayersCommand:Help("<player> Toggle player in Good bucket")
end

function Plugin:Initialise()
    self.Enabled = true
	self:CreateCommands()
	TGNS.RegisterEventHook("FullGamePlayed", function(clients, winningTeam)
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
							end
						else
							Shared.Message("balance ERROR: unable to save data")
						end
					end)
				else
					Shared.Message("balance ERROR: unable to access data")
				end
			end)
		end)
	end)
	npdr = TGNSDataRepository.Create("notedplayers", function(data)
        data.Commanders = data.Commanders or {}
        data.BestPlayers = data.BestPlayers or {}
        data.BetterPlayers = data.BetterPlayers or {}
        data.GoodPlayers = data.GoodPlayers or {}
        return data
    end)

	TGNS.ScheduleAction(3, function()
	    npdr.Load(nil, function(loadResponse)
	        if loadResponse.success then
	            notedPlayersData = loadResponse.value
	            commanderSteamIds = TGNS.Select(notedPlayersData.Commanders, function(x) return x.id end)
	            bestPlayerSteamIds = TGNS.Select(notedPlayersData.BestPlayers, function(x) return x.id end)
	            betterPlayerSteamIds = TGNS.Select(notedPlayersData.BetterPlayers, function(x) return x.id end)
	            goodPlayerSteamIds = TGNS.Select(notedPlayersData.GoodPlayers, function(x) return x.id end)
	        else
	            Shared.Message("balance ERROR: unable to access notedplayers data.")
	        end
	    end)
	end)
	JoinRandomTeam = function(player)
        local team1Players = GetGamerules():GetTeam(kTeam1Index):GetNumPlayers()
        local team2Players = GetGamerules():GetTeam(kTeam2Index):GetNumPlayers()
        Server.ClientCommand(player, team2Players < team1Players and "jointeamtwo" or "jointeamone")
    end

 --    local originalMarineTeamSpawnInitialStructures = MarineTeam.SpawnInitialStructures
 --    MarineTeam.SpawnInitialStructures = function(selfx, techPoint)
 --    	local extraIpCost = kInfantryPortalCost/2
 --    	local originalGetNumPlayers = selfx.GetNumPlayers
 --    	-- if selfx:GetNumPlayers() == 8 then
	--     	selfx.GetNumPlayers = function(selfy)
	--     		return originalGetNumPlayers(selfy) + 9
	--     	end
	--     	selfx:AddTeamResources(-extraIpCost)
 --    	-- end
 --    	local tower, commandStation = originalMarineTeamSpawnInitialStructures(selfx, techPoint)
 --    	md:ToTeamNotifyInfo(selfx:GetTeamNumber(), string.format("Marines get extra IP and lose %s resources.", extraIpCost))

 --    	selfx.GetNumPlayers = originalGetNumPlayers
 --    	return tower, commandStation
	-- end

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("balance", Plugin )