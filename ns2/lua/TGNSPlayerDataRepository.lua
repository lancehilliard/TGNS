Script.Load("lua/TGNSDataRepository.lua")

TGNSPlayerDataRepository = {}

TGNSPlayerDataRepository.Create = function(dataTypeName, onDataLoaded)
	local dr = TGNSDataRepository.Create(dataTypeName, onDataLoaded, function(steamId) return steamId end)
	
	local result = {}
	
	result.Save = function(self, data)
		dr.Save(data, data.steamId)
	end

	result.Load = function(self, steamId)
		local data = dr.Load(steamId)
		data.steamId = data.steamId or steamId
		return data
	end
	
	return result
end