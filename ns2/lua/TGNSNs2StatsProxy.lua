Script.Load("lua/TGNSCommon.lua")

local STEAMID_FETCH_URL_TEMPLATE = "http://ns2stats.org/api/players?players=%s"

TGNSNs2StatsProxy = {}

local function GetPlayerRecordFromDecodedFetchData(steamId)
	local result
	local matchingRecords = TGNS.Where(decodedFetchData, function(d) return d.id == steamId end)
	if #matchingRecords > 0 then
		result = TGNS.GetFirst(matchingRecords)
	end
	return result
end

TGNSNs2StatsProxy.Create = function(steamIds)
	local result = {}
	local decodedFetchData = {}

	if steamIds ~= nil and #steamIds > 0 then
		local commaDelimitedSteamIds = TGNS.Join(steamIds, ",")
		local fetchUrl = string.format(STEAMID_FETCH_URL_TEMPLATE, commaDelimitedSteamIds)
		local fetchResult = Shared.GetHTTPRequest(fetchUrl)
		if fetchResult ~= nil then
			local decodedFetchData = json.decode(fetchResult)
		end
	end
	
	result.GetPlayerRecord = function(steamId)
		local playerRecordProxy = {}
		local data
		local matchingRecords = decodedFetchData == nil and {} or TGNS.Where(decodedFetchData, function(d) return d.id == steamId end)
		playerRecordProxy.HasData = #matchingRecords > 0
		if playerRecordProxy.HasData then
			data = TGNS.GetFirst(matchingRecords)
			playerRecordProxy = {}
			
			playerRecordProxy.GetCumulativeScore = function()
				return data.score
			end
			
			playerRecordProxy.GetTimePlayedInSeconds = function()
				return data.time_played
			end
		end
		
		return playerRecordProxy
	end
	
	return result
end

