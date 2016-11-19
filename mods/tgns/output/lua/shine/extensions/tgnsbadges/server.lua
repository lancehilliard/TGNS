local md = TGNSMessageDisplayer.Create("BADGES")
local badgeNames = {}
local badgeDescriptions = {}

Plugin.HasConfig = false
-- Plugin.ConfigName = "tgnsbadges.json"

local function tellTargetAboutSource(targetClient, sourceClient)
	local badgeName = badgeNames[TGNS.GetClientSteamId(sourceClient)]
	if badgeName then
		TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(targetClient), Shine.Plugins.tgnsbadges.CLIENTBADGE, {i=TGNS.GetClientIndex(sourceClient), n=badgeName}) 
	end
end

local function tellMostRecentBadge(client)
	local steamId = TGNS.GetClientSteamId(client)
	local url = string.format("%s&i=%s", TGNS.Config.MostRecentBadgeEndpointBaseUrl, steamId)
	TGNS.GetHttpAsync(url, function(mostRecentBadgeResponseJson)
		local mostRecentBadgeResponse = json.decode(mostRecentBadgeResponseJson) or {}
		if mostRecentBadgeResponse.success then
			if TGNS.HasNonEmptyValue(mostRecentBadgeResponse.result.DisplayName) and TGNS.HasNonEmptyValue(mostRecentBadgeResponse.result.ID) and Shine:IsValidClient(client) then
				local player = TGNS.GetPlayer(client)
				md:ToPlayerNotifyInfo(player, string.format("Your most recent TGNS Badge: %s", mostRecentBadgeResponse.result.DisplayName))
				md:ToPlayerNotifyInfo(player, "To manage TGNS Badges: Press M > TGNS Portal (and then click 'Badges' at the top of the page)")
			end
		else
			TGNS.DebugPrint(string.format("tgnsbadges ERROR: Unable to access mostrecent badge data for NS2ID %s. msg: %s | response: %s | stacktrace: %s", steamId, mostRecentBadgeResponse.msg, mostRecentBadgeResponseJson, mostRecentBadgeResponse.stacktrace))
		end
	end)
end

function Plugin:ClientConnect(client)
	local steamId = TGNS.GetClientSteamId(client)
	TGNS.DoForPairs(badgeDescriptions, function(badgeName, badgeDescription)
		TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), self.BADGEDESCRIPTION, {n=badgeName, d=badgeDescription}) 
	end)
	if badgeNames[steamId] then
		TGNS.DoFor(TGNS.GetClientList(), function(c) tellTargetAboutSource(c, client) end)
		TGNS.DoFor(TGNS.GetClientList(), function(c) tellTargetAboutSource(client, c) end)
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 53, function()
		if Shine.Plugins.mapvote:VoteStarted() then
			TGNS.DoFor(TGNS.GetClientList(), tellMostRecentBadge)
		end
	end)
end

function Plugin:Initialise()
    self.Enabled = true

    TGNS.DoWithConfig(function()
		local url = TGNS.Config.ScoreboardBadgesEndpointBaseUrl
		TGNS.GetHttpAsync(url, function(scoreboardBadgesResponseJson)
			local scoreboardBadgesResponse = json.decode(scoreboardBadgesResponseJson) or {}
			if scoreboardBadgesResponse.success then
				TGNS.DoForPairs(scoreboardBadgesResponse.result, function(steamId, badges)
					local badge = TGNS.GetFirst(badges)
					local badgeName = string.format("tgns%s", badge.ID)
					badgeNames[tonumber(steamId)] = badgeName
					badgeDescriptions[badgeName] = string.format('%s (TGNS)\n%s\n\nWhich TGNS badges do you have?\nFind out: http://rr.tacticalgamer.com\nOr: M > TGNS Portal > Badges\nOr: Click your scoreboard row', badge.DisplayName, badge.Description)
				end)
			else
				TGNS.DebugPrint(string.format("tgnsbadges ERROR: Unable to access badge display data. url: %s | msg: %s | response: %s | stacktrace: %s", url, scoreboardBadgesResponse.msg, scoreboardBadgesResponseJson, scoreboardBadgesResponse.stacktrace))
			end
		end)
    end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end