local actionslog = { }
local clientsWhoAreConnectedEnoughToBeConsideredBumpable = {}
local MESSAGE_PREFIX = "SLOTS"
table.insert(actionslog, "COMMUNITY SLOTS DEBUG: ")
local victimBumpCounts = {}
local rejectBumpCounts = {}
local commandStructureLastOccupancies = {}
local lastSetReservedSlotAmount
local inReadyRoomSinceTimes = {}

local COMMANDER_PROTECTION_DURATION_IN_SECONDS = 60

local otherServerStaticInfo = {}
otherServerStaticInfo["Taunt"] = { address = "tgns2.tacticalgamer.com", simpleName = "Chuckle" }
otherServerStaticInfo["Chuckle"] = { address = "tgns.tacticalgamer.com", simpleName = "Taunt" }

local tgnsMd = TGNSMessageDisplayer.Create("TGNS")

local function IsClientAmongLongestConnected(clients, client, limit)
    TGNS.SortAscending(clients, TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds)
    local result = TGNS.ElementIsFoundBeforeIndex(clients, client, limit)
    return result
end

local function IsTargetProtectedStranger(targetClient, playerList)
    local result = IsClientAmongLongestConnected(TGNS.GetStrangersClients(playerList), targetClient, Shine.Plugins.communityslots.Config.MinimumStrangers)
    if result then
        tgnsMd:ToAdminConsole(string.format("%s is protected Stranger.", TGNS.GetClientName(targetClient)))
    end
    return result
end

local function IsTargetProtectedPrimerOnly(targetClient, playerList)
    local result = IsClientAmongLongestConnected(TGNS.GetPrimerOnlyClients(playerList), targetClient, Shine.Plugins.communityslots.Config.MinimumPrimerOnlys)
    if result then
        tgnsMd:ToAdminConsole(string.format("%s is protected PrimerOnly.", TGNS.GetClientName(targetClient)))
    end
    return result
end

local function IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList)
    local result = TGNS.IsPrimerOnlyClient(targetClient) and #TGNS.GetStrangersClients(playerList) > Shine.Plugins.communityslots.Config.MinimumStrangers
    return result
end

local function TargetAndJoiningArePrimerOnly(targetClient, joiningSteamId)
    local result = TGNS.IsPrimerOnlyClient(targetClient) and TGNS.IsSteamIdPrimerOnly(joiningSteamId)
    return result
end

local function GetRemainingPublicSlots(playingPlayers)
    local totalPublicSlots = Shine.Plugins.communityslots.Config.MaximumSlots - Shine.Plugins.communityslots.Config.CommunitySlots
    local result = totalPublicSlots - #playingPlayers
    result = result > 0 and result or 0
    return result
end

local function ServerIsFull(playerList)
    local result = GetRemainingPublicSlots(playerList) == 0
    return result
end

local function Log(message)
    table.insert(actionslog, message)
    TGNS.EnhancedLog(message)
end

local function IsTargetProtectedCommander(targetClient)
    local result = false
    local timeAtWhichTargetClientWasLastACommander = commandStructureLastOccupancies[targetClient]
    if timeAtWhichTargetClientWasLastACommander ~= nil then
        if Shared.GetTime() - timeAtWhichTargetClientWasLastACommander <= COMMANDER_PROTECTION_DURATION_IN_SECONDS then
            result = true
        end
    end
    return result
end

local function FindVictimClient(joiningSteamId, playerList)
    local result = nil
    local bumpableClients = TGNS.GetMatchingClients(playerList, function(c,p) return Shine.Plugins.communityslots:IsTargetBumpable(c, playerList, joiningSteamId) end)
    if #bumpableClients > 0 then
        TGNS.SortAscending(bumpableClients, TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds)
        result = TGNS.GetFirst(bumpableClients)
    end
    return result
end

