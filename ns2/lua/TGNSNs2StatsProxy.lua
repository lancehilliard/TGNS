Script.Load("lua/TGNSCommon.lua")

local requestedRecordSteamIds = {}
local steamIdsWhichWeKnowHaveNoRecord = {}
local decodedResponses = {}
local PLAYER_NOT_FOUND_RESPONSE = "Player not found"

local function processResponse(steamId, response)
	if response ~= nil then
		if response == PLAYER_NOT_FOUND_RESPONSE then
			table.insert(steamIdsWhichWeKnowHaveNoRecord, steamId)
			//TGNS.SendAdminConsoles(string.format("NOT FOUND RESPONSE : %s", steamId), "NS2STATSPROXYDEBUG")
		else
			local decodedResponse = json.decode(response)
			if decodedResponse then
				decodedResponses[steamId] = TGNS.GetFirst(decodedResponse)
				//TGNS.SendAdminConsoles(string.format("PLAYER RECORD FOUND: %s", steamId), "NS2STATSPROXYDEBUG")
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
			//TGNS.SendAdminConsoles(string.format("REQUESTING RECORD  : %s", steamId), "NS2STATSPROXYDEBUG")
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
	result.HasData = result.HasData and decodedResponseForPlayer.score ~= nil // discard found records with "null" score
	result.HasData = result.HasData and decodedResponseForPlayer.time_played // discard found records without any playtime
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