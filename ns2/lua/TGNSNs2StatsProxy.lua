Script.Load("lua/TGNSCommon.lua")

local playerRecords = {}

local function processResponse(steamId, response)
	if response ~= nil then
		local decodedResponse = json.decode(response)
		if decodedResponse then
			playerRecords[steamId] = TGNS.GetFirst(decodedResponse)
			TGNS.SendAdminConsoles(message, "NS2STATSPROXY_DEBUG")
		end
	end
end

TGNSNs2StatsProxy = {}
TGNSNs2StatsProxy.Create = function(steamIds)
	TGNS.DoFor(steamIds, function(steamId)
		local fetchUrl = string.format("http://ns2stats.org/api/player?ns2_id=%s", steamId)
		Shared.SendHTTPRequest(fetchUrl, "GET", function(response) processResponse(steamId, response) end)
	end)
	
	local result = {}
	result.GetPlayerRecord = function(steamId)
		local playerRecordProxy = {}
		local playerRecord = playerRecords[steamId]
		playerRecordProxy.HasData = playerRecord ~= nil
		if playerRecordProxy.HasData then
			playerRecordProxy.GetCumulativeScore = function()
				return playerRecord.score
			end
			
			playerRecordProxy.GetTimePlayedInSeconds = function()
				return playerRecord.time_played
			end
		end
		
		return playerRecordProxy
	end
	
	return result
end