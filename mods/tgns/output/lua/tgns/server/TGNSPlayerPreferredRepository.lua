local DATA_FILENAME = "config://PreferredPlayers.json"
local isPreferredCache = {}

TGNSPlayerPreferredRepository = {}

function TGNSPlayerPreferredRepository.Create(preferredTypeName)
	assert(preferredTypeName ~= nil and preferredTypeName ~= "")
	isPreferredCache[preferredTypeName] = {}
	local result = {}
	result.preferredTypeName = preferredTypeName

	function result:IsClientPreferred(client)
		local isPreferred
		local steamId = TGNS.GetClientSteamId(client)
		if isPreferredCache[preferredTypeName][steamId] ~= nil then
			isPreferred = isPreferredCache[preferredTypeName][steamId]
		else
			isPreferred = false
			local dataFile = io.open(DATA_FILENAME, "r")
			if dataFile then
				local preferreds = json.decode(dataFile:read("*all")) or { }
				dataFile:close()
				isPreferred = TGNS.Any(preferreds, function(p) return p.plugin == self.preferredTypeName and p.id == steamId end)
			end
			isPreferredCache[preferredTypeName][steamId] = isPreferred
		end
		return isPreferred
	end

	return result
end