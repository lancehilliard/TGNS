//TGNS Community Slots

if kDAKConfig and kDAKConfig.CommunitySlots then
	Script.Load("lua/TGNSCommon.lua")

	local VERY_HIGH_EVENT_HANDLER_PRIORITY = 1000
	local actionslog = { }
	local clientsWhoAreConnectedEnoughToBeConsideredBumpable = {}
	local MESSAGE_PREFIX = "SLOTS"
	table.insert(actionslog, "COMMUNITY SLOTS DEBUG: ")
	local victimBumpCounts = {}
	local rejectBumpCounts = {}

	local function IsTargetProtectedStranger(targetClient, playerList)
		local result = TGNS.IsClientStranger(targetClient) and #TGNS.GetStrangersClients(playerList) <= kDAKConfig.CommunitySlots.kMinimumStrangers
		return result
	end
	
	local function IsTargetProtectedPrimerOnly(targetClient, playerList)
		local result = TGNS.IsPrimerOnlyClient(targetClient) and #TGNS.GetPrimerOnlyClients(playerList) <= kDAKConfig.CommunitySlots.kMinimumPrimerOnlys
		return result
	end
	
	local function IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList)
		local result = TGNS.IsPrimerOnlyClient(targetClient) and #TGNS.GetStrangersClients(playerList) > kDAKConfig.CommunitySlots.kMinimumStrangers
		return result
	end
	
	local function TargetAndJoiningArePrimerOnly(targetClient, joiningClient)
		local result = TGNS.IsPrimerOnlyClient(targetClient) and TGNS.IsPrimerOnlyClient(joiningClient)
		return result
	end
	
	local function ServerIsFull(playerList)
		local result = #playerList >= kDAKConfig.CommunitySlots.kMaximumSlots - kDAKConfig.CommunitySlots.kCommunitySlots
		return result
	end
	
	local function Log(message)
		table.insert(actionslog, message)
		EnhancedLog(message)
	end
	
	local function IsTargetBumpable(targetClient, playerList, joiningClient)
		local joinerIsStranger = TGNS.IsClientStranger(joiningClient)
		local targetIsSM = TGNS.IsClientSM(targetClient)
		local targetIsCommander = TGNS.IsClientCommander(targetClient)
		local targetIsProtectedStranger = IsTargetProtectedStranger(targetClient, playerList)
		local targetIsProtectedPrimerOnly = IsTargetProtectedPrimerOnly(targetClient, playerList)
		local targetAndJoiningArePrimerOnly = TargetAndJoiningArePrimerOnly(targetClient, joiningClient)
		local targetIsPrimerOnlyWhoIsProtectedDueToExcessStrangers = IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList)
		local targetIsNotYetConnectedEnoughToBeConsideredBumpable = not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, targetClient)
	
		if joinerIsStranger or targetIsSM or targetIsCommander or targetIsProtectedStranger or targetIsProtectedPrimerOnly or targetAndJoiningArePrimerOnly or targetIsNotYetConnectedEnoughToBeConsideredBumpable
		then
			return false
		end

		return true
	end
	
	local function FindVictimClient(joiningClient, playerList)
		local lowestBumpableScore = math.huge
		local predicate = function(targetClient, targetPlayer)
			if IsTargetBumpable(targetClient, playerList, joiningClient) then
				targetPlayer.score = targetPlayer.score == nil and 0 or targetPlayer.score
				if (targetPlayer.score <= lowestBumpableScore) then
					lowestBumpableScore = targetPlayer.score
					return true
				end
			end
			return false
		end
		local result = TGNS.GetLastMatchingClient(playerList, predicate)
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
		result.shortReport = string.format("T: %s%s J:%s%s ?:%s P:%s S:%s T:%s", result.targetIsSM, result.targetHasSignedPrimer, result.joinerIsSM, result.joinerHasSignedPrimer, result.strangerCount, result.primerOnlyCount, result.smCount, #playerList)
		return result
	end
	
	local function IncrementBumpCount(targetClient, bumpCounts)
		if TGNS.HasClientSignedPrimer(targetClient) then
			bumpCounts.primerOnly = TGNS.GetNumericValueOrZero(bumpCounts.primerOnly) + 1
		elseif TGNS.IsClientStranger(targetClient) then
			bumpCounts.stranger = TGNS.GetNumericValueOrZero(bumpCounts.stranger) + 1
		end
	end
	
	local function GetBumpMessage(targetClient)
		local result = string.format(kDAKConfig.CommunitySlots.kBumpReason, TGNS.GetClientName(targetClient), kDAKConfig.CommunitySlots.kMaximumSlots - kDAKConfig.CommunitySlots.kCommunitySlots, kDAKConfig.CommunitySlots.kMaximumSlots)
		return result
	end
	
	local function AnnounceClientBumpToStrangers(targetClient)
		local playerName = TGNS.GetClientName(targetClient)
		local strangerClients = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return TGNS.IsClientStranger(c) end)
		local strangerPlayers = TGNS.GetPlayers(strangerClients)
		TGNS.DoFor(strangerPlayers, function(p) TGNS.SendChatMessage(p, GetBumpMessage(targetClient)) end)
	end
	
	local function onPreVictimKick(targetClient, targetPlayer, joiningClient, playerList)
		Log(string.format("%s: Victim: %s (score: %s) Joining: %s", GetKickDetails(targetClient, joiningClient, playerList).shortReport, TGNS.GetClientNameSteamIdCombo(targetClient), tostring(targetPlayer.score), TGNS.GetClientNameSteamIdCombo(joiningClient)))
		IncrementBumpCount(targetClient, victimBumpCounts)
		AnnounceClientBumpToStrangers(targetClient)
	end

	local function onPreJoinerKick(targetClient, targetPlayer, playerList)
		Log(string.format("%s: Reject: %s", GetKickDetails(targetClient, targetClient, playerList).shortReport, TGNS.GetClientNameSteamIdCombo(targetClient)))
		IncrementBumpCount(targetClient, rejectBumpCounts)
		AnnounceClientBumpToStrangers(targetClient)
	end

	local function GetFullyConnectedPlayers(clientToExclude)
		local allPlayers = TGNS.GetPlayerList()
		local result = {}
		TGNS.DoFor(allPlayers, function(p)
			local client = TGNS.ClientAction(p, function(c) return c end)
			if client ~= clientToExclude and TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client) then
				table.insert(result, p)
			end
		end)
		return result
	end
	
	local function GetBumpSummary(playerList, bumpedClient, joinerOrVictim)
		local supportingMembersCount = #TGNS.GetSmClients(playerList)
		local primerOnlysCount = #TGNS.GetPrimerOnlyClients(playerList)
		local strangersCount = #TGNS.GetStrangersClients(playerList)
		local clientName = TGNS.GetClientName(bumpedClient)
		local communityDesignationCharacter = TGNS.GetClientCommunityDesignationCharacter(bumpedClient)
		local result = string.format("Kicking %s %s> %s with S:%s P:%s ?:%s", joinerOrVictim, communityDesignationCharacter, clientName, supportingMembersCount, primerOnlysCount, strangersCount)
		return result
	end

	local function IsClientBumped(client)
		local result = false
		local playerList = GetFullyConnectedPlayers(client)
		local nonSpecPlayers = TGNS.GetPlayers(TGNS.GetMatchingClients(playerList, function(c,p) return not TGNS.IsPlayerSpectator(p) end))
		if ServerIsFull(nonSpecPlayers) then
			local victimClient = FindVictimClient(client, nonSpecPlayers)
			if victimClient ~= nil then
				TGNS.SendAdminConsoles(GetBumpSummary(playerList, victimClient, "VICTIM"), "SLOTSDEBUG")
				TGNS.KickClient(victimClient, GetBumpMessage(victimClient), function(c,p) onPreVictimKick(c,p,client,playerList) end)
			else
				TGNS.SendAdminConsoles(GetBumpSummary(playerList, client, "JOINER"), "SLOTSDEBUG")
				TGNS.KickClient(client, GetBumpMessage(client), function(c,p) onPreJoinerKick(c,p,playerList) end)
				result = true
			end
		end
		if not result then
			table.insert(clientsWhoAreConnectedEnoughToBeConsideredBumpable, client)
		end
		return result
	end
	
	local function CommunitySlotsOnClientDelayedConnect(joiningClient)
		TGNS.SendAdminConsoles(string.format("SERVERJOINED: %s", TGNS.GetClientName(joiningClient)), "SLOTSDEBUG")
		local cancel = IsClientBumped(joiningClient)
		return cancel
	end
	local function CommunitySlotsOnClientDelayedConnectGreeter(client)
		local chatMessage
		if TGNS.IsClientSM(client) then
			chatMessage = "Supporting Member! Thank you! Your help makes our two servers possible!"
		elseif TGNS.HasClientSignedPrimer(client) then
			chatMessage = string.format("TGNS Primer signer! Join the full server when %s+ strangers are playing!", kDAKConfig.CommunitySlots.kMinimumStrangers)
		else
			chatMessage = "Welcome! Visit tacticalgamer.com/natural-selection to say hello!"
		end
		TGNS.ConsolePrint(client, chatMessage)
		TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, chatMessage) end)
	end
	DAKRegisterEventHook("kDAKOnClientDelayedConnect", CommunitySlotsOnClientDelayedConnect, VERY_HIGH_EVENT_HANDLER_PRIORITY)
	DAKRegisterEventHook("kDAKOnClientDelayedConnect", CommunitySlotsOnClientDelayedConnectGreeter, 5)
	
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
		TGNS.ConsolePrint(client, string.format("BUMP TOTALS SO FAR THIS MAP (%s):", bumpCounts.totalVictims + bumpCounts.totalRejects), MESSAGE_PREFIX)
		TGNS.ConsolePrint(client, string.format("Victims: %s (%s Primer Only; %s Stranger)", bumpCounts.totalVictims, bumpCounts.primerOnlyVictims, bumpCounts.strangerVictims), MESSAGE_PREFIX)
		TGNS.ConsolePrint(client, string.format("Rejects: %s (%s Primer Only; %s Stranger)", bumpCounts.totalRejects, bumpCounts.primerOnlyRejects, bumpCounts.strangerRejects), MESSAGE_PREFIX)
	end
	
	local function PrintBumpCountsChatMessages()
		local bumpCounts = GetBumpCounts()
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
				PrintBumpCountsReport(c)
				TGNS.PlayerAction(c, function(p)
						TGNS.SendChatMessage(p, string.format("Bump totals this map: %s Victims; %s Rejects", bumpCounts.totalVictims, bumpCounts.totalRejects))
					end
				)
			end
		)
	end
	DAKRegisterEventHook("kDAKOnGameEnd", function() TGNS.ScheduleAction(8, PrintBumpCountsChatMessages) end, 5)
	
	local function DebugCommunitySlots(client)
		TGNS.DoFor(actionslog, function(logline) 
				TGNS.ConsolePrint(client, logline, MESSAGE_PREFIX)
			end
		)
		PrintBumpCountsReport(client)
	end
	DAKCreateServerAdminCommand("Console_sv_csdebug", DebugCommunitySlots, "Will print Community Slots debug messages.")
	
	local function PrintPlayerSlotsStatuses(client)
		local playerList = TGNS.GetPlayerList()
		local smClients = TGNS.GetSmClients(playerList)
		local primerOnlyClients = TGNS.GetPrimerOnlyClients(playerList)
		local strangerClients = TGNS.GetStrangersClients(playerList)
		TGNS.DoFor(smClients, function(c) TGNS.ConsolePrint(client, string.format("Supporting Member: %s %s", TGNS.GetClientName(c), TGNS.HasClientSignedPrimer(c) and "(signed TGNS Primer)" or ""), MESSAGE_PREFIX) end)
		TGNS.DoFor(primerOnlyClients, function(c) TGNS.ConsolePrint(client, string.format("Primer Only: %s", TGNS.GetClientName(c)), MESSAGE_PREFIX) end)
		TGNS.DoFor(strangerClients, function(c) TGNS.ConsolePrint(client, string.format("Say Hello To: %s", TGNS.GetClientName(c)), MESSAGE_PREFIX) end)
		TGNS.ConsolePrint(client, string.format("S: %s | P: %s | ?: %s", #smClients, #primerOnlyClients, #strangerClients), MESSAGE_PREFIX)
		PrintBumpCountsReport(client)
	end
	DAKCreateServerAdminCommand("Console_sv_csinfo", PrintPlayerSlotsStatuses, "Print Community Slots bump counts and player statuses.", true)
	
	local function CommunitySlotsOnTeamJoin(self, player, newTeamNumber, force)
		TGNS.SendAdminConsoles(string.format("TEAMJOINING: %s", TGNS.GetPlayerName(player)), "SLOTSDEBUG")
		local joiningClient = TGNS.GetClient(player)
		local cancel = IsClientBumped(joiningClient)
		return cancel
	end
	DAKRegisterEventHook("kDAKOnTeamJoin", CommunitySlotsOnTeamJoin, 5)
end

Shared.Message("CommunitySlots Loading Complete")