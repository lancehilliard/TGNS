local switchMd = TGNSMessageDisplayer.Create("SWITCH")
local swapMd = TGNSMessageDisplayer.Create("SWAP")
local tradeQueueClients = {}
local swapRequests = {}
local swapsPerformed = {}

local Plugin = {}

function Plugin:PlayerSay(client, networkMessage)
	local cancel = false
	local teamOnly = networkMessage.teamOnly
	local message = TGNS.ToLower(StringTrim(networkMessage.message))
	if TGNS.StartsWith(message, "swap ") or (message == "swap" or message == "'swap'") or (TGNS.ToLower(message) == "switch" or TGNS.ToLower(message) == "'switch'") then
		if not TGNS.IsGameInCountdown() and not TGNS.IsGameInProgress() and not (Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled()) then
			if TGNS.ToLower(message) == "switch" or TGNS.ToLower(message) == "'switch'" then
				local infoMessage, errorMessage
				local clientShouldBeRemovedFromQueue = function(c, t) return not (Shine:IsValidClient(c) and TGNS.GetClientTeamNumber(c) == t) end
				local teamNumber = TGNS.GetClientTeamNumber(client)
				local clientIsPlaying = TGNS.IsGameplayTeamNumber(teamNumber)
				if clientIsPlaying then
					if teamOnly then
						errorMessage = "Request automated team switching in all chat (not team chat)."
					else
						local player = TGNS.GetPlayer(client)
						local clientName = TGNS.GetClientName(client)
						local otherPlayingTeamNumber = TGNS.GetOtherPlayingTeamNumber(teamNumber)

						tradeQueueClients[teamNumber] = tradeQueueClients[teamNumber] or {}
						tradeQueueClients[otherPlayingTeamNumber] = tradeQueueClients[otherPlayingTeamNumber] or {}

						TGNS.RemoveAllWhere(tradeQueueClients[teamNumber], function(c) return clientShouldBeRemovedFromQueue(c, teamNumber) end)
						TGNS.RemoveAllWhere(tradeQueueClients[otherPlayingTeamNumber], function(c) return clientShouldBeRemovedFromQueue(c, otherPlayingTeamNumber) end)

						local clientIsAlreadyInQueue = TGNS.Has(tradeQueueClients[teamNumber], client)
						local clientTeamName = TGNS.GetClientTeamName(client)
						local otherTeamName = TGNS.GetOtherPlayingTeamName(clientTeamName)
						local otherClient = TGNS.FirstOrNil(tradeQueueClients[otherPlayingTeamNumber])

						if otherClient then
							local otherClientName = TGNS.GetClientName(otherClient)
							TGNS.ScheduleAction(0, function()
								switchMd:ToAllNotifyInfo(string.format("%s is now %s. %s is now %s.", clientName, otherTeamName, otherClientName, clientTeamName))
								TGNS.SendToTeam(TGNS.GetPlayer(client), otherPlayingTeamNumber, true)
								TGNS.SendToTeam(TGNS.GetPlayer(otherClient), teamNumber, true)
								if Shine.Plugins.timedstart then
									if Shine.Plugins.timedstart.GiveSecondsRemainingReprieve then
										Shine.Plugins.timedstart:GiveSecondsRemainingReprieve(30)
									end
								end
							end)
							TGNS.RemoveAllMatching(tradeQueueClients[otherPlayingTeamNumber], otherClient)
						else
							if clientIsAlreadyInQueue then
								TGNS.RemoveAllMatching(tradeQueueClients[teamNumber], client)
								infoMessage = string.format("%s will stay on %s for now ('switch' toggles).", clientName, clientTeamName)
							else
								TGNS.DoTeamSizeComparisonAction(player, TGNS.GetPlayerList(), function(playerTeamCount, otherTeamCount)
									playerCanSwitchWithoutPartner = playerTeamCount > otherTeamCount
								end)
								if playerCanSwitchWithoutPartner then
									local otherPlayingTeamNumber = TGNS.GetOtherPlayingTeamNumber(teamNumber)
									TGNS.SendToTeam(player, otherPlayingTeamNumber)
									infoMessage = string.format("%s is now %s.", clientName, TGNS.GetClientTeamName(client))
								else
									table.insert(tradeQueueClients[teamNumber], client)
									infoMessage = string.format("%s could play %s. %s, chat 'switch' if you want to switch to %s.", clientName, otherTeamName, otherTeamName, clientTeamName)
								end
							end
						end
					end
				else
					errorMessage = "You must start on either Marines or Aliens to request an automated team switch."
				end
				if errorMessage then
					switchMd:ToPlayerNotifyError(TGNS.GetPlayer(client), errorMessage)
					cancel = true
				end
				if infoMessage then
					TGNS.ScheduleAction(0, function()
						switchMd:ToAllNotifyInfo(infoMessage)
					end)
				end
			elseif TGNS.StartsWith(message, "swap ") and not teamOnly then
				local errorMessages = {}
				local marineClients
				local alienClients
				if TGNS.HasClientSignedPrimerWithGames(client) then
					if TGNS.EndsWith(message, "?") then
						local pendingSwapRequest = TGNS.FirstOrNil(swapRequests, function(swapRequest) return swapRequest.requestorClient == client  end)
				    	if pendingSwapRequest == nil then
				    		message = TGNS.Substring(message, 6)
							message = TGNS.Substring(message, 1, string.len(message) - 1)
							local playerCandidates = TGNS.Where(TGNS.Split(" ", message), TGNS.HasNonEmptyValue)
							local clients = {}
							TGNS.DoFor(playerCandidates, function(candidate)
								local player = TGNS.GetPlayerMatching(candidate)
								if player then
									local c = TGNS.GetClient(player)
									TGNS.InsertDistinctly(clients, c)
								else
									table.insert(errorMessages, string.format("'%s' matches no player.", candidate))
								end
							end)
							marineClients = TGNS.Where(clients, TGNS.ClientIsMarine)
							alienClients = TGNS.Where(clients, TGNS.ClientIsAlien)
							if #marineClients ~= 1 or #alienClients ~= 1 then
								table.insert(errorMessages, string.format("Matched players: %s", TGNS.Join(TGNS.Select(clients, function(c) return string.format("%s (%s)", TGNS.GetClientName(c), TGNS.GetClientTeamName(c)) end), ", ")))
								table.insert(errorMessages, "Swap requests must match one player from each team. Syntax example: swap wyz brian?")
							end
				    	else
				    		local pendingSwapRequestMarineClientName = Shine:IsValidClient(pendingSwapRequest.marineClient.c) and TGNS.GetClientName(pendingSwapRequest.marineClient.c) or "???"
				    		local pendingSwapRequestAlienClientName = Shine:IsValidClient(pendingSwapRequest.alienClient.c) and TGNS.GetClientName(pendingSwapRequest.alienClient.c) or "???"
				    		table.insert(errorMessages, string.format("You have already proposed a swap for this game (%s/%s).", pendingSwapRequestMarineClientName, pendingSwapRequestAlienClientName))
				    	end
					else
						table.insert(errorMessages, "Swap requests must end with a question mark. Syntax example: swap wyz brian?")
					end
				else
					table.insert(errorMessages, "Only Primer signers may request swaps.")
				end
				if #errorMessages == 0 then
					local marineClient = TGNS.GetFirst(marineClients)
					local alienClient = TGNS.GetFirst(alienClients)
					if Shine.Plugins.timedstart then
						if Shine.Plugins.timedstart.GiveSecondsRemainingReprieve then
							local bothClientsArePrimerSigners = TGNS.HasClientSignedPrimerWithGames(marineClient) and TGNS.HasClientSignedPrimerWithGames(alienClient)
							Shine.Plugins.timedstart:GiveSecondsRemainingReprieve(bothClientsArePrimerSigners and 30 or 45)
						end
					end
					local clientName = TGNS.GetClientName(client)
					local marineName = string.format("%s (to Aliens)", TGNS.GetClientName(marineClient))
					local alienName = string.format("%s (to Marines)", TGNS.GetClientName(alienClient))
					local notificationMessage = string.format("%s proposes swapping %s for %s (%s: chat 'swap' or 'stay').", clientName, marineName, alienName, marineClient == client and TGNS.GetClientName(alienClient) or (alienClient == client and TGNS.GetClientName(marineClient) or "other"))
		            TGNS.DoForReverse(swapRequests, function(swapRequest, i)
		            	local swapRequestClients = {swapRequest.marineClient.c, swapRequest.alienClient.c}
					    if TGNS.Has(swapRequestClients, marineClient) or TGNS.Has(swapRequestClients, alienClient) then
					    	table.remove(swapRequests, i)
					    end
					end)
					local swapRequest = {}
					swapRequest.marineClient = {c=marineClient,a=marineClient == client}
					swapRequest.alienClient = {c=alienClient,a=alienClient == client}
					swapRequest.requestorClient = client
					table.insert(swapRequests, swapRequest)
					TGNS.ScheduleAction(0, function() swapMd:ToAllNotifyInfo(notificationMessage) end)
				else
					TGNS.DoFor(errorMessages, function(errorMessage)
						swapMd:ToPlayerNotifyError(TGNS.GetPlayer(client), errorMessage)
					end)
					cancel = true
				end
			elseif message == "swap" or message == "'swap'" then
				local swapPartnerClient
				local clientOptedOut
				if TGNS.ClientIsOnPlayingTeam(client) then
					TGNS.DoFor(swapRequests, function(swapRequest)
						if swapRequest.marineClient.c == client and TGNS.ClientIsMarine(client) then
							if swapRequest.marineClient.a then
								swapRequest.marineClient.a = false
								clientOptedOut = true
							else
								swapRequest.marineClient.a = true
								swapPartnerClient = swapRequest.alienClient.c
							end							
						elseif swapRequest.alienClient.c == client and TGNS.ClientIsAlien(client) then
							if swapRequest.alienClient.a then
								swapRequest.alienClient.a = false
								clientOptedOut = true
							else
								swapRequest.alienClient.a = true
								swapPartnerClient = swapRequest.marineClient.c
							end
						end
					end)
					if swapPartnerClient then
						local notificationMessage = string.format("%s is willing to swap with %s (chat 'swap' or 'stay').", TGNS.GetClientName(client), TGNS.GetClientName(swapPartnerClient))
						TGNS.DoForReverse(swapRequests, function(swapRequest, i)
							if (swapRequest.marineClient.a or (false and TGNS.GetIsClientVirtual(swapRequest.marineClient.c))) and (swapRequest.alienClient.a or (false and TGNS.GetIsClientVirtual(swapRequest.alienClient.c))) and TGNS.ClientIsMarine(swapRequest.marineClient.c) and TGNS.ClientIsAlien(swapRequest.alienClient.c) then
								table.remove(swapRequests, i)
								TGNS.RemoveAllMatching(tradeQueueClients[kMarineTeamType], swapRequest.marineClient.c)
								TGNS.SendToTeam(TGNS.GetPlayer(swapRequest.marineClient.c), kAlienTeamType)
								TGNS.RemoveAllMatching(tradeQueueClients[kAlienTeamType], swapRequest.alienClient.c)
								TGNS.SendToTeam(TGNS.GetPlayer(swapRequest.alienClient.c), kMarineTeamType)
								local swapPerformed = {}
								if Shine:IsValidClient(swapRequest.requestorClient) then
									swapPerformed.requestorSteamId = TGNS.GetClientSteamId(swapRequest.requestorClient)
								end
								swapPerformed.marineSteamId = TGNS.GetClientSteamId(swapRequest.marineClient.c)
								swapPerformed.alienSteamId = TGNS.GetClientSteamId(swapRequest.alienClient.c)
								table.insert(swapsPerformed, swapPerformed)
								notificationMessage = string.format("%s accepted %s. %s accepted %s.%s", TGNS.GetClientName(swapRequest.alienClient.c), TGNS.GetClientTeamName(swapRequest.alienClient.c), TGNS.GetClientName(swapRequest.marineClient.c), TGNS.GetClientTeamName(swapRequest.marineClient.c), Shine:IsValidClient(swapRequest.requestorClient) and string.format(" Requestor: %s", TGNS.GetClientName(swapRequest.requestorClient)) or "")
								if Shine.Plugins.timedstart then
									if Shine.Plugins.timedstart.GiveSecondsRemainingReprieve then
										local bothClientsArePrimerSigners = TGNS.HasClientSignedPrimerWithGames(swapRequest.marineClient.c) and TGNS.HasClientSignedPrimerWithGames(swapRequest.alienClient.c)
										Shine.Plugins.timedstart:GiveSecondsRemainingReprieve(bothClientsArePrimerSigners and 30 or 45)
									end
								end
								return true
							end
						end)
						TGNS.ScheduleAction(0, function()
							swapMd:ToAllNotifyInfo(notificationMessage)
						end)
					else
						if clientOptedOut then
							local clientName = TGNS.GetClientName(client)
							local clientTeamName = TGNS.GetClientTeamName(client)
							TGNS.ScheduleAction(0, function()
								swapMd:ToAllNotifyInfo(string.format("%s will stay on %s for now ('swap' toggles).", TGNS.GetClientName(client), clientTeamName))
							end)
						else
							swapMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "No pending swap requests found for you.")
							swapMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "You can request specific players to switch! Chat syntax example: swap wyz brian?")
							cancel = true
						end
					end
				else
					swapMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "You must be on a team to automate swaps.")
					cancel = true
				end
			end
		else
			local captainsModeEnabled = Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled()
			swapMd:ToPlayerNotifyError(TGNS.GetPlayer(client), string.format("Swaps are not automated during %sgameplay.", captainsModeEnabled and "Captains " or ""))
			cancel = true
		end
	end
	if TGNS.IsGameWaitingToStart() and TGNS.ClientIsOnPlayingTeam(client) and (message == "stay" or message == "'stay'") then
		local swapPartnerClient
		TGNS.DoForReverse(swapRequests, function(swapRequest, index)
			if swapRequest.marineClient.c == client and TGNS.ClientIsMarine(client) then
				swapPartnerClient = swapRequest.alienClient.c
			elseif swapRequest.alienClient.c == client and TGNS.ClientIsAlien(client) then
				swapPartnerClient = swapRequest.marineClient.c
			end
			if swapPartnerClient then
				table.remove(swapRequests, index)
			end
		end)
		if swapPartnerClient then
			local notificationMessage = string.format("%s stays. Swap request cleared.", TGNS.GetClientName(client))
			TGNS.ScheduleAction(0, function()
				swapMd:ToAllNotifyInfo(notificationMessage)
				if Shine.Plugins.timedstart then
					if Shine.Plugins.timedstart.GiveSecondsRemainingReprieve then
						Shine.Plugins.timedstart:GiveSecondsRemainingReprieve(30)
					end
				end
			end)
		else
			swapMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "No pending swap requests found for you.")
			swapMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "You can request specific players to switch! Chat syntax example: swap wyz brian?")
			cancel = true
		end
	end
    if cancel then
        return ""
    end
end

local function removeSwitchAndSwapForClient(client)
	tradeQueueClients[kMarineTeamType] = tradeQueueClients[kMarineTeamType] or {}
	tradeQueueClients[kAlienTeamType] = tradeQueueClients[kAlienTeamType] or {}
	local switchRequestRemoved = false
	if TGNS.Has(tradeQueueClients[kMarineTeamType], client) then
		TGNS.RemoveAllMatching(tradeQueueClients[kMarineTeamType], client)
		switchRequestRemoved = true
	end
	if TGNS.Has(tradeQueueClients[kAlienTeamType], client) then
		TGNS.RemoveAllMatching(tradeQueueClients[kAlienTeamType], client)
		switchRequestRemoved = true
	end
	if switchRequestRemoved then
		TGNS.ScheduleAction(0, function()
			if Shine:IsValidClient(client) then
				switchMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "You are no longer in the 'switch' queue.")
			end
		end)
	end

	local swapRequestRemoved = false
    TGNS.DoForReverse(swapRequests, function(swapRequest, i)
	    if TGNS.Has({swapRequest.marineClient.c, swapRequest.alienClient.c}, client) then
	    	table.remove(swapRequests, i)
	    	swapRequestRemoved = true
	    end
	end)
	if swapRequestRemoved then
		local clientName = Shine:IsValidClient(client) and TGNS.GetClientName(client)
		TGNS.ScheduleAction(0, function()
			if clientName then
		    	swapMd:ToAllNotifyInfo(string.format("%s %s. Swap request cleared.", clientName, Shine:IsValidClient(client) and "team change" or "disconnected"))
			end
		end)
	end
end

function Plugin:ClientDisconnect(client)
	removeSwitchAndSwapForClient(client)
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if TGNS.IsGameplayTeamNumber(oldTeamNumber) then
		local client = TGNS.GetClient(player)
		removeSwitchAndSwapForClient(client)
	end
	if TGNS.IsGameplayTeamNumber(oldTeamNumber) or TGNS.IsGameplayTeamNumber(newTeamNumber) then
		if Shine.Plugins.timedstart then
			if Shine.Plugins.timedstart.GiveSecondsRemainingReprieve then
				Shine.Plugins.timedstart:GiveSecondsRemainingReprieve(30)
			end
		end
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	if TGNS.ConvertSecondsToMinutes(TGNS.GetCurrentGameDurationInSeconds()) > 25 then
		TGNS.DoFor(swapsPerformed, function(swapPerformed)
			if swapPerformed.requestorSteamId then
				TGNS.Karma(swapPerformed.requestorSteamId, "HelpfulSwapRequest")
			end
			TGNS.Karma(swapPerformed.marineSteamId, "HelpfulSwapAcceptance")
			TGNS.Karma(swapPerformed.alienSteamId, "HelpfulSwapAcceptance")
		end)
	end
	swapsPerformed = {}
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
		swapRequests = {}
	end)
end

function Plugin:Initialise()
    self.Enabled = true

	TGNS.RegisterEventHook("GameCountdownStarted", function(secondsSinceEpoch)
		tradeQueueClients = {}
		swapRequests = {}
	end)


    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("teamswitch", Plugin )