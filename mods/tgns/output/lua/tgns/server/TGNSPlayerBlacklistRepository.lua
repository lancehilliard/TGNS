TGNSPlayerBlacklistRepository = {}

function TGNSPlayerBlacklistRepository.Create(blacklistTypeName)
	assert(blacklistTypeName ~= nil and blacklistTypeName ~= "")

	local dr = TGNSDataRepository.Create("blacklist", function(data)
        data.blacklists = data.blacklists or {}
        return data
    end)

	local result = {}
	result.blacklistTypeName = blacklistTypeName

	function result:IsClientBlacklisted(client)
		local blacklistData = dr.Load()
		local blacklists = blacklistData.blacklists
		local steamId = TGNS.GetClientSteamId(client)
		local isBlacklisted = TGNS.Any(blacklists, function(b) return b.from == self.blacklistTypeName and b.id == steamId end)
		Shared.Message("IsClientBlacklisted: " .. steamId .. " from " .. self.blacklistTypeName .. " = " .. tostring(isBlacklisted))
		return isBlacklisted
	end

	return result
end