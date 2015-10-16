local NUMBER_OF_SLOTS_TO_LEAVE_FOR_JOINERS_DURING_NON_CAPTAINS_GAMES = 2
local actionslog = { }
local clientsWhoAreConnectedEnoughToBeConsideredBumpable = {}
local MESSAGE_PREFIX = "SLOTS"
table.insert(actionslog, "COMMUNITY SLOTS DEBUG: ")
local victimBumpCounts = {}
local rejectBumpCounts = {}
local commandStructureLastOccupancies = {}
local lastSetReservedSlotAmount
local inReadyRoomSinceTimes = {}
local fullSpecDataRepository
local fullSpecSteamIds
local canNotifyAboutOtherServerSlots = true
local blacklistedClients = {}
local lastAnnouncedRemainingPublicSlotsCount

local COMMANDER_PROTECTION_DURATION_IN_SECONDS = 60
local clientConnectTimesInSeconds = {}

local otherServerStaticInfo = {}
otherServerStaticInfo["Taunt"] = { address = "tgns2.tacticalgamer.com", simpleName = "Chuckle" }
otherServerStaticInfo["Chuckle"] = { address = "tgns.tacticalgamer.com", simpleName = "Taunt" }

local tgnsMd = TGNSMessageDisplayer.Create("TGNS")
local slotsDebugMd = TGNSMessageDisplayer.Create("SLOTSDEBUG")

local function getCommunitySlotsCount()
    local result = Server.GetMaxPlayers() - Shine.Plugins.communityslots.Config.PublicSlots
    return result
end

local function getMaximumSpectatorsCount()
    local result = getCommunitySlotsCount() - NUMBER_OF_SLOTS_TO_LEAVE_FOR_JOINERS_DURING_NON_CAPTAINS_GAMES
    return result
end

local function IsClientAmongLongestPlayed(clients, client, limit)
    TGNS.SortDescending(clients, TGNSConnectedTimesTracker.GetPlayedTimeInSeconds)
    local result = TGNS.ElementIsFoundBeforeIndex(clients, client, limit)
    return result
end

local function IsTargetProtectedStranger(targetClient, playerList)
    local strangersClients = TGNS.GetStrangersClients(playerList)
    local strangersClientsWithFewerThanTenGames = TGNS.Where(strangersClients, function(c) return Balance.GetTotalGamesPlayed(c) < TGNS.PRIMER_GAMES_THRESHOLD end)
    local result = IsClientAmongLongestPlayed(strangersClientsWithFewerThanTenGames, targetClient, Shine.Plugins.communityslots.Config.MinimumStrangers)
    return result
end

local function clientSatisfiesBkaRequirement(client)
    local result = client == nil or Shine.Plugins.betterknownas:IsPlayingWithBkaName(client)
    return result
end

local function IsTargetProtectedPrimerOnly(targetClient, playerList)
    local candidateClients = TGNS.Where(TGNS.GetPrimerOnlyClients(playerList), function(c) return clientSatisfiesBkaRequirement(c) end)
    local result = IsClientAmongLongestPlayed(candidateClients, targetClient, Shine.Plugins.communityslots.Config.MinimumPrimerOnlys)
    return result
end

local function IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList)
    local result = TGNS.IsPrimerOnlyClient(targetClient) and clientSatisfiesBkaRequirement(targetClient) and #TGNS.GetStrangersClients(playerList) > Shine.Plugins.communityslots.Config.MinimumStrangers
    return result
end

local function TargetAndJoiningArePrimerOnly(targetClient, joiningSteamId)
    local result = (TGNS.IsPrimerOnlyClient(targetClient) and clientSatisfiesBkaRequirement(targetClient)) and (TGNS.IsSteamIdPrimerOnly(joiningSteamId) and clientSatisfiesBkaRequirement(TGNS.GetClientByNs2Id(joiningSteamId)))
    return result
end

local function GetRemainingPublicSlots(playingPlayers)
    local result = Shine.Plugins.communityslots.Config.PublicSlots - #playingPlayers
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

