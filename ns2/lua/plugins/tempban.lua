Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSMessageDisplayer.lua")
Script.Load("lua/TGNSClientKicker.lua")

local tempbanMessageDisplayer = TGNSMessageDisplayer.Create("TEMPBAN")

local TEMPBAN_DURATION_IN_MINUTES = 15

local function ShowUsage(client)
	tempbanMessageDisplayer:ToClientConsole(client, "Usage: sv_tempban <player> <reason>")
end

local function svTempBan(client, playerName, ...)
	if TGNS.IsClientAdmin(client) or TGNS.IsClientTempAdmin(client) then
		local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local reason = TGNS.GetConcatenatedStringOrEmpty(...)
			if reason == "" then
				tempbanMessageDisplayer:ToClientConsole(client, string.format("You must specify a reason to tempban '%s'.", TGNS.GetPlayerName(targetPlayer)))
				ShowUsage(client)
			else
				local targetClient = TGNS.GetClient(targetPlayer)
				TGNS.Ban(targetClient, TEMPBAN_DURATION_IN_MINUTES, reason)
				TGNSClientKicker.Kick(targetClient, reason)
				local message = string.format("%s banned %s for %s minutes.", TGNS.GetClientName(client), TGNS.GetClientName(targetClient), TEMPBAN_DURATION_IN_MINUTES)
				tempbanMessageDisplayer:ToAdminChat(message)
				tempbanMessageDisplayer:ToClientConsole(client, message)
			end
		else
			tempbanMessageDisplayer:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerName))
			ShowUsage(client)
		end
	else
		tempbanMessageDisplayer:ToClientConsole(client, "You must be a Temp Admin or Admin to use this command.")
	end
end
TGNS.RegisterCommandHook("Console_sv_tempban", svTempBan, "<player> <reason> Bans players for 15 minutes.")