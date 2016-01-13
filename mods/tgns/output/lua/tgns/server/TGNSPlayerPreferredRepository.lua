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
						--Shared.Message("IsClientPreferred: " .. steamId .. " for " .. self.preferredTypeName .. " = " .. tostring(isPreferred))
						isPreferredCache[preferredTypeName][steamId] = isPreferred
						callback(isPreferred)
					else
						Shared.Message("PlayerPreferredRepository ERROR: Unable to access data.")
						callback(false)
					end
				end)
			end
		end
	end

	return result
end

local function getPreferreds()
	if TGNS.Config and TGNS.Config.PreferredEndpointBaseUrl then
		local url = TGNS.Config.PreferredEndpointBaseUrl
		TGNS.GetHttpAsync(url, function(preferredResponseJson)
			-- Shared.Message("preferredResponseJson: " .. preferredResponseJson)
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
	else
		TGNS.ScheduleAction(0, getPreferreds)
	end
end

Event.Hook("MapPostLoad", getPreferreds)