Script.Load("lua/TGNSCommon.lua")

local playerRecords = {}

local function processResponse(response)
	if response ~= nil then
		Shared.Message("Response:" .. response)
		local decodedResponse = json.decode(response)
		if decodedResponse then
			local steamId = decodedResponse.id
			if steamId then
				playerRecords[steamId] = decodedResponse
			end
		end
	end
end

TGNSNs2StatsProxy = {}
TGNSNs2StatsProxy.Create = function(steamIds)
	TGNS.DoFor(steamIds, function(steamId)
		local fetchUrl = string.format("http://ns2stats.org/api/player?ns2_id=%s", steamId)
		Shared.Message("Fetch: " .. fetchUrl)
		Shared.SendHTTPRequest(fetchUrl, "GET", processResponse)
	end)
	
	local result = {}
	result.GetPlayerRecord = function(steamId)
		local playerRecordProxy = {}
		local playerRecord = playerRecords[steamId]
		playerRecordProxy.HasData = playerRecord ~= nil
		if playerRecordProxy.HasData then
			playerRecordProxy = {}
			
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

