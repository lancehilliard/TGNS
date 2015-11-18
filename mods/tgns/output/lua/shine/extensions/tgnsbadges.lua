local badgeNames = {}
local badges = {}
local md = TGNSMessageDisplayer.Create("BADGES")
local badgesModIsLoaded = false
-- local targetClientBadgeLabels = {}

local Plugin = {}

local function tellTargetAboutSource(targetClient, sourceClient)
	local badgeName = badgeNames[sourceClient]
	local sourceClientSteamId = TGNS.GetClientSteamId(sourceClient)
	local sourceBadge = badges[sourceClientSteamId]
	if badgeName and sourceBadge and kBadges[badgeName] then
		SetFormalBadgeName(badgeName, string.format('%s (TGNS)\n%s\n\nWhich TGNS badges do you have?\nFind out: M > TGNS Portal > Badges\nOr: http://rr.tacticalgamer.com', sourceBadge.DisplayName, sourceBadge.Description))
		Server.SendNetworkMessage(targetClient, "Badge", { clientIndex = TGNS.GetClientId(sourceClient), badge = kBadges[badgeName] }, true)
		-- if targetClientBadgeLabels[targetClient] ~= nil and not TGNS.Has(targetClientBadgeLabels[targetClient], badgeName) then
		-- 	Server.SendNetworkMessage(targetClient, Shine.Plugins.scoreboard.BADGE_DISPLAY_LABEL, { n = badgeName, l = string.format('%s (TGNS)\n%s', sourceBadge.DisplayName, sourceBadge.Description) }, true)
		-- 	table.insert(targetClientBadgeLabels[targetClient], badgeName)
		-- end
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
						--TGNS.DebugPrint(string.format("Assigned %s badge to %s...", badgeName, TGNS.GetClientNameSteamIdCombo(client)))
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
				local player = TGNS.GetPlayer(client)
				md:ToPlayerNotifyInfo(player, string.format("Your most recent TGNS Badge: %s", mostRecentBadgeResponse.result.DisplayName))
				md:ToPlayerNotifyInfo(player, "To manage TGNS Badges: Press M > TGNS Portal (and then click 'Badges' at the top of the page)")
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
	end
end

function Plugin:ClientConfirmConnect(client)
	if badgesModIsLoaded then
		-- targetClientBadgeLabels[client] = {}
		TGNS.ScheduleAction(1, function()
			TGNS.DoFor(TGNS.GetClientList(), function(c) tellTargetAboutSource(client, c) end)
		end)
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