local function GetKickDetails(targetClient, joiningClient, playerList)
    local result = {}
    result.targetIsSM = TGNS.IsClientSM(targetClient) and "Y" or "N"
    result.targetHasSignedPrimer = TGNS.HasClientSignedPrimer(targetClient) and "Y" or "N"
    result.joinerIsSM = TGNS.IsClientSM(joiningClient) and "Y" or "N"
    result.joinerHasSignedPrimer = TGNS.IsClientSM(joiningClient) and "Y" or "N"
    result.strangerCount = #TGNS.GetStrangersClients(playerList)
    result.primerOnlyCount = #TGNS.GetPrimerOnlyClients(playerList)
    result.smCount = #TGNS.GetSmClients(playerList)
    result.shortReport = string.format("T: %s%s J:%s%s ?:%s P:%s S:%s Total:%s", result.targetIsSM, result.targetHasSignedPrimer, result.joinerIsSM, result.joinerHasSignedPrimer, result.strangerCount, result.primerOnlyCount, result.smCount, #playerList)
    return result
end

local function IncrementBumpCount(targetClient, bumpCounts)
    if TGNS.HasClientSignedPrimer(targetClient) then
        bumpCounts.primerOnly = TGNS.GetNumericValueOrZero(bumpCounts.primerOnly) + 1
    elseif TGNS.IsClientStranger(targetClient) then
        bumpCounts.stranger = TGNS.GetNumericValueOrZero(bumpCounts.stranger) + 1
    end
end

local function AnnounceClientBumpToStrangers(targetClient)
    local playerName = TGNS.GetClientName(targetClient)
    local strangerClients = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return TGNS.IsClientStranger(c) end)
    local strangerPlayers = TGNS.GetPlayers(strangerClients)
    TGNS.DoFor(strangerPlayers, function(p) tgnsMd:ToPlayerNotifyInfo(p, Shine.Plugins.communityslots:GetBumpMessage(targetClient)) end)
end

local function AnnounceOtherServerOptionsToBumpedClient(client)
    local otherServerStaticInfo = otherServerStaticInfo[TGNS.GetSimpleServerName()]
    if otherServerStaticInfo then
        local otherServerDynamicInfo = TGNSServerInfoGetter.GetInfoBySimpleServerName(otherServerStaticInfo.simpleName)
        if otherServerDynamicInfo.HasRecentData then
            local otherServerRemainingPublicSlots = otherServerDynamicInfo.GetPublicSlotsRemaining()
            if otherServerRemainingPublicSlots >= 4 then
                local message = string.format("~%s slots open on %s! Console: connect %s", otherServerRemainingPublicSlots, otherServerStaticInfo.simpleName, otherServerStaticInfo.address)
                tgnsMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), message)
                tgnsMd:ToClientConsole(client, message)
                tgnsMd:ToAdminConsole(message)
            end
        end
    end
end

local function onPreVictimKick(targetClient, targetPlayer, joiningClient, playerList)
    Log(string.format("%s: Victim: %s Joining: %s", GetKickDetails(targetClient, joiningClient, playerList).shortReport, TGNS.GetClientNameSteamIdCombo(targetClient), TGNS.GetClientNameSteamIdCombo(joiningClient)))
    IncrementBumpCount(targetClient, victimBumpCounts)
end

local function onPreJoinerKick(targetClient, targetPlayer, playerList)
    Log(string.format("%s: Reject: %s", GetKickDetails(targetClient, targetClient, playerList).shortReport, TGNS.GetClientNameSteamIdCombo(targetClient)))
    IncrementBumpCount(targetClient, rejectBumpCounts)
end

local function GetPlayingPlayers(clientToExclude)
    local allPlayingPlayers = TGNS.Where(TGNS.GetPlayerList(), function(p)
        local playerIsOnPlayingTeam = TGNS.PlayerIsOnPlayingTeam(p)
        local clientIsVirtual = TGNS.ClientAction(p, TGNS.GetIsClientVirtual)
        return playerIsOnPlayingTeam and not clientIsVirtual
    end)
    local result = {}
    TGNS.DoFor(allPlayingPlayers, function(p)
        local client = TGNS.GetClient(p)
        if client ~= clientToExclude and TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client) then
            table.insert(result, p)
        end
    end)
    return result
end

local function UpdateReservedSlotAmount()
    local reservedSlotCount = Shine.Plugins.communityslots.Config.CommunitySlots - #TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.IsPlayerSpectator(p) end)
    if lastSetReservedSlotAmount ~= reservedSlotCount then
        SetReservedSlotAmount(reservedSlotCount)
        lastSetReservedSlotAmount = reservedSlotCount
    end
end

local function AnnounceRemainingPublicSlots()
    local playingPlayers = GetPlayingPlayers()
    local remainingPublicSlots = GetRemainingPublicSlots(playingPlayers)
    TGNS.ExecuteEventHooks("PublicSlotsRemainingChanged", TGNS.GetSimpleServerName(), remainingPublicSlots)
    UpdateReservedSlotAmount()
