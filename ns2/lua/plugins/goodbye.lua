Script.Load("lua/TGNSCommon.lua")

local function ShowUsage(client) 
	TGNS.ConsolePrint(client, "", "GOODBYE")
	TGNS.ConsolePrint(client, "All usages are logged. Apply exemplarily.", "GOODBYE")
	TGNS.ConsolePrint(client, "", "GOODBYE")
	TGNS.ConsolePrint(client, "Usage:", "GOODBYE")
	TGNS.ConsolePrint(client, "    gb <target> <reason>", "GOODBYE")
	TGNS.ConsolePrint(client, "Notes:", "GOODBYE")
	TGNS.ConsolePrint(client, " * <target> is a partial name which uniquely identifies a Stranger", "GOODBYE")
	TGNS.ConsolePrint(client, " * <reason> is a documented server rule for which THE PLAYER HAS ALREADY BEEN WARNED", "GOODBYE")
	TGNS.ConsolePrint(client, " * REPEAT: THE PLAYER HAS TO HAVE BEEN WARNED (politely, as you're able)", "GOODBYE")
	TGNS.ConsolePrint(client, "", "GOODBYE")
end

local function OnCommandGoodbye(client, playerName, ...)
	if TGNS.HasClientSignedPrimer(client) or TGNS.IsClientAdmin(client) then
		local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = TGNS.GetClient(targetPlayer)
			if targetClient ~= nil then
				local reason = TGNS.GetConcatenatedStringOrEmpty(...)
				if reason == "" then
					ShowUsage(client)
					TGNS.ConsolePrint(client, "============== ERROR: ==============", "GOODBYE")
					TGNS.ConsolePrint(client, string.format("Specify a documented server rule that %s violated.", TGNS.GetPlayerName(targetPlayer)), "GOODBYE")
					TGNS.ConsolePrint(client, string.format("NOTE: Make sure %s has been warned (politely if you can manage it)!", TGNS.GetPlayerName(targetPlayer)), "GOODBYE")
					TGNS.ConsolePrint(client, "See usage notes above.", "GOODBYE")
				else
					if TGNS.IsClientStranger(targetClient) then
						TGNS.KickClient(targetClient, reason)
						TGNS.EnhancedLog(string.format("%s executed gb against %s with reason '%s'.", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetClientNameSteamIdCombo(targetClient), reason))
						TGNS.ConsolePrint(client, string.format("%s will be shown the following and removed: %s", TGNS.GetPlayerName(targetPlayer), reason), "GOODBYE")
					else
						ShowUsage(client)
						TGNS.ConsolePrint(client, "============== ERROR: ==============", "GOODBYE")
						TGNS.ConsolePrint(client, string.format("%s is not a Stranger. See usage notes above.", TGNS.GetPlayerName(targetPlayer)), "GOODBYE")
					end
				end
			else
				TGNS.ConsolePrint(client, "============== ERROR: ==============", "GOODBYE")
				TGNS.ConsolePrint(client, string.format("'%s' uniquely matches a player, but no client found. Try again.", playerName), "GOODBYE")
			end
		else
			if playerName == nil then
				ShowUsage(client, nil)
			else
				TGNS.ConsolePrint(client, "============== ERROR: ==============", "GOODBYE")
				TGNS.ConsolePrint(client, string.format("'%s' does not uniquely match a player.", playerName), "GOODBYE")
			end
			
		end
	else
		TGNS.ConsolePrint(client, "============== ERROR: ==============", "GOODBYE")
		TGNS.ConsolePrint(client, "You must sign the TGNS Primer to use this command.", "GOODBYE")
	end
end
TGNS.RegisterCommandHook("Console_gb", OnCommandGoodbye, "Remove a rule-violating Stranger from the server.")