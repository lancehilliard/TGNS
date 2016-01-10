TGNSConnectedTimesTracker = {}

local connectedTimesTrackerDatafilePath = "config://tgns/temp/connectedtimestracker.json"
local DISCONNECTED_TIME_ALLOWED_IN_SECONDS = 300
local TRACKING_INTERVAL_IN_SECONDS = 30
local DATA_BACKEND_UPDATE_INTERVAL_IN_SECONDS = 60
local data = {}

function TGNSConnectedTimesTracker.AddToPlayTime(client, secondsToAddToPlayed)
	local steamId = TGNS.GetClientSteamId(client)
	data[steamId] = data[steamId] or {}
	data[steamId].played = (data[steamId].played or 0) + secondsToAddToPlayed
end

function TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	data[steamId] = data[steamId] or {}
	local result = data[steamId].connectedTime or 0
	return result
end

function TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	data[steamId] = data[steamId] or {}
	local result = data[steamId].played or 0
	return result
end

function TGNSConnectedTimesTracker.PrintConnectedDurations(client)
	local humanClients = TGNS.GetHumanClientList()
	TGNS.SortDescending(humanClients, TGNSConnectedTimesTracker.GetPlayedTimeInSeconds)
	local humanStrangers = TGNS.Where(humanClients, TGNS.IsClientStranger)
	local humanPrimerOnlys = TGNS.Where(humanClients, TGNS.IsPrimerOnlyClient)
	local humanSupportingMembers = TGNS.Where(humanClients, TGNS.IsClientSM)
	local md = TGNSMessageDisplayer.Create("CONNECTEDTIMES")
	local printConnectedTime = function(c)
		local connectedTimeInSeconds = TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c)
		Shared.Message("connectedTimeInSeconds: " .. tostring(connectedTimeInSeconds))
		Shared.Message("Shared.GetSystemTime(): " .. tostring(Shared.GetSystemTime()))
		local playedTimeInSeconds = TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(c)
		local gamesCount = Balance and Balance.GetTotalGamesPlayed and Balance.GetTotalGamesPlayed(c) or "?"
		md:ToClientConsole(client, string.format("%s%s> %s: %s/%s %s", TGNS.IsPlayerAFK(TGNS.GetPlayer(c)) and "!" or "", TGNS.GetClientCommunityDesignationCharacter(c), TGNS.GetClientName(c), TGNS.SecondsToClock(Shared.GetSystemTime() - connectedTimeInSeconds), TGNS.SecondsToClock(playedTimeInSeconds), string.format("(games: %s%s)", gamesCount, TGNS.IsClientCommander(c) and "; Commander" or "")))
	end
	TGNS.DoFor(humanStrangers, printConnectedTime)
	TGNS.DoFor(humanPrimerOnlys, printConnectedTime)
	TGNS.DoFor(humanSupportingMembers, printConnectedTime)
end

TGNS.ScheduleActionInterval(TRACKING_INTERVAL_IN_SECONDS, function()
	local gameIsHumansOnly = Shine.Plugins.bots:GetTotalNumberOfBots() == 0
	TGNS.DoFor(TGNS.GetHumanClientList(), function(client)
		local steamId = TGNS.GetClientSteamId(client)
		local clientIsInGame = TGNS.IsGameInProgress() and TGNS.ClientIsOnPlayingTeam(client)
		local secondsToAddToPlayed = (clientIsInGame and gameIsHumansOnly) and TRACKING_INTERVAL_IN_SECONDS or 0
		data[steamId] = data[steamId] or {}
		if data[steamId].lastSeen ~= nil and Shared.GetSystemTime() - data[steamId].lastSeen > DISCONNECTED_TIME_ALLOWED_IN_SECONDS then
			data[steamId] = {}
		end
		data[steamId].connectedTime = data[steamId].connectedTime or Shared.GetSystemTime()
		data[steamId].played = (data[steamId].played or 0) + secondsToAddToPlayed
		data[steamId].lastSeen = Shared.GetSystemTime()
	end)
end)

TGNS.RegisterEventHook("OnClientConnect", function(client)
	local steamId = TGNS.GetClientSteamId(client)
	data[steamId] = data[steamId] or {}
	if data[steamId].lastSeen ~= nil and Shared.GetSystemTime() - data[steamId].lastSeen > DISCONNECTED_TIME_ALLOWED_IN_SECONDS then
		data[steamId] = {}
	end
	data[steamId].connectedTime = data[steamId].connectedTime or Shared.GetSystemTime()
end)

TGNS.RegisterEventHook("EndGame", function(gamerules, winningTeam)
	TGNSJsonFileTranscoder.EncodeToFile(connectedTimesTrackerDatafilePath, data)
end)

Event.Hook("MapPostLoad", function()
	local decodedData = TGNSJsonFileTranscoder.DecodeFromFile(connectedTimesTrackerDatafilePath) or {}
	TGNS.DoForPairs(decodedData, function(steamId, d)
		data[tonumber(steamId)] = d
	end)
end)