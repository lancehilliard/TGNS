// TGNS Player Blacklist Repository
Script.Load("lua/TGNSCommon.lua")

local DATA_FILENAME = "config://BlacklistedPlayers.json"

TGNSPlayerBlacklistRepository = {}

function TGNSPlayerBlacklistRepository.Create(blacklistTypeName)
	assert(blacklistTypeName ~= nil and blacklistTypeName ~= "")
	local result = {}
	result.blacklistTypeName = blacklistTypeName
	
	function result:IsClientBlacklisted(client)
		local steamId = TGNS.GetClientSteamId(client)
		local isBlacklisted = false
		local dataFile = io.open(DATA_FILENAME, "r")
		if dataFile then
			local blacklists = json.decode(dataFile:read("*all")) or { }
			dataFile:close()
			isBlacklisted = TGNS.Any(blacklists, function(b) return b.from == self.blacklistTypeName and b.id == steamId end)
		end
		return isBlacklisted
	end
	
	return result
end