local function FindVictimClient(joiningSteamId, playerList, passingTheBumpKarmaDelta)
    local result = nil
    local bumpableClients = TGNS.GetMatchingClients(playerList, function(c,p) return Shine.Plugins.communityslots:IsTargetBumpable(c, playerList, joiningSteamId) end)
    local clientsGivenImmunityViaKarma = {}
    if #bumpableClients > 0 then
        TGNS.SortDescending(bumpableClients, TGNSConnectedTimesTracker.GetPlayedTimeInSeconds)

        local potentiallyImmuneClients = {}
        if type(passingTheBumpKarmaDelta) == "number" then
            TGNS.DoFor(bumpableClients, function(c)
                if TGNS.Karma(c) >= math.abs(passingTheBumpKarmaDelta) then
                    table.insert(potentiallyImmuneClients, c)
                else
                    slotsDebugMd:ToAdminConsole(string.format("NOW ENABLED: %s (%s Karma) - not enough Karma for slots immunity.", TGNS.GetClientName(c), TGNS.Karma(c)))
                    return true
                end
            end)
        end
        if #potentiallyImmuneClients > 0 and #potentiallyImmuneClients < #bumpableClients then
            TGNS.DoForReverse(bumpableClients, function(c, i)
                if TGNS.Has(potentiallyImmuneClients, c) then
                    table.insert(clientsGivenImmunityViaKarma, c)
                    table.remove(bumpableClients, i)
                end
            end)
        end

        result = TGNS.GetFirst(bumpableClients)
    end
    return result, clientsGivenImmunityViaKarma
end

local function GetKickDetails(targetClient, joiningClient, playerList)
    local result = {}
    result.targetIsSM = TGNS.IsClientSM(targetClient) and "Y" or "N"
    result.targetHasSignedPrimer = TGNS.HasClientSignedPrimerWithGames(targetClient) and "Y" or "N"
    result.joinerIsSM = TGNS.IsClientSM(joiningClient) and "Y" or "N"
    result.joinerHasSignedPrimer = TGNS.IsClientSM(joiningClient) and "Y" or "N"
    result.strangerCount = #TGNS.GetStrangersClients(playerList)
    result.primerOnlyCount = #TGNS.GetPrimerOnlyClients(playerList)
    result.smCount = #TGNS.GetSmClients(playerList)
    result.shortReport = string.format("T: %s%s J:%s%s ?:%s P:%s S:%s Total:%s", result.targetIsSM, result.targetHasSignedPrimer, result.joinerIsSM, result.joinerHasSignedPrimer, result.strangerCount, result.primerOnlyCount, result.smCount, #playerList)
    return result
end

local function IncrementBumpCount(targetClient, bumpCounts)
    if TGNS.HasClientSignedPrimerWithGames(targetClient) then
        bumpCounts.primerOnly = TGNS.GetNumericValueOrZero(bumpCounts.primerOnly) + 1
    elseif TGNS.IsClientStranger(targetClient) then
        bumpCounts.stranger = TGNS.GetNumericValueOrZero(bumpCounts.stranger) + 1
    end
end

local function AnnounceClientBumpToStrangers(playerName)
    local strangerClients = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return TGNS.IsClientStranger(c) end)
    local strangerPlayers = TGNS.GetPlayers(strangerClients)
    TGNS.DoFor(strangerPlayers, function(p) tgnsMd:ToPlayerNotifyInfo(p, Shine.Plugins.communityslots:GetBumpMessage(playerName)) end)
end

// local function AnnounceOtherServerOptionsToBumpedClient(client)
//     local otherServerStaticInfo = otherServerStaticInfo[TGNS.GetSimpleServerName()]
//     if otherServerStaticInfo then
//         TGNSServerInfoGetter.GetInfoBySimpleServerName(otherServerStaticInfo.simpleName, function(getResponse)
//             if getResponse.success then
//                 local otherServerDynamicInfo = getResponse.value
//                 if otherServerDynamicInfo.HasRecentData then
//                     local otherServerRemainingPublicSlots = otherServerDynamicInfo.GetPublicSlotsRemaining()
//                     if otherServerRemainingPublicSlots >= 4 then
//                         local message = string.format("~%s slots open on %s! Console: connect %s", otherServerRemainingPublicSlots, otherServerStaticInfo.simpleName, otherServerStaticInfo.address)
//                         tgnsMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), message)
//                         tgnsMd:ToClientConsole(client, message)
//                         tgnsMd:ToAdminConsole(message)
//                     end
//                 end
//             end
//         end)
//     end
// end

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

local function UpdateReservedSlotsTag(reservedSlotCount)
    local Tags = {}

    Server.GetTags( Tags )

    for i = 1, #Tags do
        local Tag = Tags[ i ]

        if Tag and Tag:find( "R_S" ) then
            Server.RemoveTag( Tag )
        end
    end

    Server.AddTag( "R_S"..reservedSlotCount )
end

