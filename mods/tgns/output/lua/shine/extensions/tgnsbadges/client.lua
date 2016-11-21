local Plugin = Plugin

local stockBadgeDescriptions = {}
stockBadgeDescriptions["constellation"] = string.format("Constellation\n\nDonated to UWE during the production\nof the original Natural Selection mod.")
stockBadgeDescriptions["dev"] = string.format("Developer\n\nUWE Developer")
stockBadgeDescriptions["dev_retired"] = string.format("Retired Developer\n\nRetired UWE Developer")
stockBadgeDescriptions["maptester"] = string.format("Maptester\n\nContributes to UWE's official NS2\nmap testing efforts.")
stockBadgeDescriptions["playtester"] = string.format("Playtester\n\nContributes to UWE's official NS2\nplaytesting efforts.")
stockBadgeDescriptions["ns1_playtester"] = string.format("NS1 Playtester\n\nPlaytested the original NS1.")
stockBadgeDescriptions["squad5_blue"] = string.format("Squad Five Blue\n\nIndividually recognized by UWE for\ncontribution(s) to NS2 and its community.")
stockBadgeDescriptions["squad5_silver"] = string.format("Squad Five Silver\n\nIndividually recognized by UWE for\ncontribution(s) to NS2 and its community.")
stockBadgeDescriptions["squad5_gold"] = string.format("Squad Five Gold\n\nIndividually recognized by UWE for\ncontribution(s) to NS2 and its community.")
stockBadgeDescriptions["commander"] = string.format("Commander\n\nCommanded games for at least 10 losing\nhours or 5 winning hours.")
stockBadgeDescriptions["community_dev"] = string.format("Community Dev Team\n\nVolunteers to augment UWE's official\ndevelopment of NS2.")
stockBadgeDescriptions["reinforced1"] = string.format("Reinforced - Supporter\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["reinforced2"] = string.format("Reinforced - Silver\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["reinforced3"] = string.format("Reinforced - Gold\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["reinforced4"] = string.format("Reinforced - Diamond\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["reinforced5"] = string.format("Reinforced - Shadow\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["reinforced6"] = string.format("Reinforced - Onos\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["reinforced7"] = string.format("Reinforced - Insider\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["reinforced8"] = string.format("Reinforced - Game Director\n\nDonated to the development of NS2\nvia the Reinforced program.")
stockBadgeDescriptions["wc2013_supporter"] = string.format("World Championship - Supporter\n\nDonated to the 2013 World Championship.")
stockBadgeDescriptions["wc2013_silver"] = string.format("World Championship - Silver\n\nDonated to the 2013 World Championship.")
stockBadgeDescriptions["wc2013_gold"] = string.format("World Championship - Gold\n\nDonated to the 2013 World Championship.")
stockBadgeDescriptions["wc2013_shadow"] = string.format("World Championship - Shadow\n\nDonated to the 2013 World Championship.")
stockBadgeDescriptions["pax2012"] = string.format("PAX East 2012\n\nMet the UWE team at PAX.")

local badgeNames = {}
local badgeDescriptions = {}

TGNS.HookNetworkMessage(Plugin.CLIENTBADGE, function(message)
	badgeNames[message.i] = message.n
end)

TGNS.HookNetworkMessage(Plugin.BADGEDESCRIPTION, function(message)
	badgeDescriptions[message.n] = message.d
	TGNS.InsertDistinctly(gBadges, message.n)
end)

function Plugin:Initialise()
	self.Enabled = true

	local originalBadges_GetBadgeData = Badges_GetBadgeData
	Badges_GetBadgeData = function(badgeId)
		local result = originalBadges_GetBadgeData(badgeId)
		if not result and badgeDescriptions[badgeId] then
			local texturePath = string.format("ui/badges/%s.dds", badgeId)
			result = {
                name = badgeId,
                unitStatusTexture = texturePath,
                scoreboardTexture = texturePath,
                row = 1
            }
		end
		return result
	end

	local originalBadges_GetBadgeTextures = Badges_GetBadgeTextures
	Badges_GetBadgeTextures = function(clientId, useCase)
		local clientTextures, clientBadgeNames = originalBadges_GetBadgeTextures(clientId, useCase)
		if useCase == "scoreboard" then
			local badgeName = badgeNames[clientId]
			if badgeName then
				local texturePath = string.format("ui/badges/%s.dds", badgeName)
				TGNS.InsertDistinctly(clientTextures, texturePath)
				TGNS.InsertDistinctly(clientBadgeNames, badgeName)
			end
		end
		return clientTextures, clientBadgeNames
	end
	local originalGetBadgeFormalName = GetBadgeFormalName
	GetBadgeFormalName = function(name)
		local result = stockBadgeDescriptions[TGNS.ToLower(name)] or stockBadgeDescriptions[TGNS.Replace(TGNS.ToLower(string.format("badge_%s", name)), "badge_", "")]
		if result then
			result = string.format("%s\n\nhttp://wiki.unknownworlds.com/ns2/Badges", result)
		else
			result = badgeDescriptions[tostring(name)] or originalGetBadgeFormalName(name)
		end
		return result
	end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end