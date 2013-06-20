Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSPlayerDataRepository.lua")
Script.Load("lua/TGNSNs2StatsProxy.lua")
Script.Load("lua/TGNSAverageCalculator.lua")
Script.Load("lua/TGNSScoreboardPlayerHider.lua")
local steamIdsWhichStartedGame = {}
local balanceLog = {}
local balanceInProgress = false
local lastBalanceStartTimeInSeconds = 0
local SCORE_PER_MINUTE_DATAPOINTS_TO_KEEP = 30
local ns2statsProxy
local RECENT_BALANCE_DURATION_IN_SECONDS = 15

local pdr = TGNSPlayerDataRepository.Create("balance", function(balance)
			balance.wins = balance.wins ~= nil and balance.wins or 0
			balance.losses = balance.losses ~= nil and balance.losses or 0
			balance.total = balance.total ~= nil and balance.total or 0
			balance.scoresPerMinute = balance.scoresPerMinute ~= nil and balance.scoresPerMinute or {}
			return balance
		end
	)
	
Balance = {}
function Balance.IsInProgress()
	return balanceInProgress
end
function Balance.GetTotalGamesPlayed(client)
	local steamId = TGNS.GetClientSteamId(client)
	local data = pdr:Load(steamId)
	local result = data.total
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
		local notEnoughGamesToMatter = totalGames < 10
		if notEnoughGamesToMatter then
			result = TGNS.PlayerIsRookie(player) and 0 or .5
		else
			result = balance.wins / totalGames
		end
	end
	return result
end

local function GetPlayerBalance(player)
	local result
	TGNS.ClientAction(player, function(c) 
		local steamId = TGNS.GetClientSteamId(c)
		result = pdr:Load(steamId)
		end
	)
	return result
end

local function UpdateNs2StatsProxyWithRecordsOfPlayersWhoHaveTooFewLocalScoresPerMinute()
	local playersWithTooFewLocalScoresPerMinute = TGNS.Where(TGNS.GetPlayerList(), function(p) return #GetPlayerBalance(p).scoresPerMinute < 10 end)
	local steamIdsWithTooFewLocalScoresPerMinute = TGNS.Select(playersWithTooFewLocalScoresPerMinute, function(p) return TGNS.ClientAction(p, TGNS.GetClientSteamId) end)
	ns2statsProxy = TGNSNs2StatsProxy.Create(steamIdsWithTooFewLocalScoresPerMinute)
end
	
local function GetPlayerScorePerMinuteAverage(player)
	local balance = GetPlayerBalance(player)
	local result = #balance.scoresPerMinute < 10 and nil or TGNSAverageCalculator.CalculateFor(balance.scoresPerMinute)
	if result == nil and ns2statsProxy ~= nil then
		local steamId = TGNS.ClientAction(player, TGNS.GetClientSteamId)
		local ns2StatsPlayerRecord = ns2statsProxy.GetPlayerRecord(steamId)
		if ns2StatsPlayerRecord.HasData then
			local cumulativeScore = ns2StatsPlayerRecord.GetCumulativeScore()
			local timePlayedInMinutes = TGNS.ConvertSecondsToMinutes(ns2StatsPlayerRecord.GetTimePlayedInSeconds())
			result = TGNSAverageCalculator.Calculate(cumulativeScore, timePlayedInMinutes)
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
		TGNS.SendAdminConsoles(logline, "BALANCE")
	end)
end

