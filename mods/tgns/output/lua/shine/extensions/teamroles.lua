local md = TGNSMessageDisplayer.Create()
local pdrCache = {}
local pbrCache = {}
local pprCache = {}
local knownRoleDataNames = {}
local rolePdrCacheWasPreloaded = {}

local function getPdr(persistedDataName)
	local result = TGNSPlayerDataRepository.Create(persistedDataName, function(data)
		data.optin = data.optin ~= nil and data.optin or false
		return data
	end)
	return result
end

local function CreateRole(displayName, candidatesDescription, groupName, messagePrefix, optInConsoleCommandName, persistedDataName, isClientOneOfQuery, isClientBlockerQuery, minimumRequirementsQuery, clientRankQuery)
	local result = {}
	pdrCache[persistedDataName] = {}
	pbrCache[persistedDataName] = {}
	pprCache[persistedDataName] = {}
	table.insertunique(knownRoleDataNames, persistedDataName)
	local pdr = getPdr(persistedDataName)
	result.displayName = displayName
	result.candidatesDescription = candidatesDescription
	result.groupName = groupName
	result.messagePrefix = messagePrefix
	result.optInConsoleCommandName = optInConsoleCommandName
	result.IsClientOneOf = isClientOneOfQuery
	result.IsClientBlockerOf = isClientBlockerQuery
	function result:IsTeamEligible(teamPlayers) return TGNS.GetLastMatchingClient(teamPlayers, self.IsClientBlockerOf) == nil end
	function result:IsClientBlacklisted(client) 
		local steamId = TGNS.GetClientSteamId(client)
		return pbrCache[persistedDataName][steamId] == true
	end
	function result:IsClientPreferred(client) return pprCache[persistedDataName][client] == true end
	function result:LoadOptInData(client)
		local steamId = TGNS.GetClientSteamId(client)
		local pdrData = pdrCache[persistedDataName][steamId]
		return pdrData
	end
	function result:GetClientRank(client) return clientRankQuery(client) end
	function result:SaveOptInData(pdrData, callback)
		callback = callback or function() end
		pdr:Save(pdrData, function(saveResponse)
			if saveResponse.success then
				-- Shared.Message("persistedDataName: " .. tostring(persistedDataName))
				-- Shared.Message("pdrData.steamId: " .. tostring(pdrData.steamId))
				pdrCache[persistedDataName][pdrData.steamId] = pdrData
				callback(true)
			else
				TGNS.DebugPrint("teamroles ERROR: Unable to save data.", true)
				callback(false)
			end
		end)
	end
	function result:IsClientEligible(client)
		local optinData = self:LoadOptInData(client)
		local clientIsOptedIn = optinData and optinData.optin
		return clientIsOptedIn and minimumRequirementsQuery(client) and not self:IsClientBlacklisted(client)
	end
	return result
end

local roles = {
	CreateRole("Guardian"
		, "TGNS Primer signers who've played >=40 full rounds on this server"
		, "guardian_group"
		, "GUARDIAN"
		, "sh_guardian"
		, "guardian"
		, TGNS.IsClientGuardian
		, function(client) return false end
		, function(client)
			local totalGamesPlayed = Balance.GetTotalGamesPlayed(client)
			return TGNS.HasClientSignedPrimerWithGames(client) and totalGamesPlayed >= 40 and Shine.Plugins.betterknownas:IsPlayingWithBkaName(client) and not TGNS.IsClientAdmin(client)
		end
		, function(client)
			local approvalsCount = Shine.Plugins.scoreboard:GetApprovalsCount(client)
			return approvalsCount
		end)
}


local function GetCandidateClient(teamPlayers, role)
	local result = nil
	local teamIsEligible = role:IsTeamEligible(teamPlayers)
	if teamIsEligible then
		local clientsAlreadyInTheRole = TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientOneOf(c) end)
		if #clientsAlreadyInTheRole < 2 then
			teamPlayers = TGNS.Where(teamPlayers, function(p) return not TGNS.ClientAction(p, role.IsClientOneOf) end)
			TGNS.SortAscending(teamPlayers, function(p) return TGNS.ClientAction(p, function(c) return role:IsClientPreferred(c) end) and math.huge or role:GetClientRank(c) end)
			result = TGNS.GetLastMatchingClient(teamPlayers, function(c,p)
				return role:IsClientEligible(c)
			end)
		end
	end
	return result
end

local function AddToClient(client, role)
	TGNS.AddTempGroup(client, role.groupName)
	local player = TGNS.GetPlayer(client)
	md:ToPlayerNotifyInfo(player, string.format("You are a %s. Apply exemplarily.", role.displayName))
end

local function RemoveFromClient(client, role)
	if role.IsClientOneOf(client) then
		TGNS.PlayerAction(client, function(p) md:ToPlayerNotifyInfo(p, string.format("You are no longer a %s.", role.displayName)) end)
	end
	TGNS.RemoveTempGroup(client, role.groupName)
end

local function EnsureAmongPlayers(players, role)
	local candidateClient = GetCandidateClient(players, role)
	if candidateClient ~= nil then
		AddToClient(candidateClient, role)
	end
end

local function ToggleOptIn(client, role)
	local roleMd = TGNSMessageDisplayer.Create(role.messagePrefix)
	local message
	if role:IsClientBlacklisted(client) then
		message = string.format("Contact an Admin (CAA) to get access to %s: http://rr.tacticalgamer.com/Community", role.displayName)
		roleMd:ToClientConsole(client, message)
	else
		local pdrData = role:LoadOptInData(client)
		pdrData.optin = not pdrData.optin
		role:SaveOptInData(pdrData, function(saveSuccessful)
			if saveSuccessful then
				if pdrData.optin then
					message = string.format("You are opted into %s. Only %s are considered.", role.displayName, role.candidatesDescription)
				else
					message = string.format("You will no longer be considered for %s.", role.displayName)
					RemoveFromClient(client, role)
				end
			else
				message = "Unable to change opt-in status."
			end
			roleMd:ToClientConsole(client, message)
		end)
	end
end

-- local function CheckRoster()
-- 	local playerList = TGNS.GetPlayerList()
-- 	local marinePlayers = TGNS.GetMarinePlayers(playerList)
-- 	local alienPlayers = TGNS.GetAlienPlayers(playerList)
-- 	local readyRoomPlayers = TGNS.GetReadyRoomPlayers(playerList)
-- 	local spectatorPlayers = TGNS.GetSpectatorPlayers(playerList)

-- 	TGNS.DoFor(roles, function(role)
-- 		EnsureAmongPlayers(readyRoomPlayers, role)
-- 		EnsureAmongPlayers(marinePlayers, role)
-- 		EnsureAmongPlayers(alienPlayers, role)
-- 		EnsureAmongPlayers(spectatorPlayers, role)
-- 	end)
-- end

local function RegisterCommandHook(plugin, role)
	local command = plugin:BindCommand(role.optInConsoleCommandName, nil, function(client)
		ToggleOptIn(client, role)
	end, true)
	command:Help(string.format("Toggle opt in/out of %s responsibilities.", role.displayName))
end

local Plugin = {}

function reviewPlayerForRolesChange(player)
	local teamPlayers = TGNS.GetPlayersOnSameTeam(player)
	local teamClients = TGNS.GetClients(teamPlayers)
	TGNS.DoFor(roles, function(role)
		local clientIsBlockerOf = TGNS.ClientAction(player, role.IsClientBlockerOf)
		if clientIsBlockerOf then
			TGNS.DoFor(TGNS.Where(teamClients, role.IsClientOneOf), function(c) RemoveFromClient(c, role) end)
		end
		local clientIsOneOf = TGNS.ClientAction(player, role.IsClientOneOf)
		if clientIsOneOf then
			local numberOnNewTeam = #TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientOneOf(c) end)
			local numberOfBlockersOnNewTeam = #TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientBlockerOf(c) end)
			local client = TGNS.GetClient(player)
			if numberOnNewTeam >= 2 or numberOfBlockersOnNewTeam > 0 or not role:IsClientEligible(client) then
				RemoveFromClient(client, role)
			end
		else
			EnsureAmongPlayers(teamPlayers, role)
		end
	end)
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if not TGNS.GetIsPlayerVirtual(player) then
		reviewPlayerForRolesChange(player)
	end
end

function Plugin:PlayerNameChange(player, newName, oldName)
	if oldName ~= kDefaultPlayerName and newName ~= kDefaultPlayerName and string.len(newName) > 0 then
		if not TGNS.GetIsPlayerVirtual(player) then
			reviewPlayerForRolesChange(player)
		end
	end
end

function Plugin:ClientConnect(client)
	if not TGNS.GetIsClientVirtual(client) then
		local steamId = TGNS.GetClientSteamId(client)
		TGNS.DoFor(knownRoleDataNames, function(roleName)
			if pdrCache[roleName][steamId] == nil then
				if rolePdrCacheWasPreloaded[roleName] then
					pdrCache[roleName][steamId] = {steamId=steamId, optin=false}
				else
					local pdr = getPdr(roleName)
					pdr:Load(steamId, function(loadResponse)
						pdrCache[roleName][steamId] = loadResponse.value
						if not loadResponse.success then
							TGNS.DebugPrint("teamroles ERROR: Unable to access PDR data.", true)
						end
					end)
				end
			end

			local pbr = TGNSPlayerBlacklistRepository.Create(roleName)
			pbr:IsClientBlacklisted(client, function(isBlacklisted)
				pbrCache[roleName][steamId] = isBlacklisted
			end)

			local ppr = TGNSPlayerPreferredRepository.Create(roleName)
			ppr:IsClientPreferred(client, function(isPreferred)
				pprCache[roleName][client] = isPreferred
			end)
		end)
	end
end

function Plugin:ClientConfirmConnect(client)
	if not TGNS.GetIsClientVirtual(client) then
		-- CheckRoster()
		reviewPlayerForRolesChange(TGNS.GetPlayer(client))
	end
end

function Plugin:Initialise()
	self.Enabled = true
	-- TGNS.ScheduleActionInterval(10, CheckRoster)
	TGNS.DoFor(roles, function(r) RegisterCommandHook(self, r) end)
	TGNS.RegisterEventHook("BkaChanged", function(client)
		if Shine:IsValidClient(client) then
			reviewPlayerForRolesChange(TGNS.GetPlayer(client))
		end
	end)

	local function getGuardians()
		if TGNS.Config and TGNS.Config.GuardiansEndpointBaseUrl then
			local url = TGNS.Config.GuardiansEndpointBaseUrl
			TGNS.GetHttpAsync(url, function(guardiansResponseJson)
				local guardiansResponse = json.decode(guardiansResponseJson) or {}
				if guardiansResponse.success then
					TGNS.DoFor(guardiansResponse.result, function(steamId)
						pdrCache["guardian"][steamId] = {steamId=steamId, optin=true}
					end)
					rolePdrCacheWasPreloaded["guardian"] = true
				else
					TGNS.DebugPrint(string.format("teamroles ERROR: Unable to access guardians data. url: %s | msg: %s | response: %s | stacktrace: %s", url, guardiansResponse.msg, guardiansResponseJson, guardiansResponse.stacktrace))
				end
			end)
		else
			TGNS.ScheduleAction(0, getGuardians)
		end
	end
	getGuardians()

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("teamroles", Plugin )