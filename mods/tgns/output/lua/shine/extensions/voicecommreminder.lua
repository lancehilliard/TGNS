local md
local reminderLastSentWhen = {}

local Plugin = {}

function Plugin:SendVoicecommReminder(sourceClient, targetPlayer)
	if targetPlayer ~= nil then
		local targetClient = TGNS.GetClient(targetPlayer)
		local sourcePlayer = TGNS.GetPlayer(sourceClient)
		if Shared.GetTime() - (reminderLastSentWhen[targetClient] or 0) > 5 then
			local targetPlayerTeamNumber = TGNS.GetPlayerTeamNumber(targetPlayer)
			local firstMessage = string.format("%s: %s, respond to voicecomm (mic optional).", TGNS.GetClientName(sourceClient), TGNS.GetPlayerName(targetPlayer))
			local secondMessage = "This server requires teamplay. Need chat? Keybind: y"
			local messageTargetDisplayer = function(player, message) md:ToPlayerNotifyColors(player, message, 240, 230, 130, 255, 0, 0) end 
			TGNS.DoFor(TGNS.GetPlayers(TGNS.GetTeamClients(targetPlayerTeamNumber)), function(p)
				if p == targetPlayer then
					messageTargetDisplayer(p, firstMessage)
					messageTargetDisplayer(p, secondMessage)
				else
					md:ToPlayerNotifyInfo(p, firstMessage)
					md:ToPlayerNotifyInfo(p, secondMessage)
					local c = TGNS.GetClient(p)
					TGNS.ScheduleAction(22, function()
						if Shine:IsValidClient(sourceClient) and Shine:IsValidClient(targetClient) and Shine:IsValidClient(c) and TGNS.ClientsAreTeammates(sourceClient, targetClient) and TGNS.ClientsAreTeammates(sourceClient, c) and not Shine.Plugins.scoreboard:IsVouched(targetClient) then
							local tp = TGNS.GetPlayer(targetClient)
							md:ToPlayerNotifyYellow(TGNS.GetPlayer(c), string.format("%s: Vouch %s (^) or: sh_vrkick %s (chat: !vrkick %s)", TGNS.GetClientName(sourceClient), TGNS.GetPlayerName(tp), TGNS.GetPlayerGameId(tp), TGNS.GetPlayerGameId(tp)))
						end
					end)
				end
			end)
			reminderLastSentWhen[targetClient] = Shared.GetTime()
		else
			md:ToPlayerNotifyError(sourcePlayer, string.format("%s was too recently shown a voicecomm reminder by another player.", TGNS.GetPlayerName(targetPlayer)))
		end
	end
end

function Plugin:CreateCommands()
	local remindercommand = self:BindCommand( "sh_vr", "vr", function(client, playerPredicate)
		local player = TGNS.GetPlayer(client)
		if playerPredicate == nil or playerPredicate == "" then
			md:ToPlayerNotifyError(player, "You must specify a player.")
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
			if targetPlayer ~= nil then
				self:SendVoicecommReminder(client, targetPlayer)
			else
				md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
			end
		end
	end, true)
	remindercommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	remindercommand:Help( "<player> Remind player of requirement to respond to voicecomm." )

	local removeCommand = self:BindCommand( "sh_vrkick", "vrkick", function(client, playerPredicate)
		local player = TGNS.GetPlayer(client)
		if playerPredicate == nil or playerPredicate == "" then
			md:ToPlayerNotifyError(player, "You must specify a player.")
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
			if targetPlayer ~= nil then
				if TGNS.IsPlayerStranger(targetPlayer) or TGNS.IsClientAdmin(client) then
					local targetClient = TGNS.GetClient(targetPlayer)
					if Shared.GetTime() - (reminderLastSentWhen[targetClient] or 0) < 40 then
						local targetClientName = TGNS.GetClientName(targetClient)
						local targetClientTeamNumber = TGNS.GetClientTeamNumber(targetClient)
						TGNSClientKicker.Kick(targetClient, "Cannot hear voicecomm. Reconnect and respond to voicecomm (mic optional).", nil, nil, true)
						TGNS.DoFor(TGNS.GetClientList(function(c) return TGNS.GetClientTeamNumber(c) == targetClientTeamNumber or TGNS.IsClientAdmin(c) end), function(c)
							md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), string.format("%s sh_vrkick -> %s. Details in console.", TGNS.GetClientName(client), targetClientName))
							md:ToClientConsole(c, string.format("%s executed sh_vrkick against %s after they didn't respond to voicecomm.", TGNS.GetClientName(client), targetClientName))
							md:ToClientConsole(c, string.format("If this was sh_vrkick abuse, click %s on the scoreboard and choose 'Admin Feedback'.", TGNS.GetClientName(client)))
						end)
					else
						md:ToPlayerNotifyError(player, string.format("You have not shown %s the voicecomm reminder in the last 30 seconds.", TGNS.GetClientName(targetClient)))
					end
				else
					md:ToPlayerNotifyError(player, string.format("%s is not a Stranger.", TGNS.GetPlayerName(targetPlayer)))
				end
			else
				md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
			end
		end
	end)
	removeCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	removeCommand:Help( "<player> Remove player who cannot hear voicecomm." )
end

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create()
    self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("voicecommreminder", Plugin )