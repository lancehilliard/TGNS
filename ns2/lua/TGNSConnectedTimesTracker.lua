Script.Load("lua/TGNSCommon.lua")

TGNSConnectedTimesTracker = {}

local disconnectedSecondsDurationToOverlook = 300
local connectedTimes = {}
local pdr = TGNSPlayerDataRepository.Create("connectedtimes", function(data)
	data.when = data.when ~= nil and data.when or nil
	data.lastSeen = data.lastSeen ~= nil and data.lastSeen or nil
	return data
end)

function TGNSConnectedTimesTracker.SetClientConnected(client)
	local steamId = TGNS.GetClientSteamId(client)
	local data = pdr:Load(steamId)
	local tooLongHasPassedSinceLastSeen = data.lastSeen == nil or (Shared.GetSystemTime() - data.lastSeen > disconnectedSecondsDurationToOverlook)
	local noExistingConnectionTimeIsOnRecord = data.when == nil
	if tooLongHasPassedSinceLastSeen or noExistingConnectionTimeIsOnRecord then
		data.when = Shared.GetSystemTime()
		pdr:Save(data)
	end
	connectedTimes[steamId] = data.when
end

function TGNSConnectedTimesTracker.GetClientConnected(client)
	local steamId = TGNS.GetClientSteamId(client)
	local result = connectedTimes[steamId]
	if result == nil then
		local data = pdr:Load(steamId)
		result = data.when
	end
	result = result ~= nil and result or 0
	return result
end

function TGNSConnectedTimesTracker.SetClientLastSeen(client)
	local steamId = TGNS.GetClientSteamId(client)
	local data = pdr:Load(steamId)
	data.lastSeen = Shared.GetSystemTime()
	pdr:Save(data)
end

function TGNSConnectedTimesTracker.PrintConnectedTimes(client, clientList)
	table.sort(clientList, function(c1, c2)
		return TGNSConnectedTimesTracker.GetClientConnected(c1) < TGNSConnectedTimesTracker.GetClientConnected(c2)
	end)
	TGNS.DoFor(clientList, function(c)
		local connected = TGNSConnectedTimesTracker.GetClientConnected(c)
		TGNS.ConsolePrint(client, string.format("%s: %s", TGNS.GetClientName(c), TGNS.SecondsToClock(Shared.GetSystemTime() - connected)), "CONNECTEDTIMES")
	end)
end

local function StripConnectedTime(client)
	local steamId = TGNS.GetClientSteamId(client)
	connectedTimes[steamId] = 0
end
TGNS.RegisterEventHook("OnClientDisconnect", StripConnectedTime)