local function SendNextPlayer()
	local wantToUseWinLossToBalance = false
	
	local playersBuilder
	local teamAverageGetter
	
	if wantToUseWinLossToBalance then
		playersBuilder = function(playerList)
			local playersWithFewerThanTenGames = TGNS.GetPlayers(TGNS.GetMatchingClients(playerList, function(c,p) return GetPlayerBalance(p).total < 10 end))
			local playersWithTenOrMoreGames = TGNS.GetPlayers(TGNS.GetMatchingClients(playerList, function(c,p) return GetPlayerBalance(p).total >= 10 end))
			TGNS.SortDescending(playersWithTenOrMoreGames, GetPlayerWinLossRatio)
			local result = playersWithFewerThanTenGames
			TGNS.DoFor(playersWithTenOrMoreGames, function(p)
				table.insert(result, p)
			end)
			return result
		end
		teamAverageGetter = GetWinLossAverage
	else
		playersBuilder = function(playerList)
			local result = playerList
			TGNS.SortDescending(result, GetPlayerScorePerMinuteAverage)
			return result
		end
		teamAverageGetter = GetScorePerMinuteAverage
	end

	local players = playersBuilder(TGNS.GetPlayerList())
	local readyRoomClient = TGNS.GetLastMatchingClient(players, function(c,p) return TGNS.IsPlayerReadyRoom(p) and not TGNS.IsPlayerAFK(p) end)
	if readyRoomClient then
		local player = TGNS.GetPlayer(readyRoomClient)
		local teamNumber = nil
		local actionMessage

		local playerList = TGNS.GetPlayerList()
		local marineClients = TGNS.GetMarineClients(playerList)
		local alienClients = TGNS.GetAlienClients(playerList)
		local marineAvg = teamAverageGetter(marineClients)
		local alienAvg = teamAverageGetter(alienClients)
		local marineCount = #marineClients
		local alienCount = #alienClients
		if marineAvg <= alienAvg then
			teamNumber = marineCount <= alienCount and kMarineTeamType or kAlienTeamType
		else
			teamNumber = alienCount <= marineCount and kAlienTeamType or kMarineTeamType
		end
		actionMessage = string.format("sent to %s", TGNS.GetTeamName(teamNumber))
		table.insert(balanceLog, string.format("%s: %s with %s = %s", player:GetName(), GetPlayerScorePerMinuteAverage(player), GetPlayerBalance(player).total, actionMessage))
		TGNS.SendToTeam(player, teamNumber)
		TGNS.ScheduleAction(0.25, SendNextPlayer)
	else
		TGNS.SendAdminChat("Balance finished.", "ADMINDEBUG")
		TGNS.SendAdminConsoles("Balance finished.", "ADMINDEBUG")
		Shared.Message("Balance finished.")
		balanceInProgress = false
		local playerList = TGNS.GetPlayerList()
		local marineClients = TGNS.GetMarineClients(playerList)
		local alienClients = TGNS.GetAlienClients(playerList)
		local marineAvg = teamAverageGetter(marineClients)
		local alienAvg = teamAverageGetter(alienClients)
		local averagesReport = string.format("MarineAvg: %s | AlienAvg: %s", marineAvg, alienAvg)
		table.insert(balanceLog, averagesReport)
		TGNS.ScheduleAction(1, PrintBalanceLog)
	end
end

local function BeginBalance()
	balanceLog = {}
	SendNextPlayer()
end

local function svBalance(client)
	local gameState = GetGamerules():GetGameState()
	if gameState == kGameState.NotStarted or gameState == kGameState.PreGame then
		TGNS.SendAllChat(string.format("%s is balancing teams using TG and ns2stats score-per-minute data.", TGNS.GetClientName(client)), "TacticalGamer.com")
		TGNS.SendAllChat(string.format("The scoreboard will be hidden until teams are balanced.", TGNS.GetClientName(client)), "TacticalGamer.com")
		balanceInProgress = true
		lastBalanceStartTimeInSeconds = Shared.GetTime()
		TGNS.ScheduleAction(1, UpdateNs2StatsProxyWithRecordsOfPlayersWhoHaveTooFewLocalScoresPerMinute)
		TGNS.ScheduleAction(5, BeginBalance)
		TGNS.ScheduleAction(RECENT_BALANCE_DURATION_IN_SECONDS + 1, TGNS.UpdateAllScoreboards)
		TGNS.UpdateAllScoreboards()
	end
end
TGNS.RegisterCommandHook("Console_sv_balance", svBalance, "Balances all players based on TG win/loss (percentage) record.")

local function BalanceOnSetGameState(self, state, currentstate)
	if state ~= currentstate then
		if TGNS.IsGameStartingState(state) then
			steamIdsWhichStartedGame = {}
			TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c) table.insert(steamIdsWhichStartedGame, TGNS.GetClientSteamId(c)) end)
		end
	end
end
TGNS.RegisterEventHook("OnSetGameState", BalanceOnSetGameState)

local function BalanceOnGameEnd(self, winningTeam)
	TGNS.DoForClientsWithId(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c, steamId)
			if TGNS.Has(steamIdsWhichStartedGame, steamId) then
				local player = TGNS.GetPlayer(c)
				local changeBalanceFunction = TGNS.PlayerIsOnTeam(player, winningTeam) and addWinToBalance or addLossToBalance
				local balance = pdr:Load(steamId)
				changeBalanceFunction(balance)
				AddScorePerMinuteData(balance, TGNS.GetPlayerScorePerMinute(player))
				pdr:Save(balance)
			end
		end
	)
end
TGNS.RegisterEventHook("OnGameEnd", BalanceOnGameEnd)

TGNS.RegisterEventHook("OnTeamJoin", function(self, player, newTeamNumber, force)
	if BalanceStartedRecently() then
		TGNS.UpdateAllScoreboards()
	end
	local cancel = false
	cancel = BalanceStartedRecently() and TGNS.PlayerIsOnPlayingTeam(player) and not TGNS.ClientAction(player, TGNS.IsClientAdmin)
	if cancel then
		local message = string.format("%s may not switch teams within %s seconds of Balance.", TGNS.GetPlayerName(player), RECENT_BALANCE_DURATION_IN_SECONDS)
		TGNS.SendAllChat(message, "BALANCE")
	end
	return cancel
end)

TGNSScoreboardPlayerHider.RegisterHidingPredicate(function(targetPlayer, message)
	return BalanceStartedRecently() and not TGNS.PlayerIsOnPlayingTeam(targetPlayer)
end)