local md

local Plugin = {}

function Plugin:CreateCommands()
	local remindercommand = self:BindCommand( "sh_vr", "vr", function(client, playerPredicate)
		local player = TGNS.GetPlayer(client)
	if playerPredicate == nil or playerPredicate == "" then
		md:ToPlayerNotifyError(player, "You must specify a player.")
	else
		local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
		if targetPlayer ~= nil then
			md:ToTeamNotifyInfo(TGNS.GetPlayerTeamNumber(targetPlayer), string.format("%s: %s, make sure you can respond to voicecomm.", TGNS.GetClientName(client), TGNS.GetPlayerName(targetPlayer)))
			md:ToTeamNotifyInfo(TGNS.GetPlayerTeamNumber(targetPlayer), "This server requires that from everyone. Press 'y' for team chat.")
		else
			md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
		end
	end
	end)
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