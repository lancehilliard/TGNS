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
local GAMEEND_TIME_BEFORE_BALANCE = TGNS.ENDGAME_TIME_TO_READYROOM + 10
local firstClientProcessed = false
local notedCommanderSteamIds = {}
local notedPlayerSteamIds = {}

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
	local result = balanceCache[TGNS.GetClient(player)] or {}
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
			local notedCommanders = TGNS.Where(playerList, function(p) return TGNS.Has(notedCommanderSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
			local notedPlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(notedCommanders, p) and TGNS.Has(notedPlayerSteamIds, TGNS.GetClientSteamId(TGNS.GetClient(p))) end)
			local rookiePlayers = TGNS.Where(playerList, function(p) return not TGNS.Has(notedCommanders, p) and not TGNS.Has(notedPlayers, p) and TGNS.PlayerIsRookie(p) end)
			local nonRookieStrangers = TGNS.Where(playerList, function(p) return not TGNS.Has(notedCommanders, p) and not TGNS.Has(notedPlayers, p) and not TGNS.Has(rookiePlayers, p) and TGNS.ClientAction(p, TGNS.IsClientStranger) end)
			local nonRookieRegulars = TGNS.Where(playerList, function(p) return not TGNS.Has(notedCommanders, p) and not TGNS.Has(notedPlayers, p) and not TGNS.Has(rookiePlayers, p) and not TGNS.Has(nonRookieStrangers, p) end)
			local sortAction = math.random() < 0.5 and TGNS.SortDescending or TGNS.SortAscending
			sortAction(notedCommanders, GetPlayerScorePerMinuteAverage)
			sortAction(notedPlayers, GetPlayerScorePerMinuteAverage)
			sortAction(rookiePlayers, GetPlayerScorePerMinuteAverage)
			sortAction(nonRookieStrangers, GetPlayerScorePerMinuteAverage)
			sortAction(nonRookieRegulars, GetPlayerScorePerMinuteAverage)
			local playerGroups = TGNS.GetRandomizedElements({ notedCommanders, notedPlayers, rookiePlayers, nonRookieStrangers, nonRookieRegulars })
			local addPlayerToResult = function(p) table.insert(result, p) end
			TGNS.DoFor(playerGroups, function(g) TGNS.DoFor(g, addPlayerToResult) end)
			return result
		end
		teamAverageGetter = GetScorePerMinuteAverage
	end

	local playerList = (Shine.Plugins.communityslots and Shine.Plugins.communityslots.GetPlayersForNewGame) and Shine.Plugins.communityslots:GetPlayersForNewGame() or TGNS.GetPlayerList()
	local sortedPlayers = sortedPlayersGetter(playerList)
	local eligiblePlayers = TGNS.Where(sortedPlayers, function(p) return TGNS.IsPlayerReadyRoom(p) and not TGNS.IsPlayerAFK(p) end)
	local gamerules = GetGamerules()
	local numberOfMarines = gamerules:GetTeam(kTeam1Index):GetNumPlayers()
	local numberOfAliens = gamerules:GetTeam(kTeam2Index):GetNumPlayers()
	local teamNumber = numberOfMarines <= numberOfAliens and kAlienTeamType or kMarineTeamType
	TGNS.DoFor(eligiblePlayers, function(player)
		teamNumber = teamNumber == kAlienTeamType and kMarineTeamType or kAlienTeamType
		local actionMessage = string.format("sent to %s", TGNS.GetTeamName(teamNumber))
		table.insert(balanceLog, string.format("%s: %s with %s = %s", TGNS.GetPlayerName(player), GetPlayerScorePerMinuteAverage(player), GetPlayerBalance(player).total, actionMessage))
		TGNS.SendToTeam(player, teamNumber, true)
	end)
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

local function BeginBalance()
	balanceLog = {}
	SendNextPlayer()
end

local function svBalance(client)
	local player = TGNS.GetPlayer(client)
	if balanceInProgress then
		md:ToPlayerNotifyError(player, "Balance is already in progress.")
	elseif BalanceStartedRecently() then
		md:ToPlayerNotifyError(player, string.format("Balance has a server-wide cooldown of %s seconds.", RECENT_BALANCE_DURATION_IN_SECONDS))
	elseif (Shine.Plugins.captains and Shine.Plugins.captains.IsCaptainsModeEnabled and Shine.Plugins.captains.IsCaptainsModeEnabled()) then
		md:ToPlayerNotifyError(player, "You may not Balance during Captains.")
	elseif false and mayBalanceAt > Shared.GetTime() then
		md:ToPlayerNotifyError(player, "Wait a bit to let players join teams of choice.")
	else
		local gameState = GetGamerules():GetGameState()
		if gameState == kGameState.NotStarted or gameState == kGameState.PreGame then
			md:ToAllNotifyInfo(string.format("%s is balancing teams using TG and ns2stats score-per-minute data.", TGNS.GetClientName(client)))
			--md:ToAllNotifyInfo("Scoreboard is hidden until you're placed on a team.")
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

local function extraShouldBeEnforcedToMarines()
	local playerList = TGNS.GetPlayerList()
	local numberOfReadyRoomClients = #TGNS.GetReadyRoomClients(playerList)
	local numberOfMarineClients = GetGamerules():GetTeam(kTeam1Index):GetNumPlayers()
	local numberOfAlienClients = GetGamerules():GetTeam(kTeam2Index):GetNumPlayers()
	local captainsModeEnabled = (Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled())
	local atLeastOneBotFound = TGNS.Any(TGNS.GetClientList(), TGNS.GetIsClientVirtual)
	local result = numberOfAlienClients > 0 and numberOfReadyRoomClients < 6 and numberOfMarineClients == numberOfAlienClients and not captainsModeEnabled and not atLeastOneBotFound
	return result
end

local Plugin = {}

function Plugin:EndGame(gamerules, winningTeam)
	mayBalanceAt = Shared.GetTime() + GAMEEND_TIME_BEFORE_BALANCE
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	if not (force or shineForce) then
		if balanceInProgress then
			md:ToPlayerNotifyError(player, "Balance is currently assigning players to teams.")
			return false
		end
		local playerIsOnPlayingTeam = TGNS.PlayerIsOnPlayingTeam(player)
		local playerMustStayOnPlayingTeamUntilBalanceIsOver = not TGNS.ClientAction(player, TGNS.IsClientAdmin)
		if BalanceStartedRecently() and playerIsOnPlayingTeam and playerMustStayOnPlayingTeamUntilBalanceIsOver then
			local playerTeamIsSizedCorrectly = not TGNS.PlayerTeamIsOverbalanced(player, TGNS.GetPlayerList())
			if playerTeamIsSizedCorrectly then
				local message = string.format("%s may not switch teams within %s seconds of Balance.", TGNS.GetPlayerName(player), RECENT_BALANCE_DURATION_IN_SECONDS)
				md:ToPlayerNotifyError(player, message)
				return false
			end
		end
		if newTeamNumber == kAlienTeamType and extraShouldBeEnforcedToMarines() then
			md:ToPlayerNotifyError(player, "Marines get the extra player on this server. If you can quickly and")
			md:ToPlayerNotifyError(player, "politely persuade anyone to go Marines for you, feel free. Don't harass.")
			TGNS.RespawnPlayer(player)
			return false
			--return true, kMarineTeamType
		end
	end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if BalanceStartedRecently() then
		TGNS.UpdateAllScoreboards()
	end
end

local function updateTotalGamesPlayedCache(client, totalGamesPlayed)
	local steamId = TGNS.GetClientSteamId(client)
	totalGamesPlayedCache[steamId] = totalGamesPlayed
	TGNS.ExecuteEventHooks("TotalPlayedGamesCountUpdated", client, totalGamesPlayedCache[steamId])
end

function Plugin:ClientConnect(client)
	local steamId = TGNS.GetClientSteamId(client)
	pdr:Load(steamId, function(loadResponse)
		if loadResponse.success then
			updateTotalGamesPlayedCache(client, loadResponse.value.total)
			balanceCache[client] = loadResponse.value
		else
			Shared.Message("balance ERROR: unable to access data")
		end
	end)
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

function Plugin:CreateCommands()
	local balanceCommand = self:BindCommand("sh_balance", "balance", function(client)
		svBalance(client)
	end)
	balanceCommand:Help("Balance players across teams.")
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
							updateTotalGamesPlayedCache(c, balance.total)
							balanceCache[c] = loadResponse.value
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
	TGNS.ScheduleAction(3, function()
		local npdr = TGNSDataRepository.Create("notedplayers", function(data)
	        data.NotedCommanders = data.NotedCommanders or {}
	        data.NotedPlayers = data.NotedPlayers or {}
	        return data
	    end)
	    npdr.Load(nil, function(loadResponse)
	        if loadResponse.success then
	            notedPlayersData = loadResponse.value
	            notedCommanderSteamIds = TGNS.Select(notedPlayersData.NotedCommanders, function(x) return x.id end)
	            notedPlayerSteamIds = TGNS.Select(notedPlayersData.NotedPlayers, function(x) return x.id end)
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
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("balance", Plugin )