end

local function GetBumpSummary(playerList, bumpedClient, joinerOrVictim)
    local supportingMembersCount = #TGNS.GetSmClients(playerList)
    local primerOnlysCount = #TGNS.GetPrimerOnlyClients(playerList)
    local strangersCount = #TGNS.GetStrangersClients(playerList)
    local clientName = TGNS.GetClientName(bumpedClient)
    local communityDesignationCharacter = TGNS.GetClientCommunityDesignationCharacter(bumpedClient)
    local bumpedClientConnectedTime = TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(bumpedClient)
    local bumpedClientConnectedDurationClock = "UNKNOWNTIME"
    if type(bumpedClientConnectedTime) == "number" then
        bumpedClientConnectedDuration = Shared.GetSystemTime() - bumpedClientConnectedTime
        bumpedClientConnectedDurationClock = TGNS.SecondsToClock(bumpedClientConnectedDuration)
    end
    local result = string.format("Kicking %s %s> %s after %s with S:%s P:%s ?:%s", joinerOrVictim, communityDesignationCharacter, clientName, bumpedClientConnectedDurationClock, supportingMembersCount, primerOnlysCount, strangersCount)
    return result
end

local function IsClientBumped(joiningClient)
    local result = false
    local victimTeamNumber = nil
    if not TGNS.GetIsClientVirtual(joiningClient) then
        local playerList = GetPlayingPlayers(joiningClient)
        if ServerIsFull(playerList) then
            local joiningSteamId = TGNS.GetClientSteamId(joiningClient)
            local victimClient = FindVictimClient(joiningSteamId, playerList)
            if victimClient ~= nil then
                local victimPlayer = TGNS.GetPlayer(victimClient)
                victimTeamNumber = TGNS.GetPlayerTeamNumber(victimPlayer)
                tgnsMd:ToPlayerNotifyInfo(victimPlayer, Shine.Plugins.communityslots:GetBumpMessage(victimClient))
                onPreVictimKick(victimClient,victimPlayer,joiningClient,playerList)
                TGNS.ExecuteClientCommand(victimClient, "readyroom")
                tgnsMd:ToAdminConsole(GetBumpSummary(playerList, victimClient, "VICTIM"))
                TGNS.RemoveAllMatching(clientsWhoAreConnectedEnoughToBeConsideredBumpable, victimClient)
                tgnsMd:ToAdminConsole(string.format("%s was bumped.", TGNS.GetPlayerName(victimPlayer)))
                tgnsMd:ToPlayerNotifyInfo(victimPlayer, "You got bumped by reserved slots. You might be able to Spectate.")
            else
                local joiningPlayer = TGNS.GetPlayer(joiningClient)
                tgnsMd:ToPlayerNotifyInfo(joiningPlayer, Shine.Plugins.communityslots:GetBumpMessage(joiningClient))
                tgnsMd:ToAdminConsole(GetBumpSummary(playerList, joiningClient, "JOINER"))
                onPreJoinerKick(joiningClient,joiningPlayer,playerList)
                TGNS.ExecuteClientCommand(joiningClient, "readyroom")
                tgnsMd:ToAdminConsole(string.format("%s was bumped.", TGNS.GetPlayerName(joiningPlayer)))
                result = true
            end
        end
    end
    return result, victimTeamNumber
end

local function GetBumpCounts()
    local result = {}
    result.primerOnlyVictims = TGNS.GetNumericValueOrZero(victimBumpCounts.primerOnly)
    result.strangerVictims = TGNS.GetNumericValueOrZero(victimBumpCounts.stranger)
    result.primerOnlyRejects = TGNS.GetNumericValueOrZero(rejectBumpCounts.primerOnly)
    result.strangerRejects = TGNS.GetNumericValueOrZero(rejectBumpCounts.stranger)
    result.totalVictims = result.primerOnlyVictims + result.strangerVictims
    result.totalRejects = result.primerOnlyRejects + result.strangerRejects
    return result
end

