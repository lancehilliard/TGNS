local isPreferredCache = {}

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
		local isPreferred
		local steamId = TGNS.GetClientSteamId(client)
		if isPreferredCache[preferredTypeName][steamId] ~= nil then
			isPreferred = isPreferredCache[preferredTypeName][steamId]
		else
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

	return result
end