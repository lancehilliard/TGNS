Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSPlayerDataRepository.lua")
Script.Load("lua/TGNSPlayerBlacklistRepository.lua")

local RosterCheckInterval = 10

local function CreateRole(displayName, candidatesDescription, groupName, chatPrefix, optInConsoleCommandName, persistedDataName, isClientOneOfQuery, isClientBlockerQuery, minimumRequirementsQuery)
	local result = {}
	local pdr = TGNSPlayerDataRepository.Create(persistedDataName, function(data)
			data.optin = data.optin ~= nil and data.optin or false
			return data
		end)
	local pbr = TGNSPlayerBlacklistRepository.Create(persistedDataName)
	result.displayName = displayName
	result.candidatesDescription = candidatesDescription
	result.groupName = groupName
	result.chatPrefix = chatPrefix
	result.optInConsoleCommandName = optInConsoleCommandName
	result.IsClientOneOf = isClientOneOfQuery
	result.IsClientBlockerOf = isClientBlockerQuery
	function result:IsTeamEligible(teamPlayers) return TGNS.GetLastMatchingClient(teamPlayers, self.IsClientBlockerOf) == nil end
	function result:IsClientBlacklisted(client) return pbr:IsClientBlacklisted(client) end
	function result:LoadOptInData(client) return pdr:Load(TGNS.GetClientSteamId(client)) end
	function result:SaveOptInData(pdrData) pdr:Save(pdrData) end
	function result:IsClientEligible(client) return minimumRequirementsQuery(client) and self:LoadOptInData(client).optin and not self:IsClientBlacklisted(client) end
	return result
end

local roles = {
	CreateRole("Temp Admin"
		, "Supporting Members who have signed the TGNS Primer"
		, "tempadmin_group"
		, "TEMPADMIN"
		, "sv_tempadmin"
		, "tempadmin"
		, TGNS.IsClientTempAdmin
		, TGNS.IsClientAdmin
		, function(client) return TGNS.IsClientSM(client) and TGNS.HasClientSignedPrimer(client) end)
	, CreateRole("Guardian"
		, "players who have signed the TGNS Primer"
		, "guardian_group"
		, "GUARDIAN"
		, "sv_guardian"
		, "guardian"
		, TGNS.IsClientGuardian
		, function(client) return TGNS.IsClientTempAdmin(client) or TGNS.IsClientAdmin(client) end
		, TGNS.HasClientSignedPrimer)
}

local function GetCandidateClient(teamPlayers, role)
	local result = nil
	if role:IsTeamEligible(teamPlayers) then
		if #TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientOneOf(c) end) == 0 then
			result = TGNS.GetLastMatchingClient(teamPlayers, function(c,p) return role:IsClientEligible(c) end)
		end
	end
	return result
end

local function AddToClient(client, role)
	TGNS.AddSteamIDToGroup(TGNS.GetClientSteamId(client), role.groupName)
	TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, string.format("You are %s. Apply exemplarily. Console: sv_help", role.displayName)) end)
	TGNS.UpdateAllScoreboards()
end

local function RemoveFromClient(client, role)
	local steamId = TGNS.GetClientSteamId(client)
	TGNS.RemoveSteamIDFromGroup(steamId, role.groupName)
	TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, string.format("You are no longer %s.", role.displayName)) end)
	TGNS.UpdateAllScoreboards()
end

local function EnsureAmongPlayers(players, role)
	local candidateClient = GetCandidateClient(players, role)
	if candidateClient ~= nil then
		AddToClient(candidateClient, role)
	end
end

local function ToggleOptIn(client, role)
	local message
	if role:IsClientBlacklisted(client) then
		message = "Contact an Admin to get access to Temp Admin: tacticalgamer.com/natural-selection-contact-admin"
	else
		local pdrData = role:LoadOptInData(client)
		pdrData.optin = not pdrData.optin
		role:SaveOptInData(pdrData)
		if pdrData.optin then
			message = string.format("You are opted into %s. Only %s are considered.", role.displayName, role.candidatesDescription)
		else
			message = string.format("You will no longer be considered for %s.", role.displayName)
			RemoveFromClient(client, role)
		end
	end
	TGNS.ConsolePrint(client, message, role.chatPrefix)
end

local function RegisterCommandHook(role)
	TGNS.RegisterCommandHook("Console_" .. role.optInConsoleCommandName, function(client) ToggleOptIn(client, role) end, string.format("Toggle opt in/out of %s responsibilities.", role.displayName), true)
end
TGNS.DoFor(roles, RegisterCommandHook)

local function CheckRoster()
	TGNS.ScheduleAction(RosterCheckInterval, CheckRoster)

	local playerList = TGNS.GetPlayerList()
	local marinePlayers = TGNS.GetMarinePlayers(playerList)
	local alienPlayers = TGNS.GetAlienPlayers(playerList)
	local readyRoomPlayers = TGNS.GetReadyRoomPlayers(playerList)

	TGNS.DoFor(roles, function(role)
		EnsureAmongPlayers(readyRoomPlayers, role)
		EnsureAmongPlayers(marinePlayers, role)
		EnsureAmongPlayers(alienPlayers, role)
	end)
end
TGNS.ScheduleAction(RosterCheckInterval, CheckRoster)

TGNS.RegisterEventHook("OnTeamJoin", function(self, player, newTeamNumber, force)
	TGNS.DoFor(roles, function(role)
		local teamClients = TGNS.GetTeamClients(newTeamNumber, TGNS.GetPlayerList())
		local playerIsClientBlockerOf = TGNS.ClientAction(player, role.IsClientBlockerOf)
		if playerIsClientBlockerOf then
			TGNS.DoFor(TGNS.Where(teamClients, role.IsClientOneOf), function(c) RemoveFromClient(c, role) end)
		end
		local playerIs = TGNS.ClientAction(player, role.IsClientOneOf)
		if playerIs then
			local teamPlayers = TGNS.GetPlayers(teamClients)
			local numberOnNewTeam = #TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientOneOf(c) end)
			local numberOfBlockersOnNewTeam = #TGNS.GetMatchingClients(teamPlayers, function(c,p) return role.IsClientBlockerOf(c) end)
			if (numberOnNewTeam > 0 or numberOfBlockersOnNewTeam > 0) then
				TGNS.ClientAction(player, function(c) RemoveFromClient(c, role) end)
			end
		end
	end)
end)