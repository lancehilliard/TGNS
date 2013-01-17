//Balance

if kDAKConfig and kDAKConfig.Balance then
	Script.Load("lua/TGNSCommon.lua")

	local steamIdsWhichStartedGame = {}
	local addWinToBalance = function(balance)
			balance.wins = balance.wins + 1 
		end
	local addLossToBalance = function(balance) 
			balance.losses = balance.losses + 1 
		end

	local function GetDataFilename(steamId)
		return TGNS:GetDataFilename("balance", steamId)
	end

	local function SaveBalance(balance)
		local balanceFilename = GetDataFilename(balance.steamId)
		local balanceFile = io.open(balanceFilename, "w+")
		if balanceFile then
			balanceFile:write(json.encode(balance))
			balanceFile:close()
		end
	end
	
	local function GetWinLossRatio(balance)
		local result
		local totalGames = balance.losses + balance.wins
		local notEnoughGamesToMatter = totalGames < 10
		local allGamesWon = not noGamesPlayed and balance.losses == 0
		if notEnoughGamesToMatter then
			result = .5
		else
			result = allGamesWon and 1 or balance.wins / totalGames
		end
		return result
	end

	local function LoadBalance(steamId)
		local result = nil
		local balanceFilename = GetDataFilename(steamId)
		local balanceFile = io.open(balanceFilename, "r")
		if balanceFile then
			result = json.decode(balanceFile:read("*all")) or { }
			balanceFile:close()
		else
			result = { steamId = steamId, wins = 0, losses = 0 }
		end
		return result
	end
	
	local function GetPlayerWinLossRatio(player)
		local result
		TGNS:ClientAction(player, function(c) 
				local steamId = TGNS:GetClientSteamId(c)
				local balance = LoadBalance(steamId)
				result = GetWinLossRatio(balance)
			end
		)
		return result
	end
    
	local function ChangeBalance(steamId, changeAction)
		local balance = LoadBalance(steamId)
		changeAction(balance)
		SaveBalance(balance)
	end

	local function svBalance(client)
		local playerList = TGNS:GetPlayerList()
		table.sort(playerList, function(p1, p2) return GetPlayerWinLossRatio(p1) < GetPlayerWinLossRatio(p2) end )
		TGNS:ConsolePrint(client, "Win/Loss Ratios:", "BALANCE")
		TGNS:DoFor(playerList, function(player)
				TGNS:ConsolePrint(client, string.format("%s: %s", player:GetName(), GetPlayerWinLossRatio(player)), "BALANCE")
				JoinRandomTeam(player)
			end
		)
	end
	DAKCreateServerAdminCommand("Console_sv_balance", svBalance, "<balance> Balances all players based on win/loss (percentage) record.")
	
	local function BalanceOnSetGameState(self, state, currentstate)
		if state ~= currentstate then
			if TGNS:IsGameStartingState(state) then
				steamIdsWhichStartedGame = {}
				TGNS:DoFor(TGNS:GetPlayingClients(TGNS:GetPlayerList()), function(c) table.insert(steamIdsWhichStartedGame, TGNS:GetClientSteamId(c)) end)
			elseif TGNS:IsGameWinningState(state) then
				local winningTeamNumber = state == kGameState.Team1Won and kMarineTeamType or kAlienTeamType
				TGNS:DoFor(TGNS:GetPlayingClients(TGNS:GetPlayerList()), function(c)
						local steamId = TGNS:GetClientSteamId(c)
						if TGNS:Has(steamIdsWhichStartedGame, steamId) then
							local changeBalanceFunction = TGNS:PlayerIsOnWinningTeam(TGNS:GetPlayer(c)) and addWinToBalance or addLossToBalance
							ChangeBalance(steamId, changeBalanceFunction)
						end
					end
				)
			end
		end
	end
	DAKRegisterEventHook(kDAKOnSetGameState, BalanceOnSetGameState, 5)
end

Shared.Message("Balance Loading Complete")