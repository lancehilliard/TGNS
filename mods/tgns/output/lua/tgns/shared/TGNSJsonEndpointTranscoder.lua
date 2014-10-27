TGNSJsonEndpointTranscoder = {}

function TGNSJsonEndpointTranscoder.DecodeFromEndpoint(dataTypeName, recordId, callback)
	callback = callback or function() end
	local baseUrl = TGNS.Config.DataEndpointBaseUrl
	local encodedTypeName = TGNS.UrlEncode(dataTypeName)
	local encodedRecordId = TGNS.UrlEncode(recordId)
	local url = string.format("%s&d=%s&i=%s", baseUrl, encodedTypeName, encodedRecordId)
	TGNS.GetHttpAsync(url, function(response)
		local result = json.decode(response) or {}
		if result.success then
			result.value = result.value or {}
		end
		callback(result)
	end)
end

function TGNSJsonEndpointTranscoder.EncodeToEndpoint(dataTypeName, recordId, data, callback)
	callback = callback or function() end
	local baseUrl = TGNS.Config.DataEndpointBaseUrl
	local encodedTypeName = TGNS.UrlEncode(dataTypeName)
	local encodedRecordId = TGNS.UrlEncode(recordId)
	local encodedJsonData = TGNS.UrlEncode(json.encode(data))
	local url = string.format("%s&d=%s&i=%s&v=%s", baseUrl, encodedTypeName, encodedRecordId, encodedJsonData)
	TGNS.GetHttpAsync(url, function(response)
		callback(json.decode(response) or {})
	end)
end


