Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSPlayerDataRepository.lua")

TGNSConnectedTimesTracker = {}

local DISCONNECTED_TIME_ALLOWED_IN_SECONDS = 300
local connectedTimes = {}
local pdr = TGNSPlayerDataRepository.Create("connectedtimes", function(data)
	data.when = data.when ~= nil and data.when or nil
	data.lastSeen = data.lastSeen ~= nil and data.lastSeen or nil
	return data
end)

function TGNSConnectedTimesTracker.SetClientConnectedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	local data = pdr:Load(steamId)
	local tooLongHasPassedSinceLastSeen = data.lastSeen == nil or (Shared.GetSystemTime() - data.lastSeen > DISCONNECTED_TIME_ALLOWED_IN_SECONDS)
	local noExistingConnectionTimeIsOnRecord = data.when == nil
	if tooLongHasPassedSinceLastSeen or noExistingConnectionTimeIsOnRecord then
		data.when = Shared.GetSystemTime()
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

local function PrintConnectedDurations(client)
	local trackedClients = GetTrackedClients()
	table.sort(trackedClients, function(c1, c2)
		return TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c1) < TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c2)
	end)
	TGNS.DoFor(trackedClients, function(c)
		local connectedTimeInSeconds = TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c)
		TGNS.ConsolePrint(client, string.format("%s: %s", TGNS.GetClientName(c), TGNS.SecondsToClock(Shared.GetSystemTime() - connectedTimeInSeconds)), "CONNECTEDTIMES")
	end)
end
TGNS.RegisterCommandHook("Console_sv_showtimes", PrintConnectedDurations, "Print connected time of each client.")

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