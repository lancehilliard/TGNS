Script.Load("lua/TGNSDataRepository.lua")

TGNSPlayerDataRepository = {}

TGNSPlayerDataRepository.Create = function(dataTypeName, onDataLoaded)
	local result = TGNSDataRepository.Create(dataTypeName, onDataLoaded, function(steamId) return steamId end)
	
	result.Save = function(data)
		result.Save(data, data.steamId)
	end

	result.Load = function(self, steamId)
		local data = result.Load(steamId)
		data.steamId = data.steamId or steamId
		return data
	end
	
	return result
end