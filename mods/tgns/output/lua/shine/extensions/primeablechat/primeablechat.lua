if Server or Client then
	local Plugin = {}

	local OnClientInitialise = function(self) end
	local OnServerInitialise = function(self) end

	if Client then
		OnClientInitialise = function(self)
		end
	end

	if Server then
		local md = TGNSMessageDisplayer.Create("POWER")
		local lastChatWhen = {}
		local hasSeenFirstChat = {}

		OnServerInitialise = function(self)
			local originalPowerPointOnUse = PowerPoint.OnUse
			PowerPoint.OnUse = function(powerPointSelf, player, elapsedTime, useSuccessTable)
				originalPowerPointOnUse(powerPointSelf, player, elapsedTime, useSuccessTable)
				if (not powerPointSelf:GetIsBuilt()) and powerPointSelf.buildFraction == 1  and powerPointSelf.CanBeCompletedByScriptActor and not powerPointSelf:CanBeCompletedByScriptActor(player) then
					if player:isa("Marine") then
						local client = TGNS.GetClient(player)
						if client then
							lastChatWhen[client] = lastChatWhen[client] or {}
							if ((lastChatWhen[client][powerPointSelf] and Shared.GetTime() - lastChatWhen[client][powerPointSelf] > 0.5) or (hasSeenFirstChat[client] == nil)) and ((Balance.GetTotalGamesPlayed(client) < 20) or (not TGNS.IsProduction())) then
								local locationName = TGNS.GetPlayerLocationName(player)
								local chatMessage = "Power primed! :) Build other structures before finishing this power node."
								local teamNumber = TGNS.GetClientTeamNumber(client)
								local clientName = TGNS.GetClientName(client)
								local message = string.format("%s: %s", clientName, chatMessage)
								local playersToShowMessageTo = {player}
								if lastChatWhen[client][powerPointSelf] and Shared.GetTime() - lastChatWhen[client][powerPointSelf] > 2 then
									playersToShowMessageTo = TGNS.GetPlayersOnSameTeam(player)
								end
								TGNS.DoFor(playersToShowMessageTo, function(p)
									Shine:NotifyDualColour(p, 55, 143, 255, string.format("[POWER%s]", TGNS.HasNonEmptyValue(locationName) and string.format("-%s", locationName) or ""), 255, 255, 255, message)
								end)
								hasSeenFirstChat[client] = true
							end
							lastChatWhen[client][powerPointSelf] = Shared.GetTime()
						end
					end
				end
			end
		end
	end

	function Plugin:Initialise()
		self.Enabled = true
		if Client then OnClientInitialise(Plugin) end
		if Server then OnServerInitialise(Plugin) end
		return true
	end

	function Plugin:Cleanup()
	    --Cleanup your extra stuff like timers, data etc.
	    self.BaseClass.Cleanup( self )
	end

	Shine:RegisterExtension("primeablechat", Plugin )
end