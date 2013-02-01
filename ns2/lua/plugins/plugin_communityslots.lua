//TGNS Community Slots

if kDAKConfig and kDAKConfig.CommunitySlots then
	Script.Load("lua/TGNSCommon.lua")

	local actionslog = { }
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
	
		if joinerIsStranger or targetIsSM or targetIsCommander or targetIsProtectedStranger or targetAndJoiningArePrimerOnly
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
			else
				if TGNS.IsClientSM(joiningClient) then
					Log(string.format("No player kicked upon join of SM: ", TGNS.GetClientNameSteamIdCombo(joiningClient)))
				else
					TGNS.KickClient(joiningClient, GetBumpMessage(joiningClient), function(c,p) onPreJoinerKick(c,p,playerList) end)
					return true
				end
			end
		end
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
		local result.primerOnlyVictims = TGNS.GetNumericValueOrZero(victimBumpCounts.primerOnly)
		local result.strangerVictims = TGNS.GetNumericValueOrZero(victimBumpCounts.stranger)
		local result.primerOnlyRejects = TGNS.GetNumericValueOrZero(rejectBumpCounts.primerOnly)
		local result.strangerRejects = TGNS.GetNumericValueOrZero(rejectBumpCounts.stranger) 
		local result.totalVictims = primerOnlyVictims + strangerVictims
		local result.totalRejects = primerOnlyRejects + strangerRejects
		return result
	end
	
//	local function PrintBumpCountsToAdmins()
//		TGNS.DoForClientsWithId(TGNS.GetMatchingClients(TGNS.IsClientAdmin), function(c)
//				
//			end
//		)
//		for i = 1, kWinOrLoseTeamCount do
//			kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
//			kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
//			kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
//		end
//		kTimeAtWhichWinOrLoseVoteSucceeded = 0
//	end
//	DAKRegisterEventHook("kDAKOnGameEnd", PrintBumpCountsToAdmins, 5)

	local function PrintBumpCountsReport(client)
		local bumpCounts = GetBumpCounts()
		TGNS.ConsolePrint(client, string.format("BUMP COUNTS (%s):", bumpCounts.totalVictims + bumpCounts.totalRejects), "CSDEBUG")
		TGNS.ConsolePrint(client, string.format("Victims: %s (%s Primer Only; %s Stranger)", bumpCounts.totalVictims, bumpCounts.primerOnlyVictims, bumpCounts.strangerVictims), "CSDEBUG")
		TGNS.ConsolePrint(client, string.format("Rejects: %s (%s Primer Only; %s Stranger)", bumpCounts.totalRejects, bumpCounts.primerOnlyRejects, bumpCounts.strangerRejects), "CSDEBUG")
	end
	
	local function DebugCommunitySlots(client)
		TGNS.DoFor(actionslog, function(logline) 
				TGNS.ConsolePrint(client, logline, "CSDEBUG")
			end
		)
		PrintBumpCountsReport(client)
	end
	DAKCreateServerAdminCommand("Console_sv_csdebug", DebugCommunitySlots, "Will print Community Slots debug messages.")
	
	//local function PrintPlayerSlotsStatuses(client)
	//	local playerList = TGNS.GetPlayerList()
	//	local strangerClients = TGNS.GetStrangersClients(playerList)
	//	local primerOnlyClients = TGNS.IsPrimerOnlyClient(playerList)
	//	local smClients = TGNS.GetSmClients(playerList)
	//	
	//	PrintBumpCountsReport(client)
	//end
	//DAKCreateServerAdminCommand("Console_sv_cswho", PrintPlayerSlotsStatuses, "Will print slots status for all players.")
	
end

Shared.Message("CommunitySlots Loading Complete")