local function PrintBumpCountsReport(client)
    local bumpCounts = GetBumpCounts()
    tgnsMd:ToClientConsole(client, string.format("BUMP TOTALS SO FAR THIS MAP (%s):", bumpCounts.totalVictims + bumpCounts.totalRejects))
    tgnsMd:ToClientConsole(client, string.format("Victims: %s (%s Primer Only; %s Stranger)", bumpCounts.totalVictims, bumpCounts.primerOnlyVictims, bumpCounts.strangerVictims))
    tgnsMd:ToClientConsole(client, string.format("Rejects: %s (%s Primer Only; %s Stranger)", bumpCounts.totalRejects, bumpCounts.primerOnlyRejects, bumpCounts.strangerRejects))
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "communityslots.json"

function Plugin:GetPlayersForNewGame()
    local clients = TGNS.GetClientList()
    TGNS.SortAscending(clients, function(c)
        return TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, c) and 0 or (TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c) or math.huge)
    end)
    local result = {}
    TGNS.DoFor(clients, function(c, index)
        if index <= 16 then
            table.insert(result, TGNS.GetPlayer(c))
        end
    end)
    return result
end

function Plugin:GetBumpMessage(targetClient)
    local result = string.format(Shine.Plugins.communityslots.Config.BumpReason, TGNS.GetClientName(targetClient), Shine.Plugins.communityslots.Config.MaximumSlots - Shine.Plugins.communityslots.Config.CommunitySlots, Shine.Plugins.communityslots.Config.MaximumSlots - Shine.Plugins.communityslots.Config.CommunitySlots)
    if Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled() then
        result = result .. " Captains Game in play!"
    end
    return result
end

function Plugin:IsTargetBumpable(targetClient, playerList, joiningSteamId)
    local result = not TGNS.GetIsClientVirtual(targetClient)
    if result then
        local joinerIsStranger = TGNS.IsSteamIdStranger(joiningSteamId)
        local targetIsSM = TGNS.IsClientSM(targetClient)
        local targetIsProtectedCommander = IsTargetProtectedCommander(targetClient)
        local targetIsProtectedStranger = IsTargetProtectedStranger(targetClient, playerList)
        local targetIsProtectedPrimerOnly = IsTargetProtectedPrimerOnly(targetClient, playerList)
        local targetAndJoiningArePrimerOnly = TargetAndJoiningArePrimerOnly(targetClient, joiningSteamId)
        local targetIsPrimerOnlyWhoIsProtectedDueToExcessStrangers = IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList)
        local targetIsNotYetConnectedEnoughToBeConsideredBumpable = not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, targetClient)
        local captainsModeIsEnabled = Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled()

        if joinerIsStranger or targetIsSM or targetIsProtectedCommander or targetIsProtectedStranger or targetIsProtectedPrimerOnly or targetAndJoiningArePrimerOnly or targetIsPrimerOnlyWhoIsProtectedDueToExcessStrangers or targetIsNotYetConnectedEnoughToBeConsideredBumpable or captainsModeIsEnabled
        then
            result = false
        end
    end
    return result
end

function Plugin:ClientConnect(joiningClient)
    if TGNS.GetIsClientVirtual(joiningClient) then
        TGNS.ScheduleAction(3, function() self:ClientConfirmConnect(joiningClient) end)
    end
end

function Plugin:ClientConfirmConnect(client)
    TGNSConnectedTimesTracker.SetClientConnectedTimeInSeconds(client)
    local chatMessage
    if TGNS.IsClientSM(client) then
        chatMessage = "Supporting Member! Thank you! Your help makes our two servers possible!"
    elseif TGNS.HasClientSignedPrimer(client) then
        chatMessage = string.format("TGNS Primer signer! Join the full server when >%s strangers are playing!", Shine.Plugins.communityslots.Config.MinimumStrangers)
    else
        chatMessage = "Press 'm' for menu. Visit tacticalgamer.com/natural-selection to say hello!"
    end
    if not TGNS.GetIsClientVirtual(client) then
        TGNS.PlayerAction(client, function(p) tgnsMd:ToPlayerNotifyInfo(p, chatMessage) end)
    end
end

TGNS.RegisterEventHook("OnSlotTaken", function(client)
    UpdateReservedSlotAmount()
end)

function Plugin:EndGame(gamerules, winningTeam)
    TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
        local bumpCounts = GetBumpCounts()
        TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
            PrintBumpCountsReport(c)
        end)
        commandStructureLastOccupancies = {}
    end)
end

function Plugin:CreateCommands()
    local logCommand = self:BindCommand( "sh_cslog", "cslog", function(client)
        TGNS.DoFor(actionslog, function(logline, index)
                tgnsMd:ToClientConsole(client, logline)
                if #actionslog - index <= 5 then
                    tgnsMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), logline)
                end
            end
        )
        PrintBumpCountsReport(client)
    end)
    logCommand:Help( "View the Community Slots log." )
end

//local function PrintPlayerSlotsStatuses(client)
//    local playerList = TGNS.GetPlayerList()
//    local smClients = TGNS.GetSmClients(playerList)
//    local primerOnlyClients = TGNS.GetPrimerOnlyClients(playerList)
//    local strangerClients = TGNS.GetStrangersClients(playerList)
//    TGNS.DoFor(smClients, function(c) TGNS.ConsolePrint(client, string.format("Supporting Member: %s %s", TGNS.GetClientName(c), TGNS.HasClientSignedPrimer(c) and "(signed TGNS Primer)" or ""), MESSAGE_PREFIX) end)
//    TGNS.DoFor(primerOnlyClients, function(c) TGNS.ConsolePrint(client, string.format("Primer Only: %s", TGNS.GetClientName(c)), MESSAGE_PREFIX) end)
//    TGNS.DoFor(strangerClients, function(c) TGNS.ConsolePrint(client, string.format("Say Hello To: %s", TGNS.GetClientName(c)), MESSAGE_PREFIX) end)
//    TGNS.ConsolePrint(client, string.format("S: %s | P: %s | ?: %s", #smClients, #primerOnlyClients, #strangerClients), MESSAGE_PREFIX)
//    PrintBumpCountsReport(client)
//end
//TGNS.RegisterCommandHook("Console_sv_csinfo", PrintPlayerSlotsStatuses, "Print Community Slots bump counts and player statuses.", true)

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
    local cancel = false
    local victimTeamNumber = nil
    local joiningClient = TGNS.GetClient(player)
    if TGNS.IsGameplayTeamNumber(newTeamNumber) then
        if not (force or shineForce) then
            cancel, victimTeamNumber = IsClientBumped(joiningClient)
        end
        if cancel then
            tgnsMd:ToPlayerNotifyError(player, "Teams are full (8v8). You might be able to join Spectate.")
            tgnsMd:ToAdminConsole(string.format("%s was not allowed to JoinTeam.", TGNS.GetPlayerName(player)))
            TGNS.RemoveAllMatching(clientsWhoAreConnectedEnoughToBeConsideredBumpable, joiningClient)
        else
            if not (force or shineForce) and not TGNS.GetIsClientVirtual(joiningClient) then
                if victimTeamNumber ~= nil and newTeamNumber ~= victimTeamNumber then
                    cancel = true
                    TGNS.SendToTeam(player, victimTeamNumber)
                    tgnsMd:ToPlayerNotifyInfo(player, string.format("You were placed on %s to preserve 8v8.", TGNS.GetTeamName(victimTeamNumber)))
                end
            end
        end
    elseif newTeamNumber == kSpectatorIndex then
        -- SMs may spec mid-game; anyone may spec pre-game (limit enforced)
        if not (force or shineForce) then
            local spectateIsFull = #TGNS.GetSpectatorClients(TGNS.GetPlayerList()) >= self.Config.MaximumSpectators
            if TGNS.IsGameInProgress() and not ServerIsFull(GetPlayingPlayers()) and not (TGNS.IsClientAdmin(joiningClient) or TGNS.IsClientSM(joiningClient)) then
                tgnsMd:ToPlayerNotifyError(player, "Mid-game spectate is available only when teams are 8v8.")
                cancel = true
            end
            if not cancel then
                if spectateIsFull and not TGNS.IsClientAdmin(joiningClient) then
                    cancel = true
                    tgnsMd:ToPlayerNotifyError(player, "Sorry. Spectate is full (spectators are usually hidden on scoreboard).")
                    tgnsMd:ToAdminConsole(string.format("%s was not allowed to Spectate.", TGNS.GetPlayerName(player)))
                end
            end
        end
    end
    TGNS.ScheduleAction(2, UpdateReservedSlotAmount)
    if cancel then
        return false
    end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
    local client = TGNS.GetClient(player)
    inReadyRoomSinceTimes[client] = TGNS.IsPlayerReadyRoom(player) and TGNS.GetSecondsSinceMapLoaded() or nil
    if TGNS.IsGameplayTeamNumber(newTeamNumber) then
        if not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client) then
            table.insert(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client)
            TGNS.ExecuteEventHooks("OnSlotTaken", client)
        end
    elseif newTeamNumber == kSpectatorIndex then
        TGNS.RemoveAllMatching(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client)
    end
