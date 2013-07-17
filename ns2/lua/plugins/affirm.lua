Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSMessageDisplayer.lua")
Script.Load("lua/TGNSConnectedTimesTracker.lua")

local md = TGNSMessageDisplayer.Create("AFFIRM")

local CONNECTION_TIME_IN_SECONDS = 0

local function ShowUsage(client)
	md:ToClientConsole(client, "Usage: sv_affirm <player>")
	md:ToClientConsole(client, "       All usages logged. Use responsibly!")
end

local function svAffirm(client, playerName)
	if TGNS.IsClientStranger(client) then
		md:ToClientConsole(client, "You must read and agree to our rules in our forums to use this command.")
		md:ToClientConsole(client, "Forums: tacticalgamer.com/natural-selection")
	else
		if playerName == nil or playerName == "" then
			md:ToClientConsole(client, "You must specify a player.")
			ShowUsage(client)
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
			if targetPlayer ~= nil then
				local targetClient = TGNS.GetClient(targetPlayer)
				if TGNS.IsClientStranger(targetClient) then
					TGNSConnectedTimesTracker.SetClientConnectedTimeInSeconds(targetClient, CONNECTION_TIME_IN_SECONDS)
					local message = string.format("%s seemingly connected a long, long time ago...", TGNS.GetClientName(targetClient))
					md:ToClientConsole(client, message)
					local logMessage = string.format("%s executed affirm against %s.", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetClientNameSteamIdCombo(targetClient))
					TGNS.EnhancedLog(logMessage)
				else
					local message = string.format("%s is not a Stranger.", TGNS.GetClientName(targetClient))
					md:ToClientConsole(client, message)
				end
			else
				md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerName))
				ShowUsage(client)
			end
		end
	end
end
TGNS.RegisterCommandHook("Console_sv_affirm", svAffirm, "<player> Sets any stranger's connection time to a long, long time ago...", true)