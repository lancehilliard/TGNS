local RECENT_DATA_THRESHOLD_IN_SECONDS = 20

TGNSServerInfoGetter = {}

local dr = TGNSDataRepository.Create("serverinfo", function(data)
	data.publicSlotsRemaining = data.publicSlotsRemaining or 0
	data.playingPlayersCount = data.playingPlayersCount or 0
	data.lastUpdatedInSeconds = data.lastUpdatedInSeconds or 0
	return data
end)

TGNSServerInfoGetter.GetInfoBySimpleServerName = function(simpleServerName, callback)
	callback = callback or function() end
	dr.Load(simpleServerName, function(loadResponse)
		local result = {}
		if loadResponse.success then
			local data = loadResponse.value
			local secondsSinceLastUpdate = TGNS.GetSecondsSinceEpoch() - data.lastUpdatedInSeconds
			result.HasRecentData = secondsSinceLastUpdate <= RECENT_DATA_THRESHOLD_IN_SECONDS
			if result.HasRecentData then
				result.GetPublicSlotsRemaining = function()
					return data.publicSlotsRemaining
				end
				result.GetPlayingPlayersCount = function()
					return data.playingPlayersCount
				end
				result.GetTimeElapsedSinceLastUpdate = function()
					local timeElapsedSinceLastUpdate = string.TimeToString(secondsSinceLastUpdate)
					return timeElapsedSinceLastUpdate
				end
			end
		else
			result.HasRecentData = false
		end
		callback(result)
	end)
end

-- local function PublicSlotsRemainingChanged(simpleServerName, publicSlotsRemaining, playingPlayersCount)
-- 	dr.Load(simpleServerName, function(loadResponse)
-- 		if loadResponse.success then
-- 			local data = loadResponse.value
-- 			data.publicSlotsRemaining = publicSlotsRemaining
-- 			data.lastUpdatedInSeconds = TGNS.GetSecondsSinceEpoch()
-- 			data.playingPlayersCount = playingPlayersCount
-- 			dr.Save(data, simpleServerName, function(saveResponse)
-- 				if not saveResponse.success then
-- 					TGNS.DebugPrint("ServerInfoGetter ERROR: unable to save data", true)
-- 				end
-- 			end)
-- 		else
-- 			TGNS.DebugPrint("ServerInfoGetter ERROR: unable to access data", true)
-- 		end
-- 	end)
-- end
-- TGNS.RegisterEventHook("PublicSlotsRemainingChanged", PublicSlotsRemainingChanged)
