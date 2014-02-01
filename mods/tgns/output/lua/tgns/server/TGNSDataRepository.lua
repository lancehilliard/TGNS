TGNSDataRepository = {}

TGNSDataRepository.Create = function(dataTypeName, onDataLoaded)
	assert(dataTypeName ~= nil and dataTypeName ~= "")
	assert(type(onDataLoaded) == "function")

	local result = {}

	result.Save = function(data, recordId, callback)
		recordId = recordId or dataTypeName
		TGNSJsonEndpointTranscoder.EncodeToEndpoint(dataTypeName, recordId, data, callback)
	end

	result.Load = function(recordId, callback)
		callback = callback or function() end
		recordId = recordId or dataTypeName
		TGNSJsonEndpointTranscoder.DecodeFromEndpoint(dataTypeName, recordId, function(decodeResponse)
			decodeResponse.value = decodeResponse.success and decodeResponse.value or {}
			decodeResponse.value = onDataLoaded(decodeResponse.value)
			callback(decodeResponse)
		end)
	end

	return result
end