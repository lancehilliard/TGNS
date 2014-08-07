TGNSConnectedTimesTracker = {}

local DISCONNECTED_TIME_ALLOWED_IN_SECONDS = 300
local CONNECTION_TRACKING_INTERVAL_IN_SECONDS = 15
local connectedTimes = {}
local played = {}
local pdr = TGNSPlayerDataRepository.Create("connectedtimes", function(data)
	data.when = data.when ~= nil and data.when or nil
	data.lastSeen = data.lastSeen ~= nil and data.lastSeen or nil
	data.played = data.played ~= nil and data.played or nil
	return data
end)

local function dataUpdateAction(steamId, dataModifierAction, dataUpdatePredicate)
	pdr:Load(steamId, function(loadResponse)
		if loadResponse.success then
			local data = loadResponse.value
			local tooLongHasPassedSinceLastSeen = data.lastSeen == nil or (Shared.GetSystemTime() - data.lastSeen > DISCONNECTED_TIME_ALLOWED_IN_SECONDS)
			local noExistingConnectionTimeIsOnRecord = data.when == nil
			local tooLongOrNoExisting = tooLongHasPassedSinceLastSeen or noExistingConnectionTimeIsOnRecord
			if dataUpdatePredicate(data, tooLongOrNoExisting) then
				dataModifierAction(data, tooLongOrNoExisting)
				pdr:Save(data, function(saveResponse)
					if not saveResponse.success then
						Shared.Message("ConnectedTimesTracker ERROR: unable to save data")
					end
				end)
			end
			connectedTimes[steamId] = data.when
			played[steamId] = data.played
		else
			Shared.Message("ConnectedTimesTracker ERROR: unable to access data")
		end
	end)
end

function TGNSConnectedTimesTracker.SetClientConnectedTimeInSeconds(client, connectedTimeInSeconds)
	local steamId = TGNS.GetClientSteamId(client)
	if connectedTimeInSeconds then
		connectedTimes[steamId] = connectedTimeInSeconds
	end
	dataUpdateAction(steamId, function(data, tooLongOrNoExisting)
		data.when = connectedTimeInSeconds or Shared.GetSystemTime()
		data.played = tooLongOrNoExisting and 0 or (data.played or 0)
	end, function(data, tooLongOrNoExisting)
			return connectedTimeInSeconds or tooLongOrNoExisting
	end)
end

function TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	local result = connectedTimes[steamId] or 0
	return result
end

function TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	local result = played[steamId] or 0
	return result
end

local function GetTrackedClients()
	local allConnectedClients = TGNS.Where(TGNS.GetClients(TGNS.GetPlayerList()), function(c) return not TGNS.GetIsClientVirtual(c) end)
	local result = TGNS.Where(allConnectedClients, function(c)
		local steamId = TGNS.GetClientSteamId(c)
		return connectedTimes[steamId] ~= nil
	end)
	return result
end

function TGNSConnectedTimesTracker.PrintConnectedDurations(client)
	local trackedClients = GetTrackedClients()
	TGNS.SortDescending(trackedClients, TGNSConnectedTimesTracker.GetPlayedTimeInSeconds)
	local trackedStrangers = TGNS.Where(trackedClients, TGNS.IsClientStranger)
	local trackedPrimerOnlys = TGNS.Where(trackedClients, TGNS.IsPrimerOnlyClient)
	local trackedSupportingMembers = TGNS.Where(trackedClients, TGNS.IsClientSM)
	local md = TGNSMessageDisplayer.Create("CONNECTEDTIMES")
	local printConnectedTime = function(c)
		local connectedTimeInSeconds = TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c)
		local playedTimeInSeconds = TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(c)
		local gamesCount = Balance and Balance.GetTotalGamesPlayed and Balance.GetTotalGamesPlayed(c) or "?"
		md:ToClientConsole(client, string.format("%s> %s: %s/%s %s", TGNS.GetClientCommunityDesignationCharacter(c), TGNS.GetClientName(c), TGNS.SecondsToClock(Shared.GetSystemTime() - connectedTimeInSeconds), TGNS.SecondsToClock(playedTimeInSeconds), string.format("(games: %s%s)", gamesCount, TGNS.IsClientCommander(c) and "; Commander" or "")))
	end
	TGNS.DoFor(trackedStrangers, printConnectedTime)
	TGNS.DoFor(trackedPrimerOnlys, printConnectedTime)
	TGNS.DoFor(trackedSupportingMembers, printConnectedTime)
end

local function SetClientLastSeenNow(client)
	local steamId = TGNS.GetClientSteamId(client)
	local clientIsInGame = TGNS.IsGameInProgress() and TGNS.ClientIsOnPlayingTeam(client)
	local secondsToAddToPlayed = clientIsInGame and CONNECTION_TRACKING_INTERVAL_IN_SECONDS or 0
	dataUpdateAction(steamId, function(data, tooLongOrNoExisting)
		data.lastSeen = Shared.GetSystemTime()
		data.played = tooLongOrNoExisting and secondsToAddToPlayed or ((data.played or 0) + secondsToAddToPlayed)
	end, function(data) return true end)
end

local function SetLastSeenTimes()
	TGNS.DoFor(GetTrackedClients(), SetClientLastSeenNow)
	TGNS.ScheduleAction(CONNECTION_TRACKING_INTERVAL_IN_SECONDS, SetLastSeenTimes)
end
TGNS.ScheduleAction(CONNECTION_TRACKING_INTERVAL_IN_SECONDS, SetLastSeenTimes)

local function StripConnectedTime(client)
	local steamId = TGNS.GetClientSteamId(client)
	connectedTimes[steamId] = 0
	played[steamId] = 0
end
TGNS.RegisterEventHook("OnClientDisconnect", StripConnectedTime)