local DATA_FILENAME = "config://PreferredPlayers.json"

TGNSPlayerPreferredRepository = {}

function TGNSPlayerPreferredRepository.Create(preferredTypeName)
	assert(preferredTypeName ~= nil and preferredTypeName ~= "")
	local result = {}
	result.preferredTypeName = preferredTypeName
	
	function result:IsClientPreferred(client)
		local steamId = TGNS.GetClientSteamId(client)
		local isPreferred = false
		local dataFile = io.open(DATA_FILENAME, "r")
		if dataFile then
			local preferreds = json.decode(dataFile:read("*all")) or { }
			dataFile:close()
			isPreferred = TGNS.Any(preferreds, function(p) return p.plugin == self.preferredTypeName and p.id == steamId end)
		end
		return isPreferred
	end
	
	return result
end