local function UpdateReservedSlotAmount()
    local countNonPlayingPlayersConservatively = (TGNS.GetAbbreviatedDayOfWeek() == "Friday" and TGNS.GetCurrentHour() >= 19) or (TGNS.GetAbbreviatedDayOfWeek() == "Sat" and TGNS.GetCurrentHour() < 6)
    local afkNonPlayingThresholdInSeconds = countNonPlayingPlayersConservatively and 300 or 120
    local clientJoinedAfkAndStillIs = function(c) return Shine:IsValidClient(c) and not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, c) and (TGNS.GetSecondsSinceMapLoaded() - (clientConnectTimesInSeconds[c] or 0) > afkNonPlayingThresholdInSeconds) end
    local playerIsLikelyGone = function(p) return ((TGNS.GetPlayerAfkDurationInSeconds(p) >= afkNonPlayingThresholdInSeconds) or clientJoinedAfkAndStillIs(TGNS.GetClient(p))) and TGNS.IsPlayerReadyRoom(p) end
    local nonPlayingPlayersCount = #TGNS.Where(TGNS.GetPlayerList(), function(p) return (TGNS.IsPlayerSpectator(p) or playerIsLikelyGone(p)) and not TGNS.ClientAction(p, TGNS.GetIsClientVirtual) end)
    if not countNonPlayingPlayersConservatively then
        nonPlayingPlayersCount = nonPlayingPlayersCount + TGNS.GetNumberOfConnectingPlayers()
    end
    local usableNonPlayablePlayersCount = (Server.GetNumPlayersTotal() >= Shine.Plugins.communityslots.Config.PublicSlots) and nonPlayingPlayersCount or 0
    local reservedSlotCount = getCommunitySlotsCount() - usableNonPlayablePlayersCount
    reservedSlotCount = reservedSlotCount > 0 and reservedSlotCount or 0
    if lastSetReservedSlotAmount ~= reservedSlotCount then
        UpdateReservedSlotsTag(reservedSlotCount)
        lastSetReservedSlotAmount = reservedSlotCount
    end
end

