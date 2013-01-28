// TGNS Player Data Repository

TGNSPlayerDataRepository = {}

function TGNSPlayerDataRepository.Create(dataTypeName, onLoad)
	assert(dataTypeName ~= nil and dataTypeName ~= "")
	assert(type(onLoad) == "function")
	local result = {}
	result.dataTypeName = dataTypeName
	result.onLoad = onLoad
	
	local function GetDataFilename(tgnsPlayerDataRepository, steamId)
		assert(steamId ~= nil and steamId ~= "")
		local dataFilename = string.format("config://%s/%s.json", tgnsPlayerDataRepository.dataTypeName, steamId)
		return dataFilename
	end
	
	function result:Save(data)
		local dataFilename = GetDataFilename(self, data.steamId)
		local dataFile = io.open(dataFilename, "w+")
		if dataFile then
			dataFile:write(json.encode(data))
			dataFile:close()
		end
	end
	
	function result:Load(steamId)
		local data = {}
		local dataFilename = GetDataFilename(self, steamId)
		local dataFile = io.open(dataFilename, "r")
		if dataFile then
			data = json.decode(dataFile:read("*all")) or { }
			dataFile:close()
		end
		if data.steamId == nil then
			data.steamId = steamId
		end
		data = self.onLoad(data)
		return data
	end
	
	return result
end