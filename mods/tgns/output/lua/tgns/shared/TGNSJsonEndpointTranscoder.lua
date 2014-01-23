TGNSJsonEndpointTranscoder = {}

function TGNSJsonEndpointTranscoder.DecodeFromEndpoint(dataTypeName, recordId, callback)
	callback = callback or function() end
	local url = string.format("%s&d=%s&i=%s", TGNS.Config.DataEndpointBaseUrl, TGNS.UrlEncode(dataTypeName), TGNS.UrlEncode(recordId))
	TGNS.GetHttpAsync(url, function(response)
		-- Shared.Message("dataTypeName: " .. dataTypeName)
		-- Shared.Message("recordId: " .. recordId)
		-- Shared.Message("response: " .. response)
		local result = json.decode(response) or {}
		-- Shared.Message("success: " .. tostring(result.success))
		if result.success then
			-- Shared.Message("SUCCESS!")
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