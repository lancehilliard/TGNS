//TGNS Community Slots

if kDAKConfig and kDAKConfig.CommunitySlots then
	Script.Load("lua/TGNSCommon.lua")

	local actionslog = { }
	table.insert(actionslog, "COMMUNITY SLOTS DEBUG: ")
	local victimBumpCounts = {}
	local rejectBumpCounts = {}

	local function IsTargetProtectedStranger(targetClient, playerList)
		local result = TGNS:IsClientStranger(targetClient) and #TGNS:GetStrangersClients(playerList) <= kDAKConfig.CommunitySlots.kMinimumStrangers and #TGNS:GetPrimerOnlyClients(playerList) > 0
		return result
	end
	
	local function IsPrimerOnlyTargetProtectedDueToExcessStrangers(targetClient, playerList)
		local result = TGNS:IsPrimerOnlyClient(targetClient) and #TGNS:GetStrangersClients(playerList) > kDAKConfig.CommunitySlots.kMinimumStrangers
		return result
	end
	
	local function TargetAndJoiningArePrimerOnly(targetClient, joiningClient)
		local result = TGNS:IsPrimerOnlyClient(targetClient) and TGNS:IsPrimerOnlyClient(joiningClient)
		return result
	end
	
	local function ServerIsFull()
		local playerCount = TGNS:GetPlayerCount() - 1
		local result = playerCount >= kDAKConfig.CommunitySlots.kMaximumSlots - kDAKConfig.CommunitySlots.kCommunitySlots
		return result
	end
	
	local function Log(message)
		table.insert(actionslog, message)
		EnhancedLog(message)
	end
	
	local function IsTargetBumpable(targetClient, playerList, joiningClient)
		local joinerIsStranger = TGNS:IsClientStranger(joiningClient)
		local targetIsSM = TGNS:IsClientSM(targetClient)
		local targetIsCommander = TGNS:IsClientCommander(targetClient)
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
		local result = TGNS:GetLastMatchingClient(predicate, playerList)
		return result
	end
	
	local function GetKickDetails(targetClient, joiningClient, playerList)
		local result = {}
		result.targetIsSM = TGNS:IsClientSM(targetClient) and "Y" or "N"
		result.targetHasSignedPrimer = TGNS:HasClientSignedPrimer(targetClient) and "Y" or "N"
		result.joinerIsSM = TGNS:IsClientSM(joiningClient) and "Y" or "N"
		result.joinerHasSignedPrimer = TGNS:IsClientSM(joiningClient) and "Y" or "N"
		result.strangerCount = #TGNS:GetStrangersClients(playerList)
		result.primerOnlyCount = #TGNS:GetPrimerOnlyClients(playerList)
		result.smCount = #TGNS:GetSmClients(playerList)
		result.shortReport = string.format("T: %s%s J:%s%s %s %s %s", result.targetIsSM, result.targetHasSignedPrimer, result.joinerIsSM, result.joinerHasSignedPrimer, result.strangerCount, result.primerOnlyCount, result.smCount)
		return result
	end
	
	local function IncrementBumpCount(targetClient, kickCounts)
		if TGNS:HasClientSignedPrimer(targetClient) then
			kickCounts.primerOnly = TGNS:GetCountOrZero(kickCounts.primerOnly) + 1
		elseif TGNS:IsClientStranger(targetClient) then
			kickCounts.stranger = TGNS:GetCountOrZero(kickCounts.stranger) + 1
		end
	end
	
	local function onPreVictimKick(targetClient, targetPlayer, joiningClient, playerList)
		Log(string.format("%s: Victim: %s (score: %s) Joining: %s", GetKickDetails(targetClient, joiningClient, playerList).shortReport, TGNS:GetClientNameSteamIdCombo(targetClient), tostring(targetPlayer.score), TGNS:GetClientNameSteamIdCombo(joiningClient)))
		IncrementBumpCount(victimBumpCounts)
	end

	local function onPreJoinerKick(targetClient, targetPlayer, playerList)
		Log(string.format("%s: Reject: %s", GetKickDetails(targetClient, targetClient, playerList).shortReport, TGNS:GetClientNameSteamIdCombo(targetClient)))
		IncrementBumpCount(rejectBumpCounts)
	end

	local function CommunitySlotsOnClientDelayedConnect(joiningClient)
		local playerList = TGNS:GetPlayerList()
		if ServerIsFull() then
			local victimClient = FindVictimClient(joiningClient, playerList)
			if victimClient ~= nil then
				TGNS:KickClient(victimClient, kDAKConfig.CommunitySlots.kKickedForRoom, kDAKConfig.CommunitySlots.kKickedDisconnectReason, function(c,p) onPreVictimKick(c,p,joiningClient,playerList) end)
			else
				if TGNS:IsClientSM(joiningClient) then
					Log(string.format("No player kicked upon join of SM: ", TGNS:GetClientNameSteamIdCombo(joiningClient)))
				else
					TGNS:KickClient(joiningClient, kDAKConfig.CommunitySlots.kServerFull, kDAKConfig.CommunitySlots.kServerFullDisconnectReason, function(c,p) onPreJoinerKick(c,p,playerList) end)
					return false
				end
			end
		end
		return true		
	end
	local function CommunitySlotsOnClientDelayedConnectGreeter(client)
		local chatMessage
		if TGNS:IsClientSM(client) then
			chatMessage = "Welcome back! You have a reserved slot at all times. Thank you for your Supporting Membership!"
		elseif TGNS:HasClientSignedPrimer(client) then
			chatMessage = string.format("Welcome back! You have a reserved slot when %s+ strangers are playing. Thank you for signing the TGNS Primer!", kDAKConfig.CommunitySlots.kMinimumStrangers)
		else
			chatMessage = "Welcome to TGNS! Visit tacticalgamer.com/natural-selection to learn how to get a reserved slot!"
		end
		TGNS:ConsolePrint(client, chatMessage)
	end
	table.insert(kDAKOnClientDelayedConnect, function(client) return CommunitySlotsOnClientDelayedConnect(client) end)
	table.insert(kDAKOnClientDelayedConnect, function(client) return CommunitySlotsOnClientDelayedConnectGreeter(client) end)
	
	local function PrintKickCountsReport(client)
		local primerOnlyVictims = TGNS:GetCountOrZero(victimBumpCounts.primerOnly)
		local strangerVictims = TGNS:GetCountOrZero(victimBumpCounts.stranger)
		local primerOnlyRejects = TGNS:GetCountOrZero(rejectBumpCounts.primerOnly)
		local strangerRejects = TGNS:GetCountOrZero(rejectBumpCounts.stranger) 
		local totalVictims = primerOnlyVictims + strangerVictims
		local totalRejects = primerOnlyRejects + strangerRejects
		TGNS:ConsolePrint(client, "BUMP COUNTS:", "CSDEBUG")
		TGNS:ConsolePrint(client, string.format("Victims: %s (%s Primer Only; %s Stranger)", totalVictims, primerOnlyVictims, strangerVictims), "CSDEBUG")
		TGNS:ConsolePrint(client, string.format("Rejects: %s (%s Primer Only; %s Stranger)", totalRejects, primerOnlyRejects, strangerRejects), "CSDEBUG")
	end
	
	local function DebugCommunitySlots(client)
		for r = 1, #actionslog, 1 do
			if actionslog[r] ~= nil then
				TGNS:ConsolePrint(client, actionslog[r], "CSDEBUG")
			end
		end
		PrintKickCountsReport(client)
	end
	DAKCreateServerAdminCommand("Console_sv_csdebug", DebugCommunitySlots, "Will print Community Slots debug messages.")
	
end

Shared.Message("CommunitySlots Loading Complete")