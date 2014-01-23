TGNSJsonEndpointTranscoder = {}

function TGNSJsonEndpointTranscoder.DecodeFromEndpoint(key, callback)
	callback = callback or function() end
	local url = string.format("%s&key=%s", TGNS.Config.DataEndpointBaseUrl, TGNS.UrlEncode(key))
	TGNS.GetHttpAsync(url, function(response)
		-- Shared.Message("key: " .. key)
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

function TGNSJsonEndpointTranscoder.EncodeToEndpoint(key, data, callback)
	callback = callback or function() end
	local url = string.format("%s&key=%s&value=%s", TGNS.Config.DataEndpointBaseUrl, TGNS.UrlEncode(key), TGNS.UrlEncode(json.encode(data)))
	TGNS.GetHttpAsync(url, function(response)
		callback(json.decode(response) or {})
	end)
end