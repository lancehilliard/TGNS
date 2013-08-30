local requestedRecordSteamIds = {}
local steamIdsWhichWeKnowHaveNoRecord = {}
local decodedResponses = {}
local PLAYER_NOT_FOUND_RESPONSE = "Player not found"

local function processResponse(steamId, response)
	if response ~= nil then
		if response == PLAYER_NOT_FOUND_RESPONSE then
			table.insert(steamIdsWhichWeKnowHaveNoRecord, steamId)
		else
			local decodedResponse = json.decode(response)
			if decodedResponse then
				decodedResponses[steamId] = TGNS.GetFirst(decodedResponse)
			end
		end
	end
end

local function getRequestedRecords()
	TGNS.DoFor(requestedRecordSteamIds, function(steamId)
		local playerIsOnTheServer = TGNS.GetPlayerMatchingSteamId(steamId) ~= nil
		local ns2statsMightReturnRecordForThePlayer = not TGNS.Has(steamIdsWhichWeKnowHaveNoRecord, steamId)
		local weHaveYetToFetchPlayerRecordSuccessfully = not decodedResponses[steamId]
		if playerIsOnTheServer and ns2statsMightReturnRecordForThePlayer and weHaveYetToFetchPlayerRecordSuccessfully then
			local fetchUrl = string.format("http://ns2stats.org/api/player?ns2_id=%s", steamId)
			TGNS.GetHttpAsync(fetchUrl, function(response) processResponse(steamId, response) end)
		end
	end)
end
TGNS.ScheduleActionInterval(120, getRequestedRecords)

TGNSNs2StatsProxy = {}
TGNSNs2StatsProxy.AddSteamId = function(steamId)
	TGNS.InsertDistinctly(requestedRecordSteamIds, steamId)
	getRequestedRecords()
end

TGNSNs2StatsProxy.GetPlayerRecord = function(steamId)
	local result = {}
	local decodedResponseForPlayer = decodedResponses[steamId]
	result.HasData = decodedResponseForPlayer ~= nil
	result.HasData = result.HasData and TGNS.IsNumberWithNonZeroPositiveValue(decodedResponseForPlayer.score) // discard found records lacking score
	result.HasData = result.HasData and TGNS.IsNumberWithNonZeroPositiveValue(decodedResponseForPlayer.time_played) // discard found records lacking playtime
	if result.HasData then
		result.GetCumulativeScore = function()
			return decodedResponseForPlayer.score
		end
		
		result.GetTimePlayedInSeconds = function()
			return decodedResponseForPlayer.time_played
		end
	end
	return result
end