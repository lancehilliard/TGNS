//Balance

if kDAKConfig and kDAKConfig.Balance then
	Script.Load("lua/TGNSCommon.lua")

	local steamIdsWhichStartedGame = {}
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
		if notEnoughGamesToMatter then
			result = .5
		else
			result = balance.wins / totalGames
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
		end
		if result == nil then
			result = {}
		end
		if result.wins == nil then
			result.wins = 0
		end
		if result.losses == nil then
			result.losses = 0
		end
		if result.total == nil then
			result.total = 0
		end
		if result.steamId == nil then
			result.steamId = steamId
		end
		return result
	end
	
	local function GetPlayerBalance(player)
		local result
		TGNS:ClientAction(player, function(c) 
			local steamId = TGNS:GetClientSteamId(c)
			result = LoadBalance(steamId)
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
		local balance = LoadBalance(steamId)
		changeAction(balance)
		SaveBalance(balance)
	end

	local function svBalance(client)
		local playerList = TGNS:GetPlayerList()
		table.sort(playerList, function(p1, p2) return GetPlayerWinLossRatio(p1) < GetPlayerWinLossRatio(p2) end )
		TGNS:ConsolePrint(client, "Win/Loss Ratios:", "BALANCE")
		TGNS:DoFor(playerList, function(player)
				TGNS:ConsolePrint(client, string.format("%s: %s with %s", player:GetName(), GetPlayerWinLossRatio(player), GetPlayerBalance(player).total), "BALANCE")
				JoinRandomTeam(player)
			end
		)
	end
	DAKCreateServerAdminCommand("Console_sv_balance", svBalance, "Balances all players based on win/loss (percentage) record.")
	
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