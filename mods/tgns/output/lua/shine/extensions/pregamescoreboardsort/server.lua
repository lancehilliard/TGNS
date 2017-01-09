Plugin.HasConfig = false
-- Plugin.ConfigName = "pregamescoreboardsort.json"

local md = TGNSMessageDisplayer.Create()
local teamWinRatesData = {}

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
    if TGNS.PlayerIsOnPlayingTeam(player) then
        local client = TGNS.GetClient(player)
        local joinerMarineWinRate = .5
        local joinerAlienWinRate = .5
        local joinerSteamId = TGNS.GetClientSteamId(client)
        local joinerTeamWinRates = teamWinRatesData[tostring(joinerSteamId)]
        if joinerTeamWinRates then
            joinerMarineWinRate = joinerTeamWinRates[tostring(kMarineTeamType)]
            joinerAlienWinRate = joinerTeamWinRates[tostring(kAlienTeamType)]
        end
        TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(otherClient)
            local otherMarineWinRate = .5
            local otherAlienWinRate = .5
            local otherSteamId = TGNS.GetClientSteamId(otherClient)
            local otherTeamWinRates = teamWinRatesData[tostring(otherSteamId)]
            if otherTeamWinRates then
                otherMarineWinRate = otherTeamWinRates[tostring(kMarineTeamType)]
                otherAlienWinRate = otherTeamWinRates[tostring(kAlienTeamType)]
            end
            TGNS.SendNetworkMessageToPlayer(player, self.WINRATE, {i=TGNS.GetPlayer(otherClient):GetClientIndex(), m=otherMarineWinRate, a=otherAlienWinRate})
            TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(otherClient), self.WINRATE, {i=player:GetClientIndex(), m=joinerMarineWinRate, a=joinerAlienWinRate})
        end)

    end
end

function Plugin:PlayerSay(client, networkMessage)
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

    TGNS.DoWithConfig(function()
        local url = TGNS.Config.TeamWinRatesEndpointBaseUrl
        TGNS.GetHttpAsync(url, function(teamWinRatesResponseJson)
            local teamWinRatesResponse = json.decode(teamWinRatesResponseJson) or {}
            if teamWinRatesResponse.success then
                teamWinRatesData = teamWinRatesResponse.result
                -- Shared.Message("teamWinRatesResponse.result['160301']: " .. tostring(teamWinRatesResponse.result['160301']))
                -- Shared.Message("teamWinRatesResponse.result['160301'][tostring(kMarineTeamType)]: " .. tostring(teamWinRatesResponse.result['160301'][tostring(kMarineTeamType)]))
                -- Shared.Message("teamWinRatesResponse.result['160301'][tostring(kAlienTeamType)]: " .. tostring(teamWinRatesResponse.result['160301'][tostring(kAlienTeamType)]))
            else
                TGNS.DebugPrint(string.format("pregamescoreboardsort ERROR: Unable to access teamWinRates data. url: %s | msg: %s | response: %s | stacktrace: %s", url, teamWinRatesResponse.msg, teamWinRatesResponseJson, teamWinRatesResponse.stacktrace))
            end
        end)
    end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end