local md

local Plugin = {}

function Plugin:SendVoicecommReminder(sourceClient, targetPlayer)
	if targetPlayer ~= nil then
		local targetPlayerTeamNumber = TGNS.GetPlayerTeamNumber(targetPlayer)
		local firstMessage = string.format("%s: %s, make sure you can respond to voicecomm.", TGNS.GetClientName(sourceClient), TGNS.GetPlayerName(targetPlayer))
		local secondMessage = "This server requires that from everyone. Press 'y' for team chat."
		local messageTargetDisplayer = function(player, message) md:ToPlayerNotifyColors(player, message, 240, 230, 130, 255, 0, 0) end 
		TGNS.DoFor(TGNS.GetPlayers(TGNS.GetTeamClients(targetPlayerTeamNumber)), function(p)
			if p == targetPlayer then
				messageTargetDisplayer(p, firstMessage)
				messageTargetDisplayer(p, secondMessage)
			else
				md:ToPlayerNotifyInfo(p, firstMessage)
				md:ToPlayerNotifyInfo(p, secondMessage)
			end
		end)
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