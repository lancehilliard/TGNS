local RECENT_DATA_THRESHOLD_IN_SECONDS = 20

TGNSServerInfoGetter = {}

local dr = TGNSDataRepository.Create("serverinfo", function(data)
	data.publicSlotsRemaining = data.publicSlotsRemaining or 0
	data.lastUpdatedInSeconds = data.lastUpdatedInSeconds or 0
	return data
end, function(serverName) return serverName end)

TGNSServerInfoGetter.GetInfoBySimpleServerName = function(simpleServerName, callback)
	callback = callback or function() end
	dr.Load(simpleServerName, function(loadResponse)
		local result = {}
		if loadResponse.success then
			local data = loadResponse.value
			result.HasRecentData = TGNS.GetSecondsSinceEpoch() - data.lastUpdatedInSeconds <= RECENT_DATA_THRESHOLD_IN_SECONDS
		else
			result.HasRecentData = false
		end
		if result.HasRecentData then
			result.GetPublicSlotsRemaining = function()
				return data.publicSlotsRemaining
			end
		end
		callback(result)
	end)
end

local function PublicSlotsRemainingChanged(simpleServerName, publicSlotsRemaining)
	dr.Load(simpleServerName, function(loadResponse)
		if loadResponse.success then
			local data = loadResponse.value
			data.publicSlotsRemaining = publicSlotsRemaining
			data.lastUpdatedInSeconds = TGNS.GetSecondsSinceEpoch()
			dr.Save(data, simpleServerName, function(saveResponse)
				if not saveResponse.success then
					Shared.Message("ServerInfoGetter ERROR: unable to save data")
				end
			end)
		else
			Shared.Message("ServerInfoGetter ERROR: unable to access data")
		end
	end)
end
TGNS.RegisterEventHook("PublicSlotsRemainingChanged", PublicSlotsRemainingChanged)
