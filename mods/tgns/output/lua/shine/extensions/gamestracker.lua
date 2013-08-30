local GameCountIncrementer = {}
GameCountIncrementer.Create = function(tableToUpdate, gamesCountTotalSetter, gamesCountAverageSetter, playersCountSetter)
	local result = {}
	result.Increment = function(steamId)
		steamId = tostring(steamId)
		tableToUpdate[steamId] = (tableToUpdate[steamId] or 0) + 1
		local totalGamesCount = 0
		local playersCount = 0
		TGNS.DoForPairs(tableToUpdate, function(steamId, gamesCount)
			totalGamesCount = totalGamesCount + gamesCount
			playersCount = playersCount + 1
		end)
		gamesCountTotalSetter(totalGamesCount)
		playersCountSetter(playersCount)
		gamesCountAverageSetter(TGNSAverageCalculator.Calculate(totalGamesCount, playersCount))
	end
	return result
end

local GameCountIncrementerFactory = {}
GameCountIncrementerFactory.Create = function(c, data)
	local result = {}
	if TGNS.IsClientSM(c) then
		result = GameCountIncrementer.Create(data.supportingMembers, function(x) data.supportingMembersGamesCountTotal = x end, function(x) data.supportingMembersGamesCountAverage = x end, function(x) data.supportingMembersCount = x end)
	elseif TGNS.IsPrimerOnlyClient(c) then
		result = GameCountIncrementer.Create(data.primerOnlys, function(x) data.primerOnlysGamesCountTotal = x end, function(x) data.primerOnlysGamesCountAverage = x end, function(x) data.primerOnlysCount = x end)
	else
		result = GameCountIncrementer.Create(data.strangers, function(x) data.strangersGamesCountTotal = x end, function(x) data.strangersGamesCountAverage = x end, function(x) data.strangersCount = x end)
	end
	return result
end

local steamIdsWhichStartedGame = {}

local dr = TGNSDataRepository.Create("gamestracker", function(data)
	data.supportingMembers = data.supportingMembers ~= nil and data.supportingMembers or {}
	data.supportingMembersCount = data.supportingMembersCount ~= nil and data.supportingMembersCount or 0
	data.supportingMembersGamesCountAverage = data.supportingMembersGamesCountAverage ~= nil and data.supportingMembersGamesCountAverage or 0
	data.supportingMembersGamesCountTotal = data.supportingMembersGamesCountTotal ~= nil and data.supportingMembersGamesCountTotal or 0
	data.primerOnlys = data.primerOnlys ~= nil and data.primerOnlys or {}
	data.primerOnlysCount = data.primerOnlysCount ~= nil and data.primerOnlysCount or 0
	data.primerOnlysGamesCountAverage = data.primerOnlysGamesCountAverage ~= nil and data.primerOnlysGamesCountAverage or 0
	data.primerOnlysGamesCountTotal = data.primerOnlysGamesCountTotal ~= nil and data.primerOnlysGamesCountTotal or 0
	data.strangers = data.strangers ~= nil and data.strangers or {}
	data.strangersCount = data.strangersCount ~= nil and data.strangersCount or 0
	data.strangersGamesCountAverage = data.strangersGamesCountAverage ~= nil and data.strangersGamesCountAverage or 0
	data.strangersGamesCountTotal = data.strangersGamesCountTotal ~= nil and data.strangersGamesCountTotal or 0
	return data
end, TGNSMonthlyNumberGetter.Get)

local Plugin = {}

function Plugin:SetGameState(gamerules, state, oldState)
	if state ~= oldState and TGNS.IsGameStartingState(state) then
		steamIdsWhichStartedGame = {}
		TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c) table.insert(steamIdsWhichStartedGame, TGNS.GetClientSteamId(c)) end)
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	local data = dr.Load()
	TGNS.DoForClientsWithId(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c, steamId)
		if TGNS.Has(steamIdsWhichStartedGame, steamId) then
			local gameCountIncrementer = GameCountIncrementerFactory.Create(c, data)
			gameCountIncrementer.Increment(steamId)
		end
	end)
	dr.Save(data)
end

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("gamestracker", Plugin )