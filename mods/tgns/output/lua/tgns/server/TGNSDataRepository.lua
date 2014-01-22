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
		TGNSJsonFileTranscoder.EncodeToFile(dataFilename, data)
	end

	result.Load = function(recordId)
		local dataFilename = getDataFilename(recordId)
		local data = TGNSJsonFileTranscoder.DecodeFromFile(dataFilename)
		data = onDataLoaded(data)
		return data
	end

	return result
end