local function AnnounceRemainingPublicSlots()
    local playingPlayers = GetPlayingPlayers()
    local remainingPublicSlotsCount = GetRemainingPublicSlots(playingPlayers)
    if lastAnnouncedRemainingPublicSlotsCount == nil or lastAnnouncedRemainingPublicSlotsCount ~= remainingPublicSlotsCount then
        TGNS.ExecuteEventHooks("PublicSlotsRemainingChanged", TGNS.GetSimpleServerName(), remainingPublicSlotsCount, #playingPlayers)
        lastAnnouncedRemainingPublicSlotsCount = remainingPublicSlotsCount
    end
    UpdateReservedSlotAmount()
end

local function GetBumpSummary(playerList, bumpingClient, bumpedClient, joinerOrVictim)
    local supportingMembersCount = #TGNS.GetSmClients(playerList)
    local primerOnlysCount = #TGNS.GetPrimerOnlyClients(playerList)
    local strangersCount = #TGNS.GetStrangersClients(playerList)
    local aliensCount = #TGNS.GetAlienClients(playerList)
    local marinesCount = #TGNS.GetMarineClients(playerList)
    local bumpingClientName = TGNS.GetClientName(bumpingClient)
    local bumpedClientName = TGNS.GetClientName(bumpedClient)
    local bumpingClientCommunityDesignationCharacter = TGNS.GetClientCommunityDesignationCharacter(bumpingClient)
    local bumpedClientCommunityDesignationCharacter = TGNS.GetClientCommunityDesignationCharacter(bumpedClient)
    local bumpedClientPlayedTimeInSeconds = TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(bumpedClient) or 0
    local bumpedClientPlayedDurationClock = TGNS.SecondsToClock(bumpedClientPlayedTimeInSeconds)
    local result = string.format("%s %s bumping %s %s> %s after %s with S:%s P:%s ?:%s A:%s M:%s", bumpingClientCommunityDesignationCharacter, bumpingClientName, joinerOrVictim, bumpedClientCommunityDesignationCharacter, bumpedClientName, bumpedClientPlayedDurationClock, supportingMembersCount, primerOnlysCount, strangersCount, aliensCount, marinesCount)
    return result
end

local function IsClientBumped(joiningClient)
    local result = false
    local victimTeamNumber = nil
    if not TGNS.GetIsClientVirtual(joiningClient) then
        local playerList = GetPlayingPlayers(joiningClient)
        if ServerIsFull(playerList) then
            local joiningSteamId = TGNS.GetClientSteamId(joiningClient)
            local victimClient, clientsGivenImmunityViaKarma
            if not blacklistedClients[joiningClient] then
                victimClient, clientsGivenImmunityViaKarma = FindVictimClient(joiningSteamId, playerList, Shine.Plugins.karma.Config.Deltas["PassingTheBump"])
            end
            local joiningName = TGNS.GetClientName(joiningClient)
            local blacklistAdvisoryClient
            if victimClient ~= nil then
                local victimPlayer = TGNS.GetPlayer(victimClient)
                victimTeamNumber = TGNS.GetPlayerTeamNumber(victimPlayer)
                local victimName = TGNS.GetClientName(victimClient)
                tgnsMd:ToPlayerNotifyInfo(victimPlayer, Shine.Plugins.communityslots:GetBumpMessage(victimName))
                onPreVictimKick(victimClient,victimPlayer,joiningClient,playerList)
                TGNS.ExecuteClientCommand(victimClient, "readyroom")
                slotsDebugMd:ToAdminConsole(GetBumpSummary(playerList, joiningClient, victimClient, "VICTIM"))
                TGNS.Karma(joiningClient, "Bumping")
                TGNS.DoFor(clientsGivenImmunityViaKarma, function(c)
                    slotsDebugMd:ToAdminConsole(string.format("NOW ENABLED: %s (%s Karma) - enough Karma for slots immunity.", TGNS.GetClientName(c), TGNS.Karma(c)))
                    TGNS.Karma(c, "PassingTheBump")
                end)
                TGNS.RemoveAllMatching(clientsWhoAreConnectedEnoughToBeConsideredBumpable, victimClient)
                tgnsMd:ToPlayerNotifyInfo(victimPlayer, "You got bumped by reserved slots. You might be able to Spectate.")
                tgnsMd:ToClientConsole(victimClient, string.format("%s %s protected by good Karma. Learn more in the Required Reading's Reserved Slots (Advanced Logic) section.", Pluralize(#clientsGivenImmunityViaKarma, "player"), #clientsGivenImmunityViaKarma == 1 and "was" or "were"))
                if blacklistedClients[victimClient] then
                    blacklistAdvisoryClient = victimClient
                end
            else
                local joiningPlayer = TGNS.GetPlayer(joiningClient)
                tgnsMd:ToPlayerNotifyInfo(joiningPlayer, Shine.Plugins.communityslots:GetBumpMessage(joiningName))
                slotsDebugMd:ToAdminConsole(GetBumpSummary(playerList, joiningClient, joiningClient, "JOINER"))
                onPreJoinerKick(joiningClient,joiningPlayer,playerList)
                TGNS.ExecuteClientCommand(joiningClient, "readyroom")
                result = true
                if blacklistedClients[joiningClient] then
                    blacklistAdvisoryClient = joiningClient
                end
            end
            if blacklistAdvisoryClient then
                    tgnsMd:ToPlayerNotifyInfo(TGNS.GetPlayer(blacklistAdvisoryClient), "Your reserved slot is presently revoked. See console for details.")
                    tgnsMd:ToClientConsole(blacklistAdvisoryClient, "Your reserved slot privilege is presently revoked.")
                    tgnsMd:ToClientConsole(blacklistAdvisoryClient, "Do not on the server complain or inquire about revoked privileges.")
                    tgnsMd:ToClientConsole(blacklistAdvisoryClient, "Rather, use the CAA forum: http://rr.tacticalgamer.com/Community")
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

-- local function getCountOfPlayersWhoCanBumpTarget(targetClient, playerList, steamIds)
--     local result = 0
--     TGNS.DoFor(steamIds, function(steamId)
--         if Shine.Plugins.communityslots:IsTargetBumpable(targetClient, playerList, steamId) then
--             result = result + 1
--         end
--     end)
--     return result
-- end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "communityslots.json"

function Plugin:IsClientRecentCommander(client)
    return IsTargetProtectedCommander(client)
end

function Plugin:GetPlayersForNewGame()
    local prioritizedPlayers = {}
    local addToPrioritizedPlayers = function(p) table.insert(prioritizedPlayers, p) end
    local getPlayerPlayedTime = function(p) return TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(TGNS.GetClient(p)) end

    local playerList = TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.IsPlayerReadyRoom(p) and not TGNS.IsPlayerAFK(p) and not TGNS.GetIsClientVirtual(TGNS.GetClient(p)) end)
    local supportingMemberPlayers = TGNS.Where(playerList, TGNS.IsPlayerSM)

    local primerOnlyPlayers = TGNS.Where(playerList, TGNS.IsPrimerOnlyPlayer)
    local protectedPrimerOnlyPlayers = TGNS.Where(primerOnlyPlayers, function(p) return IsTargetProtectedPrimerOnly(TGNS.GetClient(p), primerOnlyPlayers) end)
    local otherPrimerOnlyPlayers = TGNS.Where(primerOnlyPlayers, function(p) return not TGNS.Has(protectedPrimerOnlyPlayers, p) end)

    local strangerPlayers = TGNS.Where(playerList, TGNS.IsPlayerStranger)
    local protectedStrangerPlayers = TGNS.Where(strangerPlayers, function(p) return IsTargetProtectedStranger(TGNS.GetClient(p), strangerPlayers) end)
    local otherStrangerPlayers = TGNS.Where(strangerPlayers, function(p) return not TGNS.Has(protectedStrangerPlayers, p) end)

    TGNS.SortDescending(protectedStrangerPlayers, getPlayerPlayedTime)
    TGNS.SortDescending(protectedPrimerOnlyPlayers, getPlayerPlayedTime)
    TGNS.SortAscending(supportingMemberPlayers, getPlayerPlayedTime)
    TGNS.SortAscending(otherPrimerOnlyPlayers, getPlayerPlayedTime)
    TGNS.SortAscending(otherStrangerPlayers, getPlayerPlayedTime)

    TGNS.DoFor(protectedStrangerPlayers, addToPrioritizedPlayers)
    TGNS.DoFor(protectedPrimerOnlyPlayers, addToPrioritizedPlayers)
    TGNS.DoFor(supportingMemberPlayers, addToPrioritizedPlayers)
    TGNS.DoFor(otherPrimerOnlyPlayers, addToPrioritizedPlayers)
    TGNS.DoFor(otherStrangerPlayers, addToPrioritizedPlayers)

    -- TGNS.DebugPrint("Prioritized players for new game:")
    -- TGNS.DoFor(prioritizedPlayers, function(p, index)
    --     local c = TGNS.GetClient(p)
    --     TGNS.DebugPrint(string.format("%s. %s%s> %s (%s)", index, TGNS.IsPlayerAFK(p) and "!" or "", TGNS.GetClientCommunityDesignationCharacter(c), TGNS.GetClientName(c), TGNS.SecondsToClock(TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(c))))
    -- end)

    local result = TGNS.Take(prioritizedPlayers, Shine.Plugins.communityslots.Config.PublicSlots)
    return result
end

function Plugin:GetBumpMessage(targetName)
    local result = string.format(Shine.Plugins.communityslots.Config.BumpReason, targetName, Shine.Plugins.communityslots.Config.PublicSlots, Shine.Plugins.communityslots.Config.PublicSlots)
    if Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled() then
        result = result .. " Captains Game in play!"
    end
    return result
end

function Plugin:IsTargetBumpable(targetClient, playerList, joiningSteamId)
    local result = not TGNS.GetIsClientVirtual(targetClient)
    if result then
        local targetClientHasSlotsPrivilege = not blacklistedClients[targetClient]
        local joinerIsStranger = TGNS.IsSteamIdStranger(joiningSteamId)
        local joinerIsPrimerSignerWhoIsNotPlayingWithBka = TGNS.IsSteamIdPrimerOnly(joiningSteamId) and not clientSatisfiesBkaRequirement(TGNS.GetClientByNs2Id(joiningSteamId))
        local targetIsSM = TGNS.IsClientSM(targetClient) and targetClientHasSlotsPrivilege
        local targetIsProtectedCommander = IsTargetProtectedCommander(targetClient)
        local targetIsProtectedStranger = IsTargetProtectedStranger(targetClient, playerList) and targetClientHasSlotsPrivilege
        local targetIsProtectedPrimerOnly = IsTargetProtectedPrimerOnly(targetClient, playerList) and targetClientHasSlotsPrivilege
        local targetAndJoiningArePrimerOnly = TargetAndJoiningArePrimerOnly(targetClient, joiningSteamId) and targetClientHasSlotsPrivilege
        local targetIsPrimerOnlyWhoIsProtectedDueToExcessStrangers = IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList) and targetClientHasSlotsPrivilege
        local targetIsNotYetConnectedEnoughToBeConsideredBumpable = not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, targetClient)
        local captainsModeIsEnabled = Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled() and targetClientHasSlotsPrivilege

        if joinerIsStranger or joinerIsPrimerSignerWhoIsNotPlayingWithBka or targetIsSM or targetIsProtectedCommander or targetIsProtectedStranger or targetIsProtectedPrimerOnly or targetAndJoiningArePrimerOnly or targetIsPrimerOnlyWhoIsProtectedDueToExcessStrangers or targetIsNotYetConnectedEnoughToBeConsideredBumpable or captainsModeIsEnabled
        then
            result = false
        end
    end
    return result
end

function Plugin:ClientConnect(joiningClient)
    if TGNS.GetIsClientVirtual(joiningClient) then
        TGNS.ScheduleAction(3, function()
            if Shine:IsValidClient(joiningClient) then
                self:ClientConfirmConnect(joiningClient)
            end
        end)
    else
        local pbr = TGNSPlayerBlacklistRepository.Create("communityslots")
        pbr:IsClientBlacklisted(joiningClient, function(isBlacklisted)
            blacklistedClients[joiningClient] = isBlacklisted
        end)
    end
    clientConnectTimesInSeconds[joiningClient] = TGNS.GetSecondsSinceMapLoaded()
end

function Plugin:ClientConfirmConnect(client)
    local chatMessage
    if TGNS.IsClientSM(client) then
        chatMessage = "Supporting Member! Thank you! Your help makes TG's servers possible!"
    elseif TGNS.HasClientSignedPrimerWithGames(client) then
        chatMessage = string.format("TGNS Primer signer! Join the full server when >%s strangers are playing!", Shine.Plugins.communityslots.Config.MinimumStrangers)
    else
        chatMessage = "Press 'm' for menu. Visit http://rr.tacticalgamer.com/Community to say hello!"
    end
    if not TGNS.GetIsClientVirtual(client) then
        TGNS.ScheduleAction(2, function()
            if Shine:IsValidClient(client) then
                tgnsMd:ToClientConsole(client, chatMessage)
            end
        end)
    end
    local steamId = TGNS.GetClientSteamId(client)
    if ServerIsFull(GetPlayingPlayers()) and TGNS.Has(fullSpecSteamIds, steamId) then
        TGNS.ScheduleAction(1, function()
            if Shine:IsValidClient(client) then
                tgnsMd:ToClientConsole(client, "Your sh_fullspec is enabled. Help: M > Info > sh_fullspec")
            end
        end)
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

local function refreshFullSpecData()
    if fullSpecDataRepository then
        fullSpecDataRepository.Load(nil, function(loadResponse)
            if loadResponse.success then
                local fullSpecData = loadResponse.value
                fullSpecSteamIds = fullSpecData.enrolled
            else
                Shared.Message("communityslots ERROR: unable to load fullSpecSteamIds")
            end
        end)
    end
end

function Plugin:CreateCommands()
    local logCommand = self:BindCommand( "sh_cslog", "cslog", function(client)
        TGNS.DoFor(actionslog, function(logline, index)
            tgnsMd:ToClientConsole(client, logline)
            if #actionslog - index <= 5 then
                tgnsMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), logline)
            end
        end)
        PrintBumpCountsReport(client)
    end)
    logCommand:Help("View the Community Slots log.")
    local showTimesCommand = self:BindCommand( "sh_showtimes", "showtimes", TGNSConnectedTimesTracker.PrintConnectedDurations)
    showTimesCommand:Help("View connected time of each client.")
    local fullSpecCommand = self:BindCommand( "sh_fullspec", "fs", function(client)
        fullSpecDataRepository.Load(nil, function(loadResponse)
            if loadResponse.success then
                fullSpecData = loadResponse.value
                local steamId = TGNS.GetClientSteamId(client)
                if TGNS.Has(fullSpecData.enrolled, steamId) then
                    TGNS.RemoveAllMatching(fullSpecData.enrolled, steamId)
                else
                    table.insert(fullSpecData.enrolled, steamId)
                end
                fullSpecSteamIds = fullSpecData.enrolled
                fullSpecDataRepository.Save(fullSpecData, nil, function(saveResponse)
                    if saveResponse.success then
                        tgnsMd:ToClientConsole(client, string.format("Your sh_fullspec is %s.", TGNS.Has(fullSpecSteamIds, steamId) and "Enabled" or "Disabled"))
                        tgnsMd:ToClientConsole(client, "Execute the command again to toggle. Help: M > Info > sh_fullspec")
                    else
                        tgnsMd:ToPlayerNotifyError("Unable to save sh_fullspec data.")
                    end
                end)
            else
                tgnsMd:ToPlayerNotifyError("Unable to access sh_fullspec data.")
            end
        end)
    end, true)
    fullSpecCommand:Help("Toggle your sh_fullspec. Help: M > Info > sh_fullspec")

    local fullSpecRefreshCommand = self:BindCommand( "sh_fullspec_datarefresh", nil, function(client)
        refreshFullSpecData()
    end)
    fullSpecRefreshCommand:Help("Used by the TGNS Portal to sync fullspec opt-in changes.")
