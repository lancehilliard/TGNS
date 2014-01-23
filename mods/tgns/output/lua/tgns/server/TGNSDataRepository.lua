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

	-- result.Save = function(data, recordId, callback)
	-- 	callback = callback or function() end
	-- 	local dataFilename = getDataFilename(recordId)
	-- 	TGNSJsonFileTranscoder.EncodeToFile(dataFilename, data)
	-- 	TGNSJsonEndpointTranscoder.EncodeToEndpoint(dataFilename, data)
	-- 	callback({success=true})
	-- end

	-- result.Load = function(recordId, callback)
	-- 	callback = callback or function() end
	-- 	local dataFilename = getDataFilename(recordId)
	-- 	local data = TGNSJsonFileTranscoder.DecodeFromFile(dataFilename)
	-- 	data = onDataLoaded(data) -- note mlh: when switching to endpoint, make sure onDataLoaded happens no matter what
	-- 	local result = {success=true,value=data}
	-- 	callback(result)
	-- end

	result.Save = function(data, recordId, callback)
		callback = callback or function() end
		local dataFilename = getDataFilename(recordId)
		TGNSJsonEndpointTranscoder.EncodeToEndpoint(dataFilename, data, callback)
	end

	result.Load = function(recordId, callback)
		callback = callback or function() end
		local dataFilename = getDataFilename(recordId)
		TGNSJsonEndpointTranscoder.DecodeFromEndpoint(dataFilename, function(decodeResponse)
			decodeResponse.value = decodeResponse.success and decodeResponse.value or {}
			decodeResponse.value = onDataLoaded(decodeResponse.value)
			callback(decodeResponse)
		end)
	end

	return result
end