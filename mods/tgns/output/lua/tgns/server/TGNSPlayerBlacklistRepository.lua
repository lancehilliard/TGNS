TGNSPlayerBlacklistRepository = {}

local pbrCache = {}
local pbrCacheWasPreloaded = false

function TGNSPlayerBlacklistRepository.Create(blacklistTypeName)
	assert(blacklistTypeName ~= nil and blacklistTypeName ~= "")

	local dr = TGNSDataRepository.Create("blacklist", function(data)
        data.blacklists = data.blacklists or {}
        return data
    end)

	local result = {}
	result.blacklistTypeName = blacklistTypeName

	function result:IsClientBlacklisted(client, callback)
		callback = callback or function() end
		local steamId = TGNS.GetClientSteamId(client)
		pbrCache[blacklistTypeName] = pbrCache[blacklistTypeName] or {}
		if pbrCache[blacklistTypeName][steamId] == nil and not pbrCacheWasPreloaded then
			dr.Load(nil, function(loadResponse)
				if loadResponse.success then
					local blacklistData = loadResponse.value
					local blacklists = blacklistData.blacklists
					local isBlacklisted = TGNS.Any(blacklists, function(b) return b.from == self.blacklistTypeName and b.id == steamId end)
					pbrCache[blacklistTypeName][steamId] = isBlacklisted
					callback(isBlacklisted)
				else
					TGNS.DebugPrint("PlayerBlacklistRepository ERROR: Unable to access data.", true)
					callback(false)
				end
			end)
		else
			callback(pbrCache[blacklistTypeName][steamId])
		end
	end

	return result
end

local function getBlacklists()
	if TGNS.Config and TGNS.Config.BlacklistEndpointBaseUrl then
		local url = TGNS.Config.BlacklistEndpointBaseUrl
		TGNS.GetHttpAsync(url, function(blacklistResponseJson)
			local blacklistResponse = json.decode(blacklistResponseJson) or {}
			if blacklistResponse.success then
				TGNS.DoFor(blacklistResponse.result, function(r)
					if r.From ~= nil and r.PlayerId ~= nil then
						pbrCache[r.From] = pbrCache[r.From] or {}
						pbrCache[r.From][r.PlayerId] = true
					end
				end)
				pbrCacheWasPreloaded = true
			else
				TGNS.DebugPrint(string.format("blacklist ERROR: Unable to access blacklist data. url: %s | msg: %s | response: %s | stacktrace: %s", url, blacklistResponse.msg, blacklistResponseJson, blacklistResponse.stacktrace))
			end
		end)
	else
		TGNS.ScheduleAction(0, getBlacklists)
	end
end

Event.Hook("MapPostLoad", getBlacklists)