end

//local function PrintPlayerSlotsStatuses(client)
//    local playerList = TGNS.GetPlayerList()
//    local smClients = TGNS.GetSmClients(playerList)
//    local primerOnlyClients = TGNS.GetPrimerOnlyClients(playerList)
//    local strangerClients = TGNS.GetStrangersClients(playerList)
//    TGNS.DoFor(smClients, function(c) TGNS.ConsolePrint(client, string.format("Supporting Member: %s %s", TGNS.GetClientName(c), TGNS.HasClientSignedPrimerWithGames(c) and "(signed TGNS Primer)" or ""), MESSAGE_PREFIX) end)
//    TGNS.DoFor(primerOnlyClients, function(c) TGNS.ConsolePrint(client, string.format("Primer Only: %s", TGNS.GetClientName(c)), MESSAGE_PREFIX) end)
//    TGNS.DoFor(strangerClients, function(c) TGNS.ConsolePrint(client, string.format("Say Hello To: %s", TGNS.GetClientName(c)), MESSAGE_PREFIX) end)
//    TGNS.ConsolePrint(client, string.format("S: %s | P: %s | ?: %s", #smClients, #primerOnlyClients, #strangerClients), MESSAGE_PREFIX)
//    PrintBumpCountsReport(client)
//end
//TGNS.RegisterCommandHook("Console_sv_csinfo", PrintPlayerSlotsStatuses, "Print Community Slots bump counts and player statuses.", true)

local function getMaximumEffectiveSpectatorCount()
    local captainsModeIsEnabled = Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled()
    local result = captainsModeIsEnabled and getCommunitySlotsCount() or getMaximumSpectatorsCount()
    return result
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
    local cancel = false
    local victimTeamNumber = nil
    local joiningClient = TGNS.GetClient(player)
    TGNS.ScheduleAction(2, UpdateReservedSlotAmount)
    local publicSlotsPerTeam = Shine.Plugins.communityslots.Config.PublicSlots / 2
    local fullGameDescriptor = string.format("%sv%s", publicSlotsPerTeam, publicSlotsPerTeam)
    if TGNS.IsGameplayTeamNumber(newTeamNumber) then
        if not (force or shineForce) then
            cancel, victimTeamNumber = IsClientBumped(joiningClient)
        end
        if cancel then
            tgnsMd:ToPlayerNotifyError(player, string.format("Teams are full (%s). You might be able to join Spectate.", fullGameDescriptor))
            TGNS.RemoveAllMatching(clientsWhoAreConnectedEnoughToBeConsideredBumpable, joiningClient)
        else
            if not (force or shineForce) and not TGNS.GetIsClientVirtual(joiningClient) then
                if victimTeamNumber ~= nil and newTeamNumber ~= victimTeamNumber then
                    tgnsMd:ToPlayerNotifyInfo(player, string.format("You were placed on %s to preserve %s.", TGNS.GetTeamName(victimTeamNumber), fullGameDescriptor))
                    if Shine.Plugins.teamres and Shine.Plugins.teamres.Enabled then
                        Shine.Plugins.teamres:JoinTeam(gamesrules, player, victimTeamNumber, force, shineForce)
                    end
                    return true, victimTeamNumber
                end
            end
        end
    elseif newTeamNumber == kSpectatorIndex then
        if not (force or shineForce) then
            local spectateIsFull = #TGNS.GetSpectatorClients(TGNS.GetPlayerList()) >= getMaximumEffectiveSpectatorCount()
            local isCaptainsModeEnabled = Shine.Plugins.captains and Shine.Plugins.captains.Enabled and Shine.Plugins.captains.IsCaptainsModeEnabled and Shine.Plugins.captains.IsCaptainsModeEnabled()
            if TGNS.IsGameInProgress() and not ServerIsFull(GetPlayingPlayers()) and not (TGNS.IsClientAdmin(joiningClient) or TGNS.IsClientSM(joiningClient)) and not isCaptainsModeEnabled and Shine.Plugins.bots:GetTotalNumberOfBots() == 0 then
                tgnsMd:ToPlayerNotifyError(player, string.format("Mid-game spectate is available only when teams are %s.", fullGameDescriptor))
                cancel = true
            end
            if not cancel then
                if spectateIsFull and not TGNS.IsClientAdmin(joiningClient) then
                    cancel = true
                    tgnsMd:ToPlayerNotifyError(player, "Sorry. Spectate is full.")
                    tgnsMd:ToAdminConsole(string.format("%s was not allowed to Spectate.", TGNS.GetPlayerName(player)))
                end
            end
        end
    end
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
    TGNS.DoFor(TGNS.GetReadyRoomClients(TGNS.GetPlayerList()), function(c)
        if (Server.GetNumPlayersTotal() >= Server.GetMaxPlayers()-2) and TGNS.IsGameInProgress() then
            local lastTeamChangeTime = inReadyRoomSinceTimes[c]
            if lastTeamChangeTime then
                local secondsRemaining = TGNS.RoundPositiveNumberDown(lastTeamChangeTime + 180 - TGNS.GetSecondsSinceMapLoaded())
                if secondsRemaining > 0 then
                    // todo?: add to temp group that appears on scoreboard (would need to remove group on successful join of team or spectate)
                    if secondsRemaining < 40 then
                        local p = TGNS.GetPlayer(c)
                        tgnsMd:ToPlayerNotifyError(p, string.format("Play or Spectate within %s seconds to stay on the server.", secondsRemaining))
                        // AnnounceOtherServerOptionsToBumpedClient(c)
                        Shine.Plugins.scoreboard:AlertApplicationIconForPlayer(p)
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
    end)
end

function Plugin:ClientDisconnect(client)
    UpdateReservedSlotAmount()
end

TGNS.RegisterEventHook("CheckConnectionAllowed", function(joiningSteamId)
    local result = true
    if not TGNS.IsSteamIdAdmin(joiningSteamId) then
        local playingPlayers = GetPlayingPlayers()
        local nonSpectatorPlayers = TGNS.Where(TGNS.GetPlayerList(), function(p) return not TGNS.IsPlayerSpectator(p) and not TGNS.GetIsClientVirtual(TGNS.GetClient(p)) end)
        if ServerIsFull(nonSpectatorPlayers) then
            local bumpableClient = FindVictimClient(joiningSteamId, playingPlayers)
            local joinerWillingToSpectate = TGNS.Has(fullSpecSteamIds, joiningSteamId) or TGNS.HasSteamIdSignedPrimer(joiningSteamId)
            result = bumpableClient ~= nil or (joinerWillingToSpectate and #TGNS.GetSpectatorClients(TGNS.GetPlayerList()) < getMaximumEffectiveSpectatorCount())
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
            if TGNS.IsPlayerSpectator(p) and not (Shine.Plugins.chatchannels and Shine.Plugins.chatchannels.DoesChatStartWithChatChannelTriggerCharacter and Shine.Plugins.chatchannels:DoesChatStartWithChatChannelTriggerCharacter(message)) then
                tgnsMd:ToPlayerNotifyError(p, "Press 'y' for Spectator chat.")
                cancel = true
            else
                if TGNS.IsPlayerReadyRoom(p) and TGNS.IsGameInProgress() and not TGNS.HasClientSignedPrimerWithGames(client) then
                    if ServerIsFull(GetPlayingPlayers()) and not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client) then
                        tgnsMd:ToPlayerNotifyError(p, "You must read and agree to our rules")
                        tgnsMd:ToPlayerNotifyError(p, "to chat to a full game from the Ready Room.")
                        tgnsMd:ToPlayerNotifyError(p, "Team chat starting with '@' goes to all admins.")
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
    fullSpecDataRepository = TGNSDataRepository.Create("fullspec", function(data)
        data.enrolled = data.enrolled or {}
        return data
    end)
    TGNS.ScheduleAction(2, refreshFullSpecData)
    TGNS.RegisterEventHook("TotalPlayedGamesCountUpdated", function(client, totalGamesPlayedCount)
        if not TGNS.ClientIsInGroup(client, "primerwithgames_group") and TGNS.HasClientSignedPrimerWithGames(client) then
            TGNS.AddTempGroup(client, "primerwithgames_group")
        end
    end)
    // TGNS.ScheduleActionInterval(15, function()
    //     if canNotifyAboutOtherServerSlots then
    //         local humansCount = #TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.GetIsClientVirtual(c) end)
    //         if humansCount > 0 and humansCount < 10 then
    //             local otherServerStaticInfo = otherServerStaticInfo[TGNS.GetSimpleServerName()]
    //             if otherServerStaticInfo then
    //                 TGNSServerInfoGetter.GetInfoBySimpleServerName(otherServerStaticInfo.simpleName, function(otherServerDynamicInfo)
    //                     if otherServerDynamicInfo.HasRecentData then
    //                         local otherServerPlayingPlayersCount = otherServerDynamicInfo.GetPlayingPlayersCount()
    //                         local otherServerPublicSlotsRemaining = otherServerDynamicInfo.GetPublicSlotsRemaining()
    //                         if otherServerPlayingPlayersCount > humansCount and otherServerPublicSlotsRemaining >= humansCount then
    //                             tgnsMd:ToAllNotifyInfo(string.format("%s players and %s open slots on %s (%s ago).", otherServerPlayingPlayersCount, otherServerPublicSlotsRemaining, otherServerStaticInfo.simpleName, otherServerDynamicInfo.GetTimeElapsedSinceLastUpdate()))
    //                             tgnsMd:ToAllNotifyInfo(string.format("To join %s from your console: connect %s", otherServerStaticInfo.simpleName, otherServerStaticInfo.address))
    //                             canNotifyAboutOtherServerSlots = false
    //                             TGNS.ScheduleAction(180, function() canNotifyAboutOtherServerSlots = true end)
    //                         end
    //                     end
    //                 end)
    //             end
    //         end
    //     end
    // end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("communityslots", Plugin)