Plugin.HasConfig = false
-- Plugin.ConfigName = "squadnumbers.json"

local md = TGNSMessageDisplayer.Create()
local squadNumbers = {}
local NUMBER_OF_GAMEPLAY_SECONDS_TO_SHOW_LIFEFORM_ICONS = 270

function Plugin:ClientConnect(client)
    local player = TGNS.GetPlayer(client)
    TGNS.SendNetworkMessageToPlayer(player, self.GAME_IN_PROGRESS, {b=TGNS.IsGameInProgress()})
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
    local client = TGNS.GetClient(player)
    if client then
        squadNumbers[client] = 0
        TGNS.SendNetworkMessageToPlayer(p, self.SQUAD_CONFIRMED, {c=TGNS.GetClientIndex(client),s=squadNumbers[client]})    
    end
end

function Plugin:EndGame(gamerules, winningTeam)
    TGNS.DoFor(TGNS.GetPlayerList(), function(p)
        TGNS.SendNetworkMessageToPlayer(p, self.GAME_IN_PROGRESS, {b=false})
    end)
    TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
        TGNS.DoFor(TGNS.GetPlayerList(), function(p)
            TGNS.DoFor(TGNS.GetClientList(), function(c)
                squadNumbers[c] = 0
                TGNS.SendNetworkMessageToPlayer(p, self.SQUAD_CONFIRMED, {c=TGNS.GetClientIndex(c),s=squadNumbers[c]})  
            end)
        end)
    end)
end

function Plugin:Initialise()
    self.Enabled = true

    TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
        TGNS.DoFor(TGNS.GetPlayerList(), function(p)
            TGNS.SendNetworkMessageToPlayer(p, self.GAME_IN_PROGRESS, {b=true})
        end)
        TGNS.ScheduleAction(NUMBER_OF_GAMEPLAY_SECONDS_TO_SHOW_LIFEFORM_ICONS, function()
            if TGNS.IsGameInProgress() and TGNS.GetCurrentGameDurationInSeconds() > NUMBER_OF_GAMEPLAY_SECONDS_TO_SHOW_LIFEFORM_ICONS - 2 then
                local playerList = TGNS.GetPlayerList()
                TGNS.DoFor(TGNS.GetAlienClients(playerList), function(c)
                    squadNumbers[c] = 0
                    TGNS.DoFor(TGNS.GetPlayerList(), function(p)
                        TGNS.SendNetworkMessageToPlayer(p, self.SQUAD_CONFIRMED, {c=TGNS.GetClientIndex(c),s=squadNumbers[c]})  
                    end)
                end)
            end
        end)
    end)

    TGNS.HookNetworkMessage(self.SQUAD_REQUESTED, function(client, message)
        local player = TGNS.GetPlayer(client)
        local targetClientIndex = message.c
        local squadNumberDelta = message.d
        local targetClient = TGNS.GetClientById(targetClientIndex)
        local md = TGNSMessageDisplayer.Create("SQUADS")
        if TGNS.IsGameInProgress() and TGNS.ClientIsAlien(targetClient) and TGNS.GetCurrentGameDurationInSeconds() > 30 then
            md:ToPlayerNotifyError(player, "Aliens may not alter planned lifeform scoreboard icons during gameplay.")
        else
            local clientIsCaptain = Shine.Plugins.captains and Shine.Plugins.captains.IsClientCaptain and Shine.Plugins.captains:IsClientCaptain(client)
            local clientIsCommander = TGNS.IsClientCommander(client)
            if (clientIsCaptain or clientIsCommander or (TGNS.ClientIsAlien(client) and client == targetClient)) then
                if targetClient and Shine:IsValidClient(targetClient) then
                    squadNumbers[targetClient] = squadNumbers[targetClient] or 0
                    squadNumbers[targetClient] = squadNumbers[targetClient] + squadNumberDelta
                    local highestSquadNumber = TGNS.ClientIsAlien(targetClient) and 6 or 9
                    if squadNumbers[targetClient] > highestSquadNumber then
                        squadNumbers[targetClient] = 0
                    elseif squadNumbers[targetClient] < 0 then
                        squadNumbers[targetClient] = highestSquadNumber
                    end
                    TGNS.DoFor(TGNS.GetPlayerList(), function(p)
                        TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.SQUAD_CONFIRMED, {c=targetClientIndex,s=squadNumbers[targetClient]})    
                        TGNS.SendNetworkMessageToPlayer(p, self.SQUAD_CONFIRMED, {c=targetClientIndex,s=squadNumbers[targetClient]})
                    end)
                else
                    md:ToPlayerNotifyError(player, "There was a problem setting a squad.")
                end
            else
                md:ToPlayerNotifyError(player, string.format("Captains and Commanders may set teammates' %s.", TGNS.ClientIsAlien(client) and "planned lifeforms" or "squads"))
            end
        end
        TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.scoreboard.SQUAD_ALLOWED, {})
    end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end