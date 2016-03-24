local PLAYER_CHANGE_INTERVAL_THRESHOLD_IN_SECONDS = 1814400
local PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE = "3-week"
local PERSISTENT_PLAYER_NAME_GAMES_COUNT_THRESHOLD = 20

local warned = {}
local bkas = {}
local steamPlayerDatas = {}
--local fetchDurations = {}
local batchBkas = {}
local dataFetchFailedFor = {}

local pdr = TGNSPlayerDataRepository.Create("bka", function(bkaData)
	bkaData.AKAs = bkaData.AKAs ~= nil and bkaData.AKAs or {}
	bkaData.BKA = bkaData.BKA ~= nil and bkaData.BKA or ""
	bkaData.BKAPlayerModifiedAtInSeconds = bkaData.BKAPlayerModifiedAtInSeconds ~= nil and bkaData.BKAPlayerModifiedAtInSeconds or 0
	bkaData.BKAPlayerModifiedAtGmtString = bkaData.BKAPlayerModifiedAtGmtString ~= nil and bkaData.BKAPlayerModifiedAtGmtString or nil
	return bkaData
end)

local function getSteamIdProfileName(steamId)
	local steamPlayerData = steamPlayerDatas[steamId]
	local result = steamPlayerData and steamPlayerData.personaname or nil
	return result
end

local function getSteamIdProfileUrl(steamId)
	local steamPlayerData = steamPlayerDatas[steamId]
	local result = steamPlayerData and steamPlayerData.profileurl or nil
	return result
end

local Plugin = {}

function Plugin:ShowCurrentBka(client, targetSteamId, bkaHeader, akasHeader, prefix)
	local md = TGNSMessageDisplayer.Create(prefix)
	pdr:Load(targetSteamId, function(loadResponse)
		local whoisMd = TGNSMessageDisplayer.Create("WHOIS")
		if loadResponse.success then
			local player = TGNS.GetPlayer(client)
			local bkaData = loadResponse.value
			local targetPlayer = TGNS.GetPlayerMatchingSteamId(targetSteamId)
			md:ToClientConsole(client, " ")
			if targetPlayer ~= nil then
				md:ToClientConsole(client, string.format(" For: %s", TGNS.GetPlayerName(targetPlayer)))
				md:ToClientConsole(client, " ")
			end
			md:ToClientConsole(client, string.format(" %s:", bkaHeader))
			if bkaData == nil or bkaData.BKA == nil or string.len(bkaData.BKA) == 0 then
				md:ToClientConsole(client, "     (none)")
			else
				md:ToClientConsole(client, string.format("     %s", bkaData.BKA))
			end
			md:ToClientConsole(client, string.format(" %s:", akasHeader))
			if bkaData == nil or bkaData.AKAs == nil or #bkaData.AKAs == 0 then
				md:ToClientConsole(client, "     (none)")
			else
				TGNS.DoFor(bkaData.AKAs, function(a) md:ToClientConsole(client, string.format("     %s", a)) end)
			end
			md:ToClientConsole(client, " ")
			whoisMd:ToPlayerNotifyInfo(player, string.format("%s (#%s%s): %s%s", TGNS.GetPlayerName(targetPlayer), TGNS.GetPlayerGameId(targetPlayer), (TGNS.IsClientAdmin(client) and TGNS.IsClientSM(TGNS.GetClient(targetPlayer))) and " SM" or "", ((bkaData.BKA and bkaData.BKA ~= "") and string.format("%s*, ", bkaData.BKA) or ""), TGNS.Join(bkaData.AKAs, ", ")))
			md:ToClientConsole(client, " ")
			md:ToClientConsole(client, "Steam Community URL:")
			md:ToClientConsole(client, getSteamIdProfileUrl(targetSteamId) or "<unknown>")
			md:ToClientConsole(client, " ")
			whoisMd:ToPlayerNotifyInfo(player, string.format("Steam Community Profile Name: %s", getSteamIdProfileName(targetSteamId) or "<unknown>"))
			md:ToClientConsole(client, " ")

			-- if not TGNS.IsClientStranger(client) and not TGNS.IsSteamIdStranger(targetSteamId) then
			-- 	local otherAdminPlayers = TGNS.GetPlayers(TGNS.GetClientList(function(c) return c ~= client and TGNS.IsClientAdmin(c) end))
			-- 	TGNS.DoFor(otherAdminPlayers, function(p)
			-- 		md:ToPlayerNotifyInfo(p, string.format("ADMIN: %s queried %s.", TGNS.GetClientName(client), TGNS.GetPlayerName(targetPlayer)))
			-- 	end)
			-- end


		else
			Shared.Message("betterknownas ERROR: unable to access data")
			whoisMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to access data.")
		end
	end)
end

function Plugin:PlayerFailsBkaPrerequisite(player)
	local result = false
	local client = TGNS.GetClient(player)
	if client then
		local totalGamesPlayedCount = Balance.GetTotalGamesPlayed(client)
		if totalGamesPlayedCount >= PERSISTENT_PLAYER_NAME_GAMES_COUNT_THRESHOLD and not Shine.Plugins.betterknownas:IsPlayingWithBkaName(client) and not dataFetchFailedFor[client] then
			result = true
		end
		-- if not TGNS.IsProduction() then
		-- 	result = true
		-- end
	end
	return result
end

local function getBkaPrerequisiteChatAdvisoryMessage()
	local result = string.format("%s+ games played on server. Persistent player name required to play. Use sh_name -- see console (`) for details.", PERSISTENT_PLAYER_NAME_GAMES_COUNT_THRESHOLD)
	return result
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	if not (force or shineForce) then
		if TGNS.IsGameplayTeamNumber(newTeamNumber) and Shine.Plugins.betterknownas:PlayerFailsBkaPrerequisite(player) then
			local client = TGNS.GetClient(player)
			local md = TGNSMessageDisplayer.Create()
			md:ToPlayerNotifyError(player, getBkaPrerequisiteChatAdvisoryMessage())
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "=================================================================================")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "You tried to join a team, but there's a problem:")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, string.format("You've played %s+ games on TGNS. It's time to register your", PERSISTENT_PLAYER_NAME_GAMES_COUNT_THRESHOLD))
			              md:ToClientConsole(client, "persistent player name (your \"BKA\") using the sh_name command.")
			md:ToClientConsole(client, "")
			              md:ToClientConsole(client, "Type sh_name in your console and follow the instructions.")
			md:ToClientConsole(client, "")
			              md:ToClientConsole(client, "Once sh_name reports your player name as matching your BKA, you're all set!")
			md:ToClientConsole(client, "")
			              md:ToClientConsole(client, "If you need help, use admin chat (@) or CAA: http://rr.tacticalgamer.com/Community")
			              md:ToClientConsole(client, "")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "")
			md:ToClientConsole(client, "=================================================================================")
			return false
		end
	end
end

local function ShowUsage(client, targetSteamId)
	local md = TGNSMessageDisplayer.Create("BKA")
	md:ToClientConsole(client, " ")
	md:ToClientConsole(client, " Usage:")
	md:ToClientConsole(client, "     sh_aka <target> <aka>")
	md:ToClientConsole(client, "     sh_bka <target> <bka>")
	md:ToClientConsole(client, " Notes:")
	md:ToClientConsole(client, " * Keep the BKA/AKA short.")
	md:ToClientConsole(client, " * BKA is enforced.")
	md:ToClientConsole(client, " * <bka> of 'clear' removes enforced BKA name")
	md:ToClientConsole(client, " * <aka> of 'clear' removes all AKA names")
	if targetSteamId ~= nil then
		Shine.Plugins.betterknownas:ShowCurrentBka(client, targetSteamId, "BKA", "AKAs", "BKA")
	end
	md:ToClientConsole(client, " ")
end

local function AddAka(targetSteamId, newBkaName, allowClearParameterToRemoveAllAkaValues, callback)
	callback = callback or function() end
	pdr:Load(targetSteamId, function(loadResponse)
		if loadResponse.success then
			local bkaData = loadResponse.value
			local akaWasChanged = false
			if newBkaName ~= "clear" or not allowClearParameterToRemoveAllAkaValues then
				if not TGNS.Any(bkaData.AKAs, function(a) return a == newBkaName end) then
					table.insert(bkaData.AKAs, newBkaName)
					akaWasChanged = true
				end
			else
				bkaData.AKAs = {}
				akaWasChanged = true
			end
			bkaData.AKAs = TGNS.GetUniqueTableValues(bkaData.AKAs)
			if akaWasChanged then
				pdr:Save(bkaData, function(saveResponse)
					if saveResponse.success then
						callback(true)
					else
						Shared.Message("betterknownas ERROR: Unable to save data")
						callback(false)
					end
				end)
			else
				callback(true)
			end
		else
			Shared.Message("betterknownas ERROR: Unable to access data")
			callback(false)
		end
	end)
end

local function OnBkaChanged(actingClient, targetClient, bkaData, newBkaName, bkaHeader, akaHeader, messagePrefix, showCurrentBka)
	bkaData.BKA = newBkaName
	pdr:Save(bkaData)
	bkas[targetClient] = newBkaName
	if showCurrentBka then
		Shine.Plugins.betterknownas:ShowCurrentBka(actingClient, TGNS.GetClientSteamId(targetClient), bkaHeader, akaHeader, messagePrefix)
	end
	TGNS.ExecuteEventHooks("BkaChanged", targetClient)
end

local function ShowWhoisUsage(client)
	local md = TGNSMessageDisplayer.Create("WHOIS")
	md:ToClientConsole(client, "Usage: sh_whois <player>")
end

function Plugin:IsPlayingWithBkaName(client)
	local bkaName = bkas[client]
	local result = bkaName ~= nil and TGNS.StringEqualsCaseInsensitiveAndWhitespaceInsensitive(TGNS.GetClientName(client), bkaName)
	return result
end

function Plugin:HasBkaName(client)
	local result = bkas[client] ~= nil
	return result
end

function Plugin:IsPlayingWithoutBkaName(player)
	local client = TGNS.GetClient(player)
	local bkaName = bkas[client]
	local result = bkaName ~= nil and not self:IsPlayingWithBkaName(client)
	return result
end

function Plugin:ClientConnect(client)
	--local connectMomentInSeconds = TGNS.GetSecondsSinceEpoch()
	local md = TGNSMessageDisplayer.Create(string.format("BKACLIENTCONNECTFETCH %s", TGNS.GetClientSteamId(client)))
	if not TGNS.GetIsClientVirtual(client) then
		local ns2id = TGNS.GetClientSteamId(client)
		local steamApiProfileUrl = TGNS.GetSteamApiProfileUrlFromNs2Id(ns2id)
		TGNS.GetHttpAsync(steamApiProfileUrl, function(response)
			local data = json.decode(response)
			if data ~= nil then
				local steamPlayerData = TGNS.GetFirst(data.response.players)
				steamPlayerDatas[ns2id] = steamPlayerData
			end
		end)
		bkas[client] = batchBkas[ns2id]
		if bkas[client] == nil then
			pdr:Load(TGNS.GetClientSteamId(client), function(loadResponse)
				if loadResponse.success then
					local bkaData = loadResponse.value
					if bkaData ~= nil and bkaData.BKA ~= nil and string.len(bkaData.BKA) > 0 then
						bkas[client] = bkaData.BKA
						if Shine:IsValidClient(client) then
							md:ToAdminConsole(string.format("Fetched '%s' BKA when %s connected (why wasn't it loaded at map load?).", bkas[client], TGNS.GetClientName(client)))
						end
					end
					dataFetchFailedFor[client] = false
					TGNS.ExecuteEventHooks("BkaChanged", client)
				else
					dataFetchFailedFor[client] = true
					TGNS.ExecuteEventHooks("BkaChanged", client)
					Shared.Message("betterknownas ERROR: unable to access data")
				end
				--local fetchDuration = TGNS.GetSecondsSinceEpoch() - connectMomentInSeconds
				--table.insert(fetchDurations, fetchDuration)
				--md:ToAdminConsole(string.format("%s (%s, %s)", loadResponse.success and "LOADED" or "ERROR", math.floor(fetchDuration), math.floor(TGNSAverageCalculator.CalculateFor(fetchDurations))))
			end)
		end
	end
end

function Plugin:GetSteamProfileName(client)
	local ns2id = TGNS.GetClientSteamId(client)
	local result = getSteamIdProfileName(ns2id)
	return result
end

function Plugin:GetSteamProfileUrl(client)
	local ns2id = TGNS.GetClientSteamId(client)
	local result = getSteamIdProfileUrl(ns2id)
	return result
end

function Plugin:CreateCommands()
	local whoisCommand = self:BindCommand( "sh_whois", "whois", function(client, playerPredicate)
		local md = TGNSMessageDisplayer.Create("WHOIS")
		if playerPredicate == nil or playerPredicate == "" then
			md:ToClientConsole(client, "You must specify a player.")
			ShowWhoisUsage(client)
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
			if targetPlayer ~= nil then
				local targetClient = TGNS.GetClient(targetPlayer)
				local targetSteamId = TGNS.GetClientSteamId(targetClient)
				self:ShowCurrentBka(client, targetSteamId, "Better Known As", "Aliases", "WHOIS")
				local logMessage = string.format("%s executed whois against %s.", TGNS.GetClientNameSteamIdCombo(client), TGNS.GetClientNameSteamIdCombo(targetClient))
				TGNS.EnhancedLog(logMessage)
			else
				md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerPredicate))
				ShowWhoisUsage(client)
			end
		end
	end, true)
	whoisCommand:AddParam{ Type = "string", Optional = true }
	whoisCommand:Help( "<player> View player's aliases." )

	local missingBkasCommand = self:BindCommand( "sh_missingbkas", nil, function(client)
		local md = TGNSMessageDisplayer.Create("BKAS")
		local clients = TGNS.GetClientList(function(c) return TGNS.IsPrimerOnlyClient(c) or (Balance.GetTotalGamesPlayed(c) >= PERSISTENT_PLAYER_NAME_GAMES_COUNT_THRESHOLD) end)
		TGNS.SortAscending(clients, function(c) return string.format("%s%s", self:IsPlayingWithBkaName(c) and "aaaaa" or "zzzzz", TGNS.GetClientName(c)) end)
		md:ToClientConsole(client, "")
		md:ToClientConsole(client, string.format("Primer Only (or %s+ games) BKAs:", PERSISTENT_PLAYER_NAME_GAMES_COUNT_THRESHOLD))
		TGNS.DoFor(clients, function(c)
			md:ToClientConsole(client, string.format("%s: %s: %s", self:IsPlayingWithBkaName(c) and "MATCH" or "NO MATCH", TGNS.GetClientName(c), bkas[c]))
		end)
		md:ToClientConsole(client, "")
	end)
	missingBkasCommand:Help( "View all players' BKAs." )

	local bkaCommand = self:BindCommand( "sh_bka", "bka", function(client, playerName, newBkaName)
		local md = TGNSMessageDisplayer.Create("BKA")
		local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = TGNS.GetClient(targetPlayer)
			if targetClient ~= nil then
				if newBkaName == nil or newBkaName == "" then
					md:ToClientConsole(client, "ERROR: No BKA name specified.")
				else
					if newBkaName == "clear" then
						newBkaName = nil
					end
					local targetSteamId = TGNS.GetClientSteamId(targetClient)
					pdr:Load(targetSteamId, function(loadResponse)
						if loadResponse.success then
							local bkaData = loadResponse.value
							OnBkaChanged(client, targetClient, bkaData, newBkaName, "BKA", "AKAs", "BKA", true)
						else
							md:ToClientConsole(client, "ERROR: Unable to access BKA data. BKA not changed.")
							Shared.Message("betterknownas ERROR: unable to access data")
						end
					end)
				end
			else
				md:ToClientConsole(client, string.format("'%s' uniquely matches a player, but no client found.", playerName))
			end
		else
			if playerName == nil then
				ShowUsage(client, nil)
			else
				md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerName))
			end
		end
	end )
	bkaCommand:AddParam{ Type = "string", Optional = true}
	bkaCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true}
	bkaCommand:Help( "<target> <bka> Adds a BKA name to the target.")

	local nameCommand = self:BindCommand( "sh_name", "name", function(client, newBkaName)
		newBkaName = newBkaName or ""
		local md = TGNSMessageDisplayer.Create("BKA")
		local steamId = TGNS.GetClientSteamId(client)
		md:ToClientConsole(client, "Loading BKA info. Please wait. This might take several seconds if the map has just finished loading.")
		pdr:Load(steamId, function(loadResponse)
			if loadResponse.success then
				local bkaData = loadResponse.value
				local bkaChangeError
				local timeRemainingBeforePlayerMayChangeOwnBkaInSeconds = bkaData.BKAPlayerModifiedAtInSeconds + PLAYER_CHANGE_INTERVAL_THRESHOLD_IN_SECONDS - TGNS.GetSecondsSinceEpoch()
				local newBkaIsOldBkaExceptQuotes = (TGNS.HasNonEmptyValue(newBkaName) and TGNS.HasNonEmptyValue(bkaData.BKA)) and ((TGNS.Replace(newBkaName, "\"", "") == bkaData.BKA) or (TGNS.Replace(bkaData.BKA, "\"", "") == newBkaName)) or false
				if timeRemainingBeforePlayerMayChangeOwnBkaInSeconds > 0 and TGNS.HasNonEmptyValue(newBkaName) and not newBkaIsOldBkaExceptQuotes then
					bkaChangeError = string.format("%s cooldown in progress since %s (GMT). An admin can always edit your Better Known As.", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE, bkaData.BKAPlayerModifiedAtGmtString)
				else
					if not TGNS.HasNonEmptyValue(newBkaName) then
						bkaChangeError = "You did not specify a new Better Known As name."
					elseif newBkaName == "clear" then
						bkaChangeError = "You specified a Better Known As name that is not allowed."
					elseif newBkaName:len() > kMaxNameLength then
						bkaChangeError = string.format("Your Better Known As name must be %s characters or less.", kMaxNameLength)
					end
				end
				local showSummary = function(client)
					md:ToClientConsole(client, "------------------------------------------")
					md:ToClientConsole(client, string.format("Your current BKA: %s", bkas[client] or ""))
					md:ToClientConsole(client, string.format("Your current player name: %s", TGNS.GetClientName(client)))
					md:ToClientConsole(client, string.format("Your current BKA %s your current player name.", self:IsPlayingWithBkaName(client) and "matches" or "does not match"))
					md:ToClientConsole(client, "------------------------------------------")
				end
				if bkaChangeError then
					md:ToAdminConsole(string.format("%s had error with sh_name: %s", TGNS.GetClientName(client), bkaChangeError))
					md:ToClientConsole(client, string.format("ERROR: %s", bkaChangeError))
					md:ToClientConsole(client, string.format("ERROR: %s", bkaChangeError))
					md:ToClientConsole(client, string.format("ERROR: %s", bkaChangeError))
					md:ToClientConsole(client, string.format("ERROR: %s", bkaChangeError))
					md:ToClientConsole(client, string.format("ERROR: %s", bkaChangeError))
					md:ToClientConsole(client, "")
					md:ToClientConsole(client, "Usage: sh_name <name>")
					md:ToClientConsole(client, "Example: sh_name Tony")
					md:ToClientConsole(client, "Example: sh_name Tony the Tiger")
					md:ToClientConsole(client, string.format("Example: sh_name %s", TGNS.GetClientName(client)))
					md:ToClientConsole(client, "")
					showSummary(client)
					md:ToClientConsole(client, "You can get help with this command in our Contact an Admin forum.")
					md:ToClientConsole(client, "Any full admin can fix any BKA you've set for yourself in error. Just ask!")
					md:ToClientConsole(client, "Otherwise, use the Usage/Examples above to set your BKA.")
				else
					if warned[client] == newBkaName then
						if TGNS.GetClientName(client) ~= newBkaName then
							TGNS.SendClientCommand(client, string.format("name %s", newBkaName))
						end
						bkaData.BKAPlayerModifiedAtInSeconds = TGNS.GetSecondsSinceEpoch()
						bkaData.BKAPlayerModifiedAtGmtString = TGNS.GetCurrentDateTimeAsGmtString()
						TGNS.ScheduleAction(1, function()
							if Shine:IsValidClient(client) then
								OnBkaChanged(client, client, bkaData, newBkaName, "Better Known As", "Aliases", "BKA", false)
								md:ToAdminConsole(string.format("%s set BKA successfully.", TGNS.GetClientName(client)))
								showSummary(client)
							end
						end)
					else
						md:ToAdminConsole(string.format("%s needs to repeat same input for BKA to take effect.", TGNS.GetClientName(client)))
						md:ToClientConsole(client, "")
						md:ToClientConsole(client, "")
						md:ToClientConsole(client, "")
						md:ToClientConsole(client, "")
						md:ToClientConsole(client, "")
						md:ToClientConsole(client, "WHOA! You're not quite done yet!")
						md:ToClientConsole(client, string.format("You're setting your Better Known As name, with a %s cooldown before you can edit it again!", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE))
						md:ToClientConsole(client, "")
						md:ToClientConsole(client, string.format("If you're sure '%s' is what you want, execute this same command again:", newBkaName))
						md:ToClientConsole(client, "")
						md:ToClientConsole(client, string.format("sh_name %s", newBkaName))
						md:ToClientConsole(client, "")
						warned[client] = newBkaName
					end
				end
				md:ToClientConsole(client, "")
			else
				md:ToClientConsole(client, "ERROR: Unable to access sh_name data. sh_name not changed.")
				Shared.Message("betterknownas ERROR: Unable to access data.")
			end
		end)
	end, true)
	nameCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true}
	nameCommand:Help(string.format("<name> Edit your own Better Known As (%s cooldown between edits).", PLAYER_CHANGE_INTERVAL_THRESHOLD_ADJECTIVE))

	local akaCommand = self:BindCommand( "sh_aka", "aka", function(client, playerName, newBkaName)
		local md = TGNSMessageDisplayer.Create()
		local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = TGNS.GetClient(targetPlayer)
			if targetClient ~= nil then
				local targetSteamId = TGNS.GetClientSteamId(targetClient)
				if newBkaName ~= nil and newBkaName ~= "" then
					AddAka(targetSteamId, newBkaName, true, function(success)
						if success then
							self:ShowCurrentBka(client, targetSteamId, "BKA", "AKAs", "BKA")
						else
							md:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to add AKA.")
						end
					end)
				else
					ShowUsage(client, targetSteamId)
				end
			else
				md:ToClientConsole(client, string.format("'%s' uniquely matches a player, but no client found.", playerName))
			end
		else
			if playerName == nil then
				ShowUsage(client, nil)
			else
				md:ToClientConsole(client, string.format("'%s' does not uniquely match a player.", playerName))
			end
		end
	end )
	akaCommand:AddParam{ Type = "string", Optional = true}
	akaCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true}
	akaCommand:Help("<target> <aka> Adds an AKA name to the target.")
end

function Plugin:PlayerNameChange(player, newName, oldName)
	local client = TGNS.GetClient(player)
	if newName ~= kDefaultPlayerName and string.len(newName) > 0 then
		if client and not TGNS.GetIsClientVirtual(client) then
			local steamId = TGNS.GetClientSteamId(client)
			AddAka(steamId, newName, false)
		end
		if self:PlayerFailsBkaPrerequisite(player) then
			md:ToAdminConsole(string.format("Player still fails BKA prerequisite after name change. OldName: %s; NewName: %s; BKA: %s", oldName, newName, bkas[client]))
		end
	end
	if TGNS.PlayerIsOnPlayingTeam(player) and Shine.Plugins.betterknownas:PlayerFailsBkaPrerequisite(player) then
		local md = TGNSMessageDisplayer.Create()
		md:ToPlayerNotifyError(player, getBkaPrerequisiteChatAdvisoryMessage())
		TGNS.SendToTeam(player, kTeamReadyRoom, true)
	end
end

function Plugin:Initialise()
    self.Enabled = true
	self:CreateCommands()

	local batchLoadBkas
	batchLoadBkas = function()
		if TGNS.Config and TGNS.Config.BkaEndpointBaseUrl then
			TGNS.GetHttpAsync(TGNS.Config.BkaEndpointBaseUrl, function(bkaResponseJson)
				local bkaResponse = json.decode(bkaResponseJson) or {}
				if bkaResponse.success then
					TGNS.DoFor(bkaResponse.result, function(d)
						batchBkas[d.id] = d.bka
					end)
				else
					TGNS.DebugPrint(string.format("bka ERROR: Unable to access bka data for server %s. msg: %s | response: %s | stacktrace: %s", TGNS.GetSimpleServerName(), bkaResponse.msg, bkaResponseJson, bkaResponse.stacktrace))
				end
			end)
		else
			TGNS.ScheduleAction(0, batchLoadBkas)
		end
	end
	batchLoadBkas()

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("betterknownas", Plugin )