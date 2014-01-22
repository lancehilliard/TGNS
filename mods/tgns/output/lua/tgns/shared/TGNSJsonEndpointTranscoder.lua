TGNSJsonEndpointTranscoder = {}

function TGNSJsonEndpointTranscoder.EncodeToEndpoint(key, data, callback)
	callback = callback or function() end
	local url = string.format("%s&key=%s&value=%s", TGNS.Config.DataEndpointBaseUrl, TGNS.UrlEncode(key), TGNS.UrlEncode(json.encode(data)))
	TGNS.GetHttpAsync(url, function(response)
		callback(json.decode(response))
	end)
end