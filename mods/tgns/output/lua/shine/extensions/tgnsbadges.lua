local badgeNames = {}
local badges = {}
local md = TGNSMessageDisplayer.Create("BADGES")
local badgesModIsLoaded = false

local Plugin = {}

local function tellTargetAboutSource(targetClient, sourceClient)
	local badgeName = badgeNames[sourceClient]
	if badgeName and kBadges[badgeName] then
		Server.SendNetworkMessage(targetClient, "Badge", { clientIndex = TGNS.GetClientId(sourceClient), badge = kBadges[badgeName] }, true)
	end
end

local function assignBadge(client)
	local steamId = TGNS.GetClientSteamId(client)
	local url = string.format("%s&i=%s", TGNS.Config.ScoreboardBadgesEndpointBaseUrl, steamId)
	TGNS.GetHttpAsync(url, function(scoreboardBadgesResponseJson)
		if Shine:IsValidClient(client) then
			local scoreboardBadgesResponse = json.decode(scoreboardBadgesResponseJson) or {}
			if scoreboardBadgesResponse.success then
				if #scoreboardBadgesResponse.result > 0 then
					local badge = TGNS.GetFirst(scoreboardBadgesResponse.result)
					local badgeName = string.format("tgns%s", badge.ID)
					if kBadges[badgeName] then
						badgeNames[client] = badgeName
						badges[steamId] = badge
						-- TGNS.DebugPrint(string.format("Assigned %s badge to %s...", badgeName, TGNS.GetClientNameSteamIdCombo(client)))
						TGNS.DoFor(TGNS.GetClientList(), function(c) tellTargetAboutSource(c, client) end)
					end
				end
			else
				TGNS.DebugPrint(string.format("tgnsbadges ERROR: Unable to access badge display data for NS2ID %s. msg: %s | response: %s | stacktrace: %s", steamId, scoreboardBadgesResponse.msg, scoreboardBadgesResponseJson, scoreboardBadgesResponse.stacktrace))
			end
		end
	end)
end

local function tellMostRecentBadge(client)
	local steamId = TGNS.GetClientSteamId(client)
	local url = string.format("%s&i=%s", TGNS.Config.MostRecentBadgeEndpointBaseUrl, steamId)
	TGNS.GetHttpAsync(url, function(mostRecentBadgeResponseJson)
		local mostRecentBadgeResponse = json.decode(mostRecentBadgeResponseJson) or {}
		if mostRecentBadgeResponse.success then
			if TGNS.HasNonEmptyValue(mostRecentBadgeResponse.result.DisplayName) and TGNS.HasNonEmptyValue(mostRecentBadgeResponse.result.ID) and kBadges[string.format("tgns%s",mostRecentBadgeResponse.result.ID)] and Shine:IsValidClient(client) then
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), string.format("Your most recent TGNS Badge: %s", mostRecentBadgeResponse.result.DisplayName))
			end
		else
			TGNS.DebugPrint(string.format("tgnsbadges ERROR: Unable to access mostrecent badge data for NS2ID %s. msg: %s | response: %s | stacktrace: %s", steamId, mostRecentBadgeResponse.msg, mostRecentBadgeResponseJson, mostRecentBadgeResponse.stacktrace))
		end
	end)
end

function Plugin:GetCurrentBadgeInfo(steamId)
	local result = badges[steamId]
	return result
end

function Plugin:ClientConnect(client)
	if badgesModIsLoaded then
		assignBadge(client)
		TGNS.DoFor(TGNS.GetClientList(), function(c) tellTargetAboutSource(client, c) end)
		-- TGNS.DoFor(TGNS.GetClientList(), function(c) tellTargetAboutSource(c, client) end)
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	if badgesModIsLoaded then
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 53, function()
			if Shine.Plugins.mapvote:VoteStarted() then
				TGNS.DoFor(TGNS.GetClientList(), tellMostRecentBadge)
			end
		end)
	end
end

function Plugin:Initialise()
    self.Enabled = true
    TGNS.ScheduleAction(2, function()
	    badgesModIsLoaded = GiveBadge and Shine.GetUpValue(GiveBadge, "sServerBadges") ~= nil
    end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("tgnsbadges", Plugin )