TGNSJsonEndpointTranscoder = {}

function TGNSJsonEndpointTranscoder.DecodeFromEndpoint(dataTypeName, recordId, callback)
	callback = callback or function() end
	local url = string.format("%s&d=%s&i=%s", TGNS.Config.DataEndpointBaseUrl, TGNS.UrlEncode(dataTypeName), TGNS.UrlEncode(recordId))
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
	local url = string.format("%s&d=%s&i=%s&v=%s", TGNS.Config.DataEndpointBaseUrl, TGNS.UrlEncode(dataTypeName), TGNS.UrlEncode(recordId), TGNS.UrlEncode(json.encode(data)))
	TGNS.GetHttpAsync(url, function(response)
		callback(json.decode(response) or {})
	end)
end