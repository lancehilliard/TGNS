//Balance

if kDAKConfig and kDAKConfig.Balance then
	Script.Load("lua/TGNSCommon.lua")
	Script.Load("lua/TGNSPlayerDataRepository.lua")
	local steamIdsWhichStartedGame = {}
	local balanceLog = {}
	local balanceInProgress = false
	
	Balance = {}
	function Balance.IsInProgress()
		return balanceInProgress
	end
	
	local pdr = TGNSPlayerDataRepository.Create("balance", function(balance)
				balance.wins = balance.wins ~= nil and balance.wins or 0
				balance.losses = balance.losses ~= nil and balance.losses or 0
				balance.total = balance.total ~= nil and balance.total or 0
				return balance
			end
		)
		
	local addWinToBalance = function(balance)
			balance.wins = balance.wins + 1
			balance.total = balance.total + 1
			if balance.wins + balance.losses > 100 then
				balance.losses = balance.losses - 1
			end
			//Shared.Message(balance.steamId .. " WIN")
		end
	local addLossToBalance = function(balance) 
			balance.losses = balance.losses + 1 
			balance.total = balance.total + 1
			if balance.wins + balance.losses > 100 then
				balance.wins = balance.wins - 1
			end
			//Shared.Message(balance.steamId .. " LOSS")
		end

	local function GetWinLossRatio(balance)
		local result
		local totalGames = balance.losses + balance.wins
		local notEnoughGamesToMatter = totalGames < 10
		if notEnoughGamesToMatter then
			result = .5
		else
			result = balance.wins / totalGames
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
	
	local function GetPlayerWinLossRatio(player)
		local balance = GetPlayerBalance(player)
		local result = GetWinLossRatio(balance)
		return result
	end
    
	local function ChangeBalance(steamId, changeAction)
		local balance = pdr:Load(steamId)
		changeAction(balance)
		pdr:Save(balance)
	end
	
	local function GetWinLossAverage(clients)
		local result = 0
		if #clients > 0 then
			local total = 0
			TGNS.DoFor(clients, function(c)
				total = total + TGNS.PlayerAction(c, function(p) return GetPlayerWinLossRatio(p) end)
			end)
			result = total / #clients
		end
		return result
	end
	
	local function PrintBalanceLog(client)
		TGNS.DoFor(balanceLog, function(logline)
			TGNS.ConsolePrint(client, logline, "BALANCE")
		end)
	end
	
	local function svBalance(client)
		local gameState = GetGamerules():GetGameState()
		local whenDescriptor
		if gameState == kGameState.NotStarted or gameState == kGameState.PreGame then
			whenDescriptor = "JUST NOW"
			local playerList = TGNS.GetPlayerList()
			table.sort(playerList, function(p1, p2) return GetPlayerWinLossRatio(p1) > GetPlayerWinLossRatio(p2) end )
			TGNS.ConsolePrint(client, "Win/Loss Ratios:", "BALANCE")
			balanceLog = {}
			local teamNumber
			balanceInProgress = true
			TGNS.DoFor(playerList, function(player)
				local actionMessage
				if TGNS.IsPlayerReadyRoom(player) then
					local updatedPlayerList = TGNS.GetPlayerList()
					local marineClients = TGNS.GetMarineClients(updatedPlayerList)
					local alienClients = TGNS.GetAlienClients(updatedPlayerList)
					local marineAvg = GetWinLossAverage(marineClients)
					local alienAvg = GetWinLossAverage(alienClients)
					local marineCount = #marineClients
					local alienCount = #alienClients
					if marineAvg <= alienAvg then
						teamNumber = marineCount <= alienCount and kMarineTeamType or kAlienTeamType
					else
						teamNumber = alienCount <= marineCount and kAlienTeamType or kMarineTeamType
					end
					actionMessage = string.format("sent to %s", TGNS.GetTeamName(teamNumber))
				else
					actionMessage = string.format("ALREADY on %s", TGNS.GetPlayerTeamName(player))
				end
				table.insert(balanceLog, string.format("%s: %s with %s = %s", player:GetName(), GetPlayerWinLossRatio(player), GetPlayerBalance(player).total, actionMessage))
				if teamNumber ~= nil then
					TGNS.SendToTeam(player, teamNumber)
				end
			end)
			balanceInProgress = false
			playerList = TGNS.GetPlayerList()
			marineClients = TGNS.GetMarineClients(playerList)
			alienClients = TGNS.GetAlienClients(playerList)
			marineAvg = GetWinLossAverage(marineClients)
			alienAvg = GetWinLossAverage(alienClients)
			local averagesReport = string.format("MarineAvg: %s | AlienAvg: %s", marineAvg, alienAvg)
			table.insert(balanceLog, averagesReport)
		else
			whenDescriptor = "EARLIER"
		end
		if TGNS.IsClientAdmin(client) then
			TGNS.ConsolePrint(client, string.format("%s:", whenDescriptor), "BALANCE")
			TGNS.ScheduleAction(1, function() PrintBalanceLog(client) end)
		end
	end
	DAKCreateServerAdminCommand("Console_sv_balance", svBalance, "Balances all players based on win/loss (percentage) record.")
	
	local function BalanceOnSetGameState(self, state, currentstate)
		if state ~= currentstate then
			if TGNS.IsGameStartingState(state) then
				steamIdsWhichStartedGame = {}
				TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c) table.insert(steamIdsWhichStartedGame, TGNS.GetClientSteamId(c)) end)
			end
		end
	end
	DAKRegisterEventHook("kDAKOnSetGameState", BalanceOnSetGameState, 5)
	
	function BalanceOnGameEnd(self, winningTeam)
		TGNS.DoForClientsWithId(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c, steamId)
				if TGNS.Has(steamIdsWhichStartedGame, steamId) then
					local changeBalanceFunction = TGNS.PlayerIsOnTeam(TGNS.GetPlayer(c), winningTeam) and addWinToBalance or addLossToBalance
					ChangeBalance(steamId, changeBalanceFunction)
				end
			end
		)
	end
	DAKRegisterEventHook("kDAKOnGameEnd", BalanceOnGameEnd, 5)
	
end

Shared.Message("Balance Loading Complete")