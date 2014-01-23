TGNSPlayerBlacklistRepository = {}

function TGNSPlayerBlacklistRepository.Create(blacklistTypeName)
	assert(blacklistTypeName ~= nil and blacklistTypeName ~= "")

	local dr = TGNSDataRepository.Create("blacklist", function(data)
        data.blacklists = data.blacklists or {}
        return data
    end)

	local result = {}
	result.blacklistTypeName = blacklistTypeName

	function result:IsClientBlacklisted(client, callback)
		callback = callback or function() end
		dr.Load(nil, function(loadResponse)
			if loadResponse.success then
				local blacklistData = loadResponse.value
				local blacklists = blacklistData.blacklists
				local steamId = TGNS.GetClientSteamId(client)
				local isBlacklisted = TGNS.Any(blacklists, function(b) return b.from == self.blacklistTypeName and b.id == steamId end)
				--Shared.Message("IsClientBlacklisted: " .. steamId .. " from " .. self.blacklistTypeName .. " = " .. tostring(isBlacklisted))
				callback(isBlacklisted)
			else
				Shared.Message("PlayerBlacklistRepository ERROR: Unable to access data.")
				callback(false)
			end
		end)
	end

	return result
end