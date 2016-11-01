local isPreferredCache = {}
local preferredCacheWasPreloaded = false

TGNSPlayerPreferredRepository = {}

function TGNSPlayerPreferredRepository.Create(preferredTypeName)
	assert(preferredTypeName ~= nil and preferredTypeName ~= "")

	local dr = TGNSDataRepository.Create("preferred", function(data)
        data.preferreds = data.preferreds or {}
        return data
    end)

	isPreferredCache[preferredTypeName] = {}
	local result = {}
	result.preferredTypeName = preferredTypeName

	function result:IsClientPreferred(client, callback)
		callback = callback or function() end
		
		local steamId = TGNS.GetClientSteamId(client)
		if isPreferredCache[preferredTypeName][steamId] ~= nil then
			callback(isPreferredCache[preferredTypeName][steamId])
		else
			if preferredCacheWasPreloaded then
				callback(false)
			else
				local isPreferred
				dr.Load(nil, function(loadResponse)
					if loadResponse.success then
						local preferredData = loadResponse.value
						local preferreds = preferredData.preferreds
						isPreferred = TGNS.Any(preferreds, function(p) return p.plugin == self.preferredTypeName and p.id == steamId end)
						isPreferredCache[preferredTypeName][steamId] = isPreferred
						callback(isPreferred)
					else
						TGNS.DebugPrint("PlayerPreferredRepository ERROR: Unable to access data.", true)
						callback(false)
					end
				end)
			end
		end
	end

	return result
end

Event.Hook("MapPostLoad", function()
	TGNS.DoWithConfig(function()
		local url = TGNS.Config.PreferredEndpointBaseUrl
		TGNS.GetHttpAsync(url, function(preferredResponseJson)
			local preferredResponse = json.decode(preferredResponseJson) or {}
			if preferredResponse.success then
				TGNS.DoFor(preferredResponse.result, function(r)
					if r.PluginName ~= nil and r.PlayerId ~= nil then
						isPreferredCache[r.PluginName] = isPreferredCache[r.PluginName] or {}
						isPreferredCache[r.PluginName][r.PlayerId] = true
					end
				end)
				preferredCacheWasPreloaded = true
			else
				TGNS.DebugPrint(string.format("preferred ERROR: Unable to access preferred data. url: %s | msg: %s | response: %s | stacktrace: %s", url, preferredResponse.msg, preferredResponseJson, preferredResponse.stacktrace))
			end
		end)
	end)
end)