TGNSPlayerDataRepository = {}

TGNSPlayerDataRepository.Create = function(dataTypeName, onDataLoaded)
	local dr = TGNSDataRepository.Create(dataTypeName, onDataLoaded)

	local result = {}

	result.Save = function(self, data, callback)
		callback = callback or function() end
		dr.Save(data, data.steamId, callback)
	end

	result.Load = function(self, steamId, callback)
		callback = callback or function() end
		dr.Load(steamId, function(loadResponse)
			loadResponse.value.steamId = loadResponse.value.steamId or steamId
			callback(loadResponse)
		end)
	end

	return result
end