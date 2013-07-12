Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSPlayerDataRepository.lua")
Script.Load("lua/TGNSScoreboardMessageChanger.lua")

local PLAYER_CHANGE_INTERVAL_THRESHOLD_IN_SECONDS = 1814400
local PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE = "3-week"

local warned = {}
local bkas = {}

local pdr = TGNSPlayerDataRepository.Create("bka", function(bkaData)
			bkaData.AKAs = bkaData.AKAs ~= nil and bkaData.AKAs or {}
			bkaData.BKA = bkaData.BKA ~= nil and bkaData.BKA or ""
			bkaData.BKAPlayerModifiedAtInSeconds = bkaData.BKAPlayerModifiedAtInSeconds ~= nil and bkaData.BKAPlayerModifiedAtInSeconds or 0
			bkaData.BKAPlayerModifiedAtGmtString = bkaData.BKAPlayerModifiedAtGmtString ~= nil and bkaData.BKAPlayerModifiedAtGmtString or nil
			return bkaData
		end
	)

local function ShowCurrentBka(client, targetSteamId, bkaHeader, akasHeader, prefix)
	local steamId = TGNS.GetClientSteamId(client)
	local bkaData = pdr:Load(targetSteamId)
	local player = TGNS.GetPlayerMatchingSteamId(targetSteamId)
	TGNS.ConsolePrint(client, " ", prefix)
	if player ~= nil then
		TGNS.ConsolePrint(client, string.format(" For: %s", player:GetName()), prefix)
		TGNS.ConsolePrint(client, " ", prefix)
	end
	TGNS.ConsolePrint(client, string.format(" %s:", bkaHeader), prefix)
	if bkaData == nil or bkaData.BKA == nil or string.len(bkaData.BKA) == 0 then
		TGNS.ConsolePrint(client, "     (none)", prefix)
	else
		TGNS.ConsolePrint(client, string.format("     %s", bkaData.BKA), prefix)
	end
	TGNS.ConsolePrint(client, string.format(" %s:", akasHeader), prefix)
	if bkaData == nil or bkaData.AKAs == nil or #bkaData.AKAs == 0 then
		TGNS.ConsolePrint(client, "     (none)", prefix)
	else
		TGNS.DoFor(bkaData.AKAs, function(a) TGNS.ConsolePrint(client, string.format("     %s", a), prefix) end)
	end
end

local function ShowUsage(client, targetSteamId) 
	ServerAdminPrint(client, "[BKA]")
	ServerAdminPrint(client, "[BKA] Usage:")
	ServerAdminPrint(client, "[BKA]     sv_aka <target> <aka>")
	ServerAdminPrint(client, "[BKA]     sv_bka <target> <bka>")
	ServerAdminPrint(client, "[BKA] Notes:")
	ServerAdminPrint(client, "[BKA] * Keep the BKA/AKA short.")
	ServerAdminPrint(client, "[BKA] * BKA is enforced.")
	ServerAdminPrint(client, "[BKA] * <bka> of 'clear' removes enforced BKA name")
	ServerAdminPrint(client, "[BKA] * <aka> of 'clear' removes all AKA names")
	if targetSteamId ~= nil then
		ShowCurrentBka(client, targetSteamId, "BKA", "AKAs", "BKA")
	end
	ServerAdminPrint(client, "[BKA]")
end

local function AddAka(targetSteamId, newBkaName, allowClearParameterToRemoveAllAkaValues)
	local bkaData = pdr:Load(targetSteamId)
	if newBkaName ~= "clear" or not allowClearParameterToRemoveAllAkaValues then
		table.insert(bkaData.AKAs, newBkaName)
	else
		bkaData.AKAs = {}
	end
	bkaData.AKAs = TGNS.TableUnique(bkaData.AKAs)
	pdr:Save(bkaData)
end

local function svAka(client, playerName, ...)
	local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
	if targetPlayer ~= nil then
		local targetClient = Server.GetOwner(targetPlayer)
		if targetClient ~= nil then
			local targetSteamId = targetClient:GetUserId()
			local newBkaName = TGNS.GetConcatenatedStringOrEmpty(...)
			if newBkaName ~= "" then
				AddAka(targetSteamId, newBkaName, true)
				ShowCurrentBka(client, targetSteamId, "BKA", "AKAs", "BKA")
			else
				ShowUsage(client, targetSteamId)
			end
		else
			ServerAdminPrint(client, string.format("'%s' uniquely matches a player, but no client found.", playerName))
		end
	else
		if playerName == nil then
			ShowUsage(client, nil)
		else
			ServerAdminPrint(client, string.format("'%s' does not uniquely match a player.", playerName))
		end
		
	end
end
TGNS.RegisterCommandHook("Console_sv_aka", svAka, "<target> <aka> Adds an AKA name to the target.")

local function OnBkaChanged(actingClient, targetClient, bkaData, newBkaName, bkaHeader, akaHeader, messagePrefix)
	bkaData.BKA = newBkaName
	pdr:Save(bkaData)
	bkas[targetClient] = newBkaName
	TGNS.UpdateAllScoreboards()
	ShowCurrentBka(actingClient, TGNS.GetClientSteamId(targetClient), bkaHeader, akaHeader, messagePrefix)
end

local function svOwnBka(client, ...)
	local newBkaName = TGNS.GetConcatenatedStringOrEmpty(...)
	local steamId = TGNS.GetClientSteamId(client)
	local bkaData = pdr:Load(steamId)
	local bkaChangeError
	local timeRemainingBeforePlayerMayChangeOwnBkaInSeconds = bkaData.BKAPlayerModifiedAtInSeconds + PLAYER_CHANGE_INTERVAL_THRESHOLD_IN_SECONDS - TGNS.GetSecondsSinceEpoch()
	if timeRemainingBeforePlayerMayChangeOwnBkaInSeconds > 0 then
		bkaChangeError = string.format("%s cooldown in progress since %s (GMT). An admin can always edit your Better Known As.", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE, bkaData.BKAPlayerModifiedAtGmtString)
	else
		if newBkaName == "" then
			bkaChangeError = "No Better Known As name specified."
		elseif newBkaName == "clear" then
			bkaChangeError = "This Better Known As name may not be used."
		end
	end
	if bkaChangeError then
		TGNS.ConsolePrint(client, string.format("ERROR: %s", bkaChangeError), "BKA")
		TGNS.ConsolePrint(client, "Usage: sv_name <name>", "BKA")
	else
		if warned[client] == newBkaName then
			TGNS.ExecuteClientCommand(client, string.format("name %s", newBkaName))
			bkaData.BKAPlayerModifiedAtInSeconds = TGNS.GetSecondsSinceEpoch()
			bkaData.BKAPlayerModifiedAtGmtString = TGNS.GetCurrentDateTimeAsGmtString()
			OnBkaChanged(client, client, bkaData, newBkaName, "Better Known As", "Aliases", "BKA")
		else
			TGNS.ConsolePrint(client, string.format("WHOA! You're setting your Better Known As name, with a %s cooldown before you can edit it again!", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE), "BKA")
			TGNS.ConsolePrint(client, "Your Better Known As name stays with you if you later choose a different player name.", "BKA")
			TGNS.ConsolePrint(client, "Any player may view your Better Known As at any time with the sv_whois command.", "BKA")
			TGNS.ConsolePrint(client, string.format("If you're sure '%s' is what you want, execute this same command again.", newBkaName), "BKA")
			warned[client] = newBkaName
		end
	end
end
TGNS.RegisterCommandHook("Console_sv_name", svOwnBka, string.format("<name> Edit your own Better Known As (%s cooldown between edits).", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE), true)

local function svBka(client, playerName, ...)
	local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
	if targetPlayer ~= nil then
		local targetClient = TGNS.GetClient(targetPlayer)
		if targetClient ~= nil then
			local newBkaName = TGNS.GetConcatenatedStringOrEmpty(...)
			if newBkaName == "" then
				TGNS.ConsolePrint(client, "ERROR: No BKA name specified.", "BKA")
			else
				if newBkaName == "clear" then
					newBkaName = nil
				end
				local targetSteamId = TGNS.GetClientSteamId(targetClient)
				local bkaData = pdr:Load(targetSteamId)
				OnBkaChanged(client, targetClient, bkaData, newBkaName, "BKA", "AKAs", "BKA")
			end
		else
			ServerAdminPrint(client, string.format("'%s' uniquely matches a player, but no client found.", playerName))
		end
	else
		if playerName == nil then
			ShowUsage(client, nil)
		else
			ServerAdminPrint(client, string.format("'%s' does not uniquely match a player.", playerName))
		end
	end
end
TGNS.RegisterCommandHook("Console_sv_bka", svBka, "<target> <bka> Adds a BKA name to the target.")

local function OnClientDelayedConnect(client)
	local bkaData = pdr:Load(TGNS.GetClientSteamId(client))
	if bkaData ~= nil and bkaData.BKA ~= nil and string.len(bkaData.BKA) > 0 then
		bkas[client] = bkaData.BKA
		TGNS.UpdateAllScoreboards()
	end
end
TGNS.RegisterEventHook("OnClientDelayedConnect", OnClientDelayedConnect)

TGNSScoreboardMessageChanger.Add(TGNSScoreboardMessageChanger.Priority.LOWEST, function(scorePlayer, sendToPlayer, scoresMessage)
	local client = TGNS.GetClient(scorePlayer)
	local bkaName = bkas[client]
	if bkaName ~= nil and not TGNS.StringEqualsCaseInsensitive(TGNS.GetPlayerName(scorePlayer), bkaName) then
		scoresMessage.playerName = string.format("*%s", scoresMessage.playerName)
	end
end)

local function ShowWhoisUsage(client)
	TGNS.ConsolePrint(client, "Usage: sv_whois <player>", "WHOIS")
end

local function svWhois(client, playerName)
	if playerName == nil or playerName == "" then
		TGNS.ConsolePrint(client, "You must specify a player.", "WHOIS")
		ShowWhoisUsage(client)
	else
		local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = TGNS.GetClient(targetPlayer)
			local targetSteamId = TGNS.GetClientSteamId(targetClient)
			ShowCurrentBka(targetClient, targetSteamId, "Better Known As", "Aliases", "WHOIS")
			local logMessage = string.format("%s executed whois against %s.", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetClientNameSteamIdCombo(targetClient))
			TGNS.EnhancedLog(logMessage)
		else
			TGNS.ConsolePrint(client, string.format("'%s' does not uniquely match a player.", playerName), "WHOIS")
			ShowWhoisUsage(client)
		end
	end
end
TGNS.RegisterCommandHook("Console_sv_whois", svWhois, "<player> View player's aliases.", true)

function BkaOnCommandSetName(client, message)
	local name = TrimName(message.name)
	if name ~= kDefaultPlayerName and string.len(name) > 0 then
		local steamId = TGNS.GetClientSteamId(client)
		AddAka(steamId, name, false)
	end
end
TGNS.RegisterNetworkMessageHook("SetName", BkaOnCommandSetName)
