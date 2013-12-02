TGNSDataRepository = {}

TGNSDataRepository.Create = function(dataTypeName, onDataLoaded, dataFilenameStubCreator)
	assert(dataTypeName ~= nil and dataTypeName ~= "")
	assert(type(onDataLoaded) == "function")

	local getDataFilename = function(recordId)
		local filenameStub = dataFilenameStubCreator and dataFilenameStubCreator(recordId) or dataTypeName
		local result = string.format("config://tgnsdata/%s/%s.json", dataTypeName, filenameStub)
		return result
	end

	local result = {}

	result.Save = function(data, recordId)
		local dataFilename = getDataFilename(recordId)
		local dataFile = io.open(dataFilename, "w+")
		if dataFile then
			dataFile:write(json.encode(data))
			dataFile:close()
		end
	end

	result.Load = function(recordId)
		local data = {}
		local dataFilename = getDataFilename(recordId)
		local dataFile = io.open(dataFilename, "r")
		if dataFile then
			data = json.decode(dataFile:read("*all")) or { }
			dataFile:close()
		end
		data = onDataLoaded(data)
		return data
	end

	return result
end