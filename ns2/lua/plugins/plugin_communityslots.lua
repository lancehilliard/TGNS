//TGNS Community Slots

if kDAKConfig and kDAKConfig.CommunitySlots then
	Script.Load("lua/TGNSCommon.lua")

	local actionslog = { }
	local clientsWhoAreConnectedEnoughToBeConsideredBumpable = {}
	local MESSAGE_PREFIX = "SLOTS"
	table.insert(actionslog, "COMMUNITY SLOTS DEBUG: ")
	local victimBumpCounts = {}
	local rejectBumpCounts = {}

	local function IsTargetProtectedStranger(targetClient, playerList)
		local result = TGNS.IsClientStranger(targetClient) and #TGNS.GetStrangersClients(playerList) <= kDAKConfig.CommunitySlots.kMinimumStrangers and #TGNS.GetPrimerOnlyClients(playerList) > 0
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
		local result = #playerList - 1 >= kDAKConfig.CommunitySlots.kMaximumSlots - kDAKConfig.CommunitySlots.kCommunitySlots
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
		local targetAndJoiningArePrimerOnly = TargetAndJoiningArePrimerOnly(targetClient, joiningClient)
		local targetIsPrimerOnlyWhoIsProtectedDueToExcessStrangers = IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList)
		local targetIsNotYetConnectedEnoughToBeConsideredBumpable = not TGNS.Has(clientsWhoAreConnectedEnoughToBeConsideredBumpable, targetClient)
	
		if joinerIsStranger or targetIsSM or targetIsCommander or targetIsProtectedStranger or targetAndJoiningArePrimerOnly or targetIsNotYetConnectedEnoughToBeConsideredBumpable
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
		result.shortReport = string.format("T: %s%s J:%s%s %s %s %s", result.targetIsSM, result.targetHasSignedPrimer, result.joinerIsSM, result.joinerHasSignedPrimer, result.strangerCount, result.primerOnlyCount, result.smCount)
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

	local function CommunitySlotsOnClientDelayedConnect(joiningClient)
		local playerList = TGNS.GetPlayerList()
		local nonSpecPlayers = TGNS.GetPlayers(TGNS.GetMatchingClients(playerList, function(c,p) return not TGNS.IsPlayerSpectator(p) end))
		if ServerIsFull(nonSpecPlayers) then
			local victimClient = FindVictimClient(joiningClient, nonSpecPlayers)
			if victimClient ~= nil then
				TGNS.KickClient(victimClient, GetBumpMessage(victimClient), function(c,p) onPreVictimKick(c,p,joiningClient,playerList) end)
				TGNS.SendAdminConsole(string.format("Kicking VICTIM %s with %s strangers present.", TGNS.GetClientName(victimClient), #TGNS.GetStrangersClients(playerList)), "SLOTSDEBUG")
				return true
			else
				//if TGNS.IsClientSM(joiningClient) then
				//	Log(string.format("No player kicked upon join of SM: ", TGNS.GetClientNameSteamIdCombo(joiningClient)))
				//else
					TGNS.KickClient(joiningClient, GetBumpMessage(joiningClient), function(c,p) onPreJoinerKick(c,p,playerList) end)
					TGNS.SendAdminConsole(string.format("Kicking JOINER %s with %s strangers present.", TGNS.GetClientName(joiningClient), #TGNS.GetStrangersClients(playerList)), "SLOTSDEBUG")
					return true
				//end
			end
		end
		table.insert(clientsWhoAreConnectedEnoughToBeConsideredBumpable, joiningClient)
	end
	local function CommunitySlotsOnClientDelayedConnectGreeter(client)
		local chatMessage
		if TGNS.IsClientSM(client) then
			chatMessage = "Supporting Member! Thank you! Join the full server anytime!"
		elseif TGNS.HasClientSignedPrimer(client) then
			chatMessage = string.format("TGNS Primer signer! Join the full server when %s+ strangers are playing!", kDAKConfig.CommunitySlots.kMinimumStrangers)
		else
			chatMessage = "Welcome! Visit tacticalgamer.com/natural-selection to say hello!"
		end
		TGNS.ConsolePrint(client, chatMessage)
		TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, chatMessage) end)
	end
	DAKRegisterEventHook("kDAKOnClientDelayedConnect", CommunitySlotsOnClientDelayedConnect, 5)
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
	
end

Shared.Message("CommunitySlots Loading Complete")