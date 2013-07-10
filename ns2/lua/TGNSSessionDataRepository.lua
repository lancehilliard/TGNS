Script.Load("lua/TGNSDataRepository.lua")
Script.Load("lua/TGNSConnectedTimesTracker.lua")

local sessions = {}

local getSteamIdConnectedTimeInSeconds(steamId)
	local player = TGNS.GetPlayerMatchingSteamId(steamId)
	local client = TGNS.GetClient(player)
	local result = TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
	return result
end

local sessionBoundOnDataLoaded = function(data, onDataLoaded)
	if data.sessionId == nil or data.steamId == nil or data.sessionId ~= getSteamIdConnectedTimeInSeconds(data.steamId) then
		data = {}
	end
	return onDataLoaded(data)
end

TGNSSessionDataRepository = {}

TGNSSessionDataRepository.Create = function(dataTypeName, onDataLoaded)
	local dr = TGNSDataRepository.Create(dataTypeName, function(data) sessionBoundOnDataLoaded(data, onDataLoaded) end, function(recordId) return string.format("%s-session", recordId) end)
	
	local result = {}
	
	result.Save = function(self, data)
		dr.Save(data, data.steamId)
		sessions[data.steamId] = data
	end

	result.Load = function(self, steamId)
		local data = sessions[steamId] or dr.Load(steamId)
		data.steamId = data.steamId or steamId
		data.sessionId = data.sessionId or getSteamIdConnectedTimeInSeconds(steamId)
		return data
	end
	
	return result
end