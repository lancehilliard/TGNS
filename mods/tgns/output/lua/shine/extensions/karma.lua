local md = TGNSMessageDisplayer.Create()
local karmaCache = {}
local httpFailureCount = {}
local HttpFailureThreshold = 5
local spectateKarmaProgress = {}
local lastTeamExit = {}
local seedingTempfilePath = "config://tgns/temp/seeding.json"

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "karma.json"

local function debug(message)
	if not TGNS.IsProduction() then
		Shared.Message(string.format("KARMADEBUG: %s", message))
	end
end

local function getHumanClients(clients)
	local result = TGNS.Where(clients, function(c) return not TGNS.GetIsClientVirtual(c) end)
	return result
end

local function refreshKarma(steamId)
	httpFailureCount[steamId] = httpFailureCount[steamId] or 0
	if httpFailureCount[steamId] < HttpFailureThreshold and TGNS.IsNumberWithNonZeroPositiveValue(steamId) then
		local url = string.format("%s&i=%s", TGNS.Config.KarmaEndpointBaseUrl, steamId)
		TGNS.GetHttpAsync(url, function(karmaResponseJson)
			local karmaResponse = json.decode(karmaResponseJson) or {}
			if karmaResponse.success then
				karmaCache[steamId] = karmaResponse.result
			else
				httpFailureCount[steamId] = httpFailureCount[steamId] + 1
				TGNS.DebugPrint(string.format("karma ERROR: Unable to access karma data for NS2ID %s (failures: %s). msg: %s | response: %s | stacktrace: %s", steamId, httpFailureCount[steamId], karmaResponse.msg, karmaResponseJson, karmaResponse.stacktrace))
			end
		end)
	end
end

local function addKarma(steamId, deltaName)
	httpFailureCount[steamId] = httpFailureCount[steamId] or 0
	if httpFailureCount[steamId] < HttpFailureThreshold and TGNS.IsNumberWithNonZeroPositiveValue(steamId) then
		local delta = deltaName and Shine.Plugins.karma.Config.Deltas[deltaName] or nil
		if delta == nil then
			TGNS.DebugPrint(string.format("karma ERROR: Unable to resolve %s delta for NS2ID %s.", deltaName, steamId))
		else
			karmaCache[steamId] = karmaCache[steamId] or 0
			karmaCache[steamId] = karmaCache[steamId] + delta
			local url = string.format("%s&i=%s&n=%s&d=%s", TGNS.Config.KarmaEndpointBaseUrl, steamId, TGNS.UrlEncode(deltaName), delta)
			TGNS.GetHttpAsync(url, function(karmaResponseJson)
				local karmaResponse = json.decode(karmaResponseJson) or {}
				if not karmaResponse.success then
					karmaCache[steamId] = karmaCache[steamId] - delta
					httpFailureCount[steamId] = httpFailureCount[steamId] + 1
					TGNS.DebugPrint(string.format("karma ERROR: Unable to save %s delta (%s) for NS2ID %s (failures: %s). msg: %s | response: %s | stacktrace: %s", deltaName, delta, steamId, httpFailureCount[steamId], karmaResponse.msg, karmaResponseJson, karmaResponse.stacktrace))
				end
			end)
		end
	end
end

local function onClientConnect(steamId)
	refreshKarma(steamId)
	if Server.GetNumPlayersTotal() <= 8 and Shared.GetTime() > 60 then
		local seeders = Shine.LoadJSONFile(seedingTempfilePath) or {}
		local humanClients = getHumanClients(TGNS.GetClientList())
		TGNS.DoFor(humanClients, function(c)
			local csteamId = TGNS.GetClientSteamId(c)
			if not TGNS.Has(seeders, csteamId) then
				table.insert(seeders, csteamId)
			end
		end)
		Shine.SaveJSONFile(seeders, seedingTempfilePath)
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	if Server.GetNumPlayersTotal() >= 12 then
		local humanClients = getHumanClients(TGNS.GetClientList())
		local humanSteamIds = TGNS.Select(humanClients, TGNS.GetClientSteamId)
		TGNS.ScheduleAction(2, function()
			local seeders = Shine.LoadJSONFile(seedingTempfilePath) or {}
			TGNS.DoFor(humanSteamIds, function(s)
				if TGNS.Has(seeders, s) then
					TGNS.Karma(s, "Seeding")
				end
			end)
			Shine.SaveJSONFile({}, seedingTempfilePath)
		end)
	end
end

function Plugin:ClientConnect(client)
	local steamId = TGNS.GetClientSteamId(client)
	onClientConnect(steamId)
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
	local steamId = TGNS.GetClientSteamId(client)
	if TGNS.IsGameInProgress() and Shine.Plugins.bots:GetTotalNumberOfBots() == 0 then
		if TGNS.IsGameplayTeamNumber(oldTeamNumber) then
			local teamExit = {}
			teamExit.when = Shared.GetTime()
			teamExit.teamNumber = oldTeamNumber
			teamExit.teamSizeBeforeExit = #getHumanClients(TGNS.GetTeamClients(oldTeamNumber, TGNS.GetPlayerList())) + 1
			lastTeamExit[client] = teamExit
		end
		if TGNS.IsGameplayTeamNumber(newTeamNumber) and lastTeamExit[client] and (lastTeamExit[client].teamNumber ~= newTeamNumber) and (Shared.GetTime() - lastTeamExit[client].when < 10) and ((#getHumanClients(TGNS.GetTeamClients(newTeamNumber)) - 1) - lastTeamExit[client].teamSizeBeforeExit <= -2) and #TGNS.GetPlayerList() >= 8 then
			TGNS.Karma(steamId, "FixingTeamSizes")
		end
	end
end

local function getTargetSteamId(target)
	local result = IsNumber(target) and target or TGNS.GetClientSteamId(target:isa("Player") and TGNS.GetClient(target) or target)
	return result
end

function Plugin:AddKarma(target, deltaName)
	local steamId = getTargetSteamId(target)
	addKarma(steamId, deltaName)
end

function Plugin:GetKarma(target)
	local steamId = getTargetSteamId(target)
	local result = karmaCache[steamId]
	return result
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("FullGamePlayed", function(clients)
		local humanClients = getHumanClients(clients)
		if #humanClients >= 8 then
			local deltaName = (Shine.Plugins.captains and Shine.Plugins.captains.IsCaptainsModeEnabled and Shine.Plugins.captains.IsCaptainsModeEnabled()) and "FullCaptainsRoundPlayed" or "FullGamePlayed"
			TGNS.DoFor(humanClients, function(c)
				local steamId = TGNS.GetClientSteamId(c)
				TGNS.ScheduleAction(10, function()
					TGNS.Karma(steamId, deltaName)
				end)
			end)
		end
	end)

	TGNS.ScheduleActionInterval(30, function()
		local playerList = TGNS.GetPlayerList()
		TGNS.DoFor(TGNS.GetSpectatorClients(playerList), function(c)
			local numberOfPlayingClients = #TGNS.GetPlayingClients(playerList)
			if numberOfPlayingClients >= Shine.Plugins.communityslots.Config.PublicSlots then
				local steamId = TGNS.GetClientSteamId(c)
				spectateKarmaProgress[steamId] = spectateKarmaProgress[steamId] or 0
				spectateKarmaProgress[steamId] = spectateKarmaProgress[steamId] + 1
				if spectateKarmaProgress[steamId] >= 10 then
					TGNS.Karma(steamId, "SpectatingWhenFull")
					spectateKarmaProgress[steamId] = 0
				end
			end
		end)
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("karma", Plugin )