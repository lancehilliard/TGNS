Script.Load("lua/TGNSDataRepository.lua")
Script.Load("lua/TGNSCommon.lua")

local RECENT_DATA_THRESHOLD_IN_SECONDS = 20

TGNSServerInfoGetter = {}

local dr = TGNSDataRepository.Create("serverinfo", function(data)
	data.publicSlotsRemaining = data.publicSlotsRemaining or 0
	data.lastUpdatedInSeconds = data.lastUpdatedInSeconds or 0
	return data
end, function(serverName) return serverName end)

TGNSServerInfoGetter.GetInfoBySimpleServerName = function(simpleServerName)
	local data = dr.Load(simpleServerName)
	local result = {}
	result.HasRecentData = TGNS.GetSecondsSinceEpoch() - data.lastUpdatedInSeconds <= RECENT_DATA_THRESHOLD_IN_SECONDS
	if result.HasRecentData then
		result.GetPublicSlotsRemaining = function()
			return data.publicSlotsRemaining
		end
	end
	return result
end

local function PublicSlotsRemainingChanged(simpleServerName, publicSlotsRemaining)
	local data = dr.Load(simpleServerName)
	data.publicSlotsRemaining = publicSlotsRemaining
	data.lastUpdatedInSeconds = TGNS.GetSecondsSinceEpoch()
	dr.Save(data, simpleServerName)
end
TGNS.RegisterEventHook("PublicSlotsRemainingChanged", PublicSlotsRemainingChanged)