end

local function sweep()
    local totalPlayersOnServer = TGNS.GetPlayerList()
    local countOfTotalPlayersOnServer = #totalPlayersOnServer
    local countOfPlayingPlayers = #GetPlayingPlayers()
    TGNS.DoFor(TGNS.GetReadyRoomClients(totalPlayersOnServer), function(c)
        if totalPlayersOnServer > 16 then
            if countOfPlayingPlayers >= 10 or totalPlayersOnServer >= Shine.Plugins.communityslots.Config.MaximumSlots-3 then
                local lastTeamChangeTime = inReadyRoomSinceTimes[c]
                if lastTeamChangeTime then
                    local secondsRemaining = TGNS.RoundPositiveNumberDown(lastTeamChangeTime + 60 - TGNS.GetSecondsSinceMapLoaded())
                    if secondsRemaining > 0 then
                        // todo?: add to temp group that appears on scoreboard (would need to remove group on successful join of team or spectate)
                        if secondsRemaining < 40 then
                            tgnsMd:ToPlayerNotifyInfo(TGNS.GetPlayer(c), string.format("Play or Spectate within %s seconds to stay on the server.", secondsRemaining))
                            AnnounceOtherServerOptionsToBumpedClient(c)
                        end
                    else
                        TGNSClientKicker.Kick(c, "Too long spent in the Ready Room.", nil, AnnounceClientBumpToStrangers)
                        tgnsMd:ToAdminNotifyInfo(string.format("%s kicked for being in the Ready Room too long.", TGNS.GetClientName(c)))
                    end
                else
                    inReadyRoomSinceTimes[c] = TGNS.GetSecondsSinceMapLoaded()
                end
            else
                inReadyRoomSinceTimes[c] = TGNS.GetSecondsSinceMapLoaded()
            end
        else
            inReadyRoomSinceTimes[c] = TGNS.GetSecondsSinceMapLoaded()
        end
    end)
end

function Plugin:ClientDisconnect(client)
    UpdateReservedSlotAmount()
end

TGNS.RegisterEventHook("CheckConnectionAllowed", function(joiningSteamId)
    local result = true
    if not TGNS.IsSteamIdAdmin(joiningSteamId) then
        local playerList = GetPlayingPlayers()
        if ServerIsFull(playerList) then
            local bumpableClient = FindVictimClient(joiningSteamId, playerList)
            result = bumpableClient ~= nil
        end
    end
    return result
end)

function Plugin:Think()
    TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientCommander), function(client)
        commandStructureLastOccupancies[client] = Shared.GetTime()
    end)
end

function Plugin:PlayerSay(client, networkMessage)
    local cancel = false
    local teamOnly = networkMessage.teamOnly
    local message = StringTrim(networkMessage.message)
    if not teamOnly then
        TGNS.PlayerAction(client, function(p)
            if TGNS.IsPlayerSpectator(p) then
                tgnsMd:ToPlayerNotifyError(p, "Press 'y' for Spectator or @admin chat.")
                if TGNS.IsClientAdmin(client) then
                    tgnsMd:ToPlayerNotifyError(p, "Full admin note: sh_say (chat: !say) is also available.")
                end
                cancel = true
            else
                if TGNS.IsPlayerReadyRoom(p) and TGNS.IsGameInProgress() and not TGNS.HasClientSignedPrimer(client) then
                    if ServerIsFull(GetPlayingPlayers()) and not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client) then
                        tgnsMd:ToPlayerNotifyError(p, "You must read and agree to the TGNS Primer")
                        tgnsMd:ToPlayerNotifyError(p, "to chat to a full game from the Ready Room.")
                        tgnsMd:ToPlayerNotifyError(p, "Team chat with '@' goes to all admins.")
                        cancel = true
                    end
                end
            end
        end)
    end
    if cancel then
        return ""
    end
end



function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()
    TGNS.ScheduleActionInterval(10, sweep)
    TGNS.ScheduleActionInterval(10, AnnounceRemainingPublicSlots)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("communityslots", Plugin)