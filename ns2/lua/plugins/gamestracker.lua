Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSAverageCalculator.lua")
Script.Load("lua/TGNSDataRepository.lua")
Script.Load("lua/TGNSMonthlyNumberGetter.lua")

local GameCountIncrementer = {}
GameCountIncrementer.Create = function(tableToUpdate, totalSetter, averageSetter)
	local result = {}
	result.Increment = function(steamId)
		steamId = tostring(steamId)
		tableToUpdate[steamId] = (tableToUpdate[steamId] or 0) + 1
		local totalGames = 0
		local playersCount = 0
		TGNS.DoForPairs(tableToUpdate, function(steamId, gamesCount)
			totalGames = totalGames + gamesCount
			playersCount = playersCount + 1
		end)
		totalSetter(totalGames)
		averageSetter(TGNSAverageCalculator.Calculate(totalGames, playersCount))
	end
	return result
end

local GameCountIncrementerFactory = {}
GameCountIncrementerFactory.Create = function(c, data)
	local result = {}
	if TGNS.IsClientSM(c) then
		result = GameCountIncrementer.Create(data.supportingMembers, function(x) data.supportingMembersTotal = x end, function(x) data.supportingMembersAverage = x end)
	elseif TGNS.IsClientPrimerOnly(c) then
		result = GameCountIncrementer.Create(data.primerOnlys, function(x) data.primerOnlysTotal = x end, function(x) data.primerOnlysAverage = x end)
	else
		result = GameCountIncrementer.Create(data.strangers, function(x) data.strangersTotal = x end, function(x) data.strangersAverage = x end)
	end
	return result
end

local steamIdsWhichStartedGame = {}

local dr = TGNSDataRepository.Create("gamestracker", function(data)
	data.supportingMembers = data.supportingMembers ~= nil and data.supportingMembers or {}
	data.supportingMembersTotal = data.supportingMembersTotal ~= nil and data.supportingMembersTotal or 0
	data.supportingMembersAverage = data.supportingMembersAverage ~= nil and data.supportingMembersAverage or 0
	data.primerOnlys = data.primerOnlys ~= nil and data.primerOnlys or {}
	data.primerOnlysTotal = data.primerOnlysTotal ~= nil and data.primerOnlysTotal or 0
	data.primerOnlysAverage = data.primerOnlysAverage ~= nil and data.primerOnlysAverage or 0
	data.strangers = data.strangers ~= nil and data.strangers or {}
	data.strangersTotal = data.strangersTotal ~= nil and data.strangersTotal or 0
	data.strangersAverage = data.strangersAverage ~= nil and data.strangersAverage or 0
	return data
end, function(recordId)
	local result = string.format("%s-%s", TGNSMonthlyNumberGetter.Get(), Server.GetIpAddress())
	return result
end)

local function OnSetGameState(self, state, currentstate)
	if state ~= currentstate and TGNS.IsGameStartingState(state) then
		steamIdsWhichStartedGame = {}
		TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c) table.insert(steamIdsWhichStartedGame, TGNS.GetClientSteamId(c)) end)
	end
end
TGNS.RegisterEventHook("OnSetGameState", OnSetGameState)

local function OnGameEnd()
	local data = dr.Load()
	TGNS.DoForClientsWithId(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c, steamId)
		if TGNS.Has(steamIdsWhichStartedGame, steamId) then
			local gameCountIncrementer = GameCountIncrementerFactory.Create(c, data)
			gameCountIncrementer.Increment(steamId)
		end
	end)
	dr.Save(data)
end
TGNS.RegisterEventHook("OnGameEnd", OnGameEnd)