local steamIdsWhichStartedGame = {}
local balanceLog = {}
local balanceInProgress = false
local lastBalanceStartTimeInSeconds = 0
local SCORE_PER_MINUTE_DATAPOINTS_TO_KEEP = 30
local RECENT_BALANCE_DURATION_IN_SECONDS = 15
local NS2STATS_SCORE_PER_MINUTE_VALID_DATA_THRESHOLD = 30
local LOCAL_DATAPOINTS_COUNT_THRESHOLD = 10
local totalGamesPlayedCache = {}

local pdr = TGNSPlayerDataRepository.Create("balance", function(balance)
	balance.wins = balance.wins ~= nil and balance.wins or 0
	balance.losses = balance.losses ~= nil and balance.losses or 0
	balance.total = balance.total ~= nil and balance.total or 0
	balance.scoresPerMinute = balance.scoresPerMinute ~= nil and balance.scoresPerMinute or {}
	return balance
end)

local md = TGNSMessageDisplayer.Create("BALANCE")

Balance = {}
function Balance.IsInProgress()
	return balanceInProgress
end
function Balance.GetTotalGamesPlayed(client)
	local result = TGNS.GetIsClientVirtual(client) and 0 or totalGamesPlayedCache[client]
	if not result then
		local steamId = TGNS.GetClientSteamId(client)
		local data = pdr:Load(steamId)
		local result = data.total
		totalGamesPlayedCache[client] = result
	end
	return result or 0
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
	local result
	TGNS.ClientAction(player, function(c)
		local steamId = TGNS.GetClientSteamId(c)
		result = pdr:Load(steamId)
		end
	)
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
			local rookiePlayers = TGNS.Where(playerList, TGNS.PlayerIsRookie)
			local nonRookieStrangers = TGNS.Where(playerList, function(p) return not TGNS.Has(rookiePlayers, p) and TGNS.ClientAction(p, TGNS.IsClientStranger) end)
			local nonRookieRegulars = TGNS.Where(playerList, function(p) return not TGNS.Has(rookiePlayers, p) and not TGNS.Has(nonRookieStrangers, p) end)
			TGNS.SortDescending(rookiePlayers, GetPlayerScorePerMinuteAverage)
			TGNS.SortDescending(nonRookieStrangers, GetPlayerScorePerMinuteAverage)
			TGNS.SortDescending(nonRookieRegulars, GetPlayerScorePerMinuteAverage)
			local addPlayerToResult = function(p) table.insert(result, p) end
			TGNS.DoFor(rookiePlayers, addPlayerToResult)
			TGNS.DoFor(nonRookieStrangers, addPlayerToResult)
			TGNS.DoFor(nonRookieRegulars, addPlayerToResult)
			return result
		end
		teamAverageGetter = GetScorePerMinuteAverage
	end

	local playerList = TGNS.GetPlayerList()
	local sortedPlayers = sortedPlayersGetter(playerList)
	//local eligiblePlayers = TGNS.Where(sortedPlayers, function(p) return TGNS.IsPlayerReadyRoom(p) and not TGNS.IsPlayerAFK(p) end)
	local eligiblePlayers = TGNS.Where(sortedPlayers, function(p) return TGNS.IsPlayerReadyRoom(p) end)
	if #eligiblePlayers > 0 then
		local marineClients = TGNS.GetMarineClients(playerList)
		local alienClients = TGNS.GetAlienClients(playerList)
		local marineAvg = teamAverageGetter(marineClients)
		local alienAvg = teamAverageGetter(alienClients)
		local teamNumber
		local teamIsWeaker
		if #marineClients <= #alienClients then
			teamNumber = kMarineTeamType
			teamIsWeaker = marineAvg <= alienAvg
		else
			teamNumber = kAlienTeamType
			teamIsWeaker = alienAvg <= marineAvg
		end
		local player = TGNS.GetFirst(eligiblePlayers) // teamIsWeaker and TGNS.GetFirst(eligiblePlayers) or TGNS.GetLast(eligiblePlayers)
		local actionMessage = string.format("sent to %s", TGNS.GetTeamName(teamNumber))
		table.insert(balanceLog, string.format("%s: %s with %s = %s", TGNS.GetPlayerName(player), GetPlayerScorePerMinuteAverage(player), GetPlayerBalance(player).total, actionMessage))
		TGNS.SendToTeam(player, teamNumber, true)
		TGNS.ScheduleAction(0.25, SendNextPlayer)
	else
		md:ToAdminConsole("Balance finished.")
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
	local player = TGNS.GetPlayer(client)
	if balanceInProgress then
		md:ToPlayerNotifyError(player, "Balance is already in progress.")
	else
		local gameState = GetGamerules():GetGameState()
		if gameState == kGameState.NotStarted or gameState == kGameState.PreGame then
			md:ToAllNotifyInfo(string.format("%s is balancing teams using TG and ns2stats score-per-minute data.", TGNS.GetClientName(client)))
			md:ToAllNotifyInfo("Scoreboard is hidden until you're placed on a team.")
			balanceInProgress = true
			lastBalanceStartTimeInSeconds = Shared.GetTime()
			TGNS.ScheduleAction(5, BeginBalance)
			TGNS.ScheduleAction(RECENT_BALANCE_DURATION_IN_SECONDS + 1, TGNS.UpdateAllScoreboards)
			TGNS.UpdateAllScoreboards()
		else
			md:ToPlayerNotifyError(player, "Balance cannot be used during a game.")
		end
	end
end

local Plugin = {}

function Plugin:SetGameState(gamerules, state, oldState)
	if state ~= oldState then
		if TGNS.IsGameStartingState(state) then
			steamIdsWhichStartedGame = {}
			TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c) table.insert(steamIdsWhichStartedGame, TGNS.GetClientSteamId(c)) end)
		end
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.DoForClientsWithId(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c, steamId)
		if TGNS.Has(steamIdsWhichStartedGame, steamId) then
			local player = TGNS.GetPlayer(c)
			local changeBalanceFunction = TGNS.PlayerIsOnTeam(player, winningTeam) and addWinToBalance or addLossToBalance
			local balance = pdr:Load(steamId)
			changeBalanceFunction(balance)
			AddScorePerMinuteData(balance, TGNS.GetPlayerScorePerMinute(player))
			pdr:Save(balance)
			totalGamesPlayedCache[c] = nil
		end
	end)
end


function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	if balanceInProgress and not force then
		md:ToPlayerNotifyError(player, "Balance is currently assigning players to teams.")
		return false
	end
	local balanceStartedRecently = BalanceStartedRecently()
	local playerIsOnPlayingTeam = TGNS.PlayerIsOnPlayingTeam(player)
	local playerMustStayOnPlayingTeamUntilBalanceIsOver = not TGNS.ClientAction(player, TGNS.IsClientAdmin)
	if balanceStartedRecently then
		TGNS.UpdateAllScoreboards()
	end
	if balanceStartedRecently and playerIsOnPlayingTeam and playerMustStayOnPlayingTeamUntilBalanceIsOver then
		local playerTeamIsSizedCorrectly = not TGNS.PlayerTeamIsOverbalanced(player, TGNS.GetPlayerList())
		if playerTeamIsSizedCorrectly then
			local message = string.format("%s may not switch teams within %s seconds of Balance.", TGNS.GetPlayerName(player), RECENT_BALANCE_DURATION_IN_SECONDS)
			md:ToPlayerNotifyError(player, message)
			return false
		end
	end
end

TGNSScoreboardPlayerHider.RegisterHidingPredicate(function(targetPlayer, message)
	return BalanceStartedRecently() and not TGNS.PlayerIsOnPlayingTeam(targetPlayer) and not TGNS.ClientAction(targetPlayer, TGNS.IsClientAdmin)
end)

function Plugin:ClientConfirmConnect(client)
	local playerHasTooFewLocalScoresPerMinute = TGNS.PlayerAction(client, function(p) return #GetPlayerBalance(p).scoresPerMinute < LOCAL_DATAPOINTS_COUNT_THRESHOLD end)
	if playerHasTooFewLocalScoresPerMinute then
		local steamId = TGNS.GetClientSteamId(client)
		TGNSNs2StatsProxy.AddSteamId(steamId)
	end
end

function Plugin:CreateCommands()
	local balanceCommand = self:BindCommand("sh_balance", "balance", function(client)
		svBalance(client)
	end)
	balanceCommand:Help("Balance players across teams.")
end

function Plugin:Initialise()
    self.Enabled = true
	self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("balance", Plugin )