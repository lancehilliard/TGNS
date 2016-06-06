local md = TGNSMessageDisplayer.Create("SWITCH")
local tradeQueueClients = {}

local Plugin = {}

function Plugin:PlayerSay(client, networkMessage)
	local infoMessage, errorMessage
	local teamOnly = networkMessage.teamOnly
	local message = StringTrim(networkMessage.message)
	local clientShouldBeRemovedFromQueue = function(c, t) return not (Shine:IsValidClient(c) and TGNS.GetClientTeamNumber(c) == t) end
	local isTrade = TGNS.ToLower(message) == "switch" or TGNS.ToLower(message) == "'switch'"
	if isTrade then
		local teamNumber = TGNS.GetClientTeamNumber(client)
		local clientIsPlaying = TGNS.IsGameplayTeamNumber(teamNumber)
		if TGNS.IsGameInCountdown() or TGNS.IsGameInProgress() or (Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled()) then
			local captainsModeEnabled = Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled()
			errorMessage = string.format("Team switching is not automated during %sgameplay.", captainsModeEnabled and "Captains " or "")
		else
			if clientIsPlaying then
				if teamOnly then
					errorMessage = "Request automated team switching in all chat (not team chat)."
				else
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
							md:ToAllNotifyInfo(string.format("%s is now %s. %s is now %s.", clientName, otherTeamName, otherClientName, clientTeamName))
							TGNS.SendToTeam(TGNS.GetPlayer(client), otherPlayingTeamNumber, true)
							TGNS.SendToTeam(TGNS.GetPlayer(otherClient), teamNumber, true)
						end)
						TGNS.RemoveAllMatching(tradeQueueClients[otherPlayingTeamNumber], otherClient)
					else
						if clientIsAlreadyInQueue then
							TGNS.RemoveAllMatching(tradeQueueClients[teamNumber], client)
							infoMessage = string.format("%s will stay on %s for now.", clientName, clientTeamName)
						else
							table.insert(tradeQueueClients[teamNumber], client)
							infoMessage = string.format("%s could play %s. %s, chat 'switch' if you want to switch to %s.", clientName, otherTeamName, otherTeamName, clientTeamName)
						end
					end
				end
			else
				errorMessage = "You must start on either Marines or Aliens to request an automated team switch."
			end
		end
	end
	if errorMessage then
		md:ToPlayerNotifyError(TGNS.GetPlayer(client), errorMessage)
		return ""
	end
	if infoMessage then
		TGNS.ScheduleAction(0, function()
			md:ToAllNotifyInfo(infoMessage)
		end)
	end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if TGNS.IsGameplayTeamNumber(oldTeamNumber) then
		tradeQueueClients[oldTeamNumber] = tradeQueueClients[oldTeamNumber] or {}
		local client = TGNS.GetClient(player)
		if TGNS.Has(tradeQueueClients[oldTeamNumber], client) then
			TGNS.RemoveAllMatching(tradeQueueClients[oldTeamNumber], client)
			md:ToPlayerNotifyInfo(player, string.format("You are no longer in the %s 'switch' queue.", TGNS.GetTeamName(oldTeamNumber)))
		end
	end
end

function Plugin:Initialise()
    self.Enabled = true

	TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
		tradeQueueClients = {}
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("teamswitch", Plugin )