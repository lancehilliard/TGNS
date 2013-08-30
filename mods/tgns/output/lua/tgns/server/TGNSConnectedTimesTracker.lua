TGNSConnectedTimesTracker = {}

local DISCONNECTED_TIME_ALLOWED_IN_SECONDS = 300
local connectedTimes = {}
local pdr = TGNSPlayerDataRepository.Create("connectedtimes", function(data)
	data.when = data.when ~= nil and data.when or nil
	data.lastSeen = data.lastSeen ~= nil and data.lastSeen or nil
	return data
end)

function TGNSConnectedTimesTracker.SetClientConnectedTimeInSeconds(client, connectedTimeInSeconds)
	local steamId = TGNS.GetClientSteamId(client)
	local data = pdr:Load(steamId)
	local tooLongHasPassedSinceLastSeen = data.lastSeen == nil or (Shared.GetSystemTime() - data.lastSeen > DISCONNECTED_TIME_ALLOWED_IN_SECONDS)
	local noExistingConnectionTimeIsOnRecord = data.when == nil
	if connectedTimeInSeconds or tooLongHasPassedSinceLastSeen or noExistingConnectionTimeIsOnRecord then
		data.when = connectedTimeInSeconds or Shared.GetSystemTime()
		pdr:Save(data)
	end
	connectedTimes[steamId] = data.when
end

function TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	local result = connectedTimes[steamId]
	if result == nil then
		local data = pdr:Load(steamId)
		result = data.when
	end
	result = result ~= nil and result or 0
	return result
end

local function GetTrackedClients()
	local allConnectedClients = TGNS.GetClients(TGNS.GetPlayerList())
	local result = TGNS.Where(allConnectedClients, function(c)
		local steamId = TGNS.GetClientSteamId(c)
		return connectedTimes[steamId] ~= nil
	end)
	return result
end

//function TGNSConnectedTimesTracker.PrintConnectedDurations(client)
//	local trackedClients = GetTrackedClients()
//	TGNS.SortAscending(trackedClients, TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds)
//	local trackedStrangers = TGNS.Where(trackedClients, TGNS.IsClientStranger)
//	local trackedPrimerOnlys = TGNS.Where(trackedClients, TGNS.IsPrimerOnlyClient)
//	local trackedSupportingMembers = TGNS.Where(trackedClients, TGNS.IsClientSM)
//	local printConnectedTime = function(c)
//		local connectedTimeInSeconds = TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c)
//		TGNS.ConsolePrint(client, string.format("%s> %s: %s", TGNS.GetClientCommunityDesignationCharacter(c), TGNS.GetClientName(c), TGNS.SecondsToClock(Shared.GetSystemTime() - connectedTimeInSeconds)), "CONNECTEDTIMES")
//	end
//	TGNS.DoFor(trackedStrangers, printConnectedTime)
//	TGNS.DoFor(trackedPrimerOnlys, printConnectedTime)
//	TGNS.DoFor(trackedSupportingMembers, printConnectedTime)
//end
//TGNS.RegisterCommandHook("Console_sv_showtimes", TGNSConnectedTimesTracker.PrintConnectedDurations, "Print connected time of each client.")

local function SetClientLastSeenNow(client)
	local steamId = TGNS.GetClientSteamId(client)
	local data = pdr:Load(steamId)
	data.lastSeen = Shared.GetSystemTime()
	pdr:Save(data)
end

local function SetLastSeenTimes()
	TGNS.DoFor(GetTrackedClients(), SetClientLastSeenNow)
	TGNS.ScheduleAction(30, SetLastSeenTimes)
end
TGNS.ScheduleAction(30, SetLastSeenTimes)

local function StripConnectedTime(client)
	local steamId = TGNS.GetClientSteamId(client)
	connectedTimes[steamId] = 0
end
TGNS.RegisterEventHook("OnClientDisconnect", StripConnectedTime)