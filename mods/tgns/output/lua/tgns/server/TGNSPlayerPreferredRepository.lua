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

	function result:IsClientPreferred(client)
		local isPreferred
		local steamId = TGNS.GetClientSteamId(client)
		if isPreferredCache[preferredTypeName][steamId] ~= nil then
			isPreferred = isPreferredCache[preferredTypeName][steamId]
		else
			local preferredData = dr.Load()
			local preferreds = preferredData.preferreds
			isPreferred = TGNS.Any(preferreds, function(p) return p.plugin == self.preferredTypeName and p.id == steamId end)
			Shared.Message("IsClientPreferred: " .. steamId .. " for " .. self.preferredTypeName .. " = " .. tostring(isPreferred))
			isPreferredCache[preferredTypeName][steamId] = isPreferred
		end
		return isPreferred
	end

	return result
end