// give some players limited admin commands when no admin is present

if kDAKConfig and kDAKConfig.TempAdmin then
	Script.Load("lua/TGNSCommon.lua")
	Script.Load("lua/TGNSPlayerDataRepository.lua")
	Script.Load("lua/TGNSPlayerBlacklistRepository.lua")
	
	local RosterCheckInterval = 10
	local pdr = TGNSPlayerDataRepository.Create("tempadmin", function(tempAdminData)
				tempAdminData.optin = tempAdminData.optin ~= nil and tempAdminData.optin or false
				return tempAdminData
			end
		)

	local pbr = TGNSPlayerBlacklistRepository.Create("tempadmin")
		
	local function IsClientOptedIn(client)
		local tempAdminData = pdr:Load(TGNS.GetClientSteamId(client))
		local result = tempAdminData.optin
		return result
	end

	local function IsTempAdminEligible(client)
		local result = TGNS.IsClientSM(client) and TGNS.HasClientSignedPrimer(client) and IsClientOptedIn(client) and not pbr:IsClientBlacklisted(client)
		return result
	end
	
	local function GetExistingTempAdminsCount(teamPlayers)
		local existingTempAdmins = TGNS.GetMatchingClients(teamPlayers, function(c,p) return TGNS.IsClientTempAdmin(c) end)
		local result = #existingTempAdmins
		return result
	end
	
	local function GetExistingAdminsCount(teamPlayers)
		local existingAdmins = TGNS.GetMatchingClients(teamPlayers, function(c,p) return TGNS.IsClientAdmin(c) end)
		local result = #existingAdmins
		return result
	end
	
	local function GetTempAdminCandidateClient(teamPlayers)
		local result = nil
		local teamNeedsAdmin = TGNS.GetLastMatchingClient(teamPlayers, TGNS.IsClientAdmin) == nil
		if teamNeedsAdmin then
			if GetExistingTempAdminsCount(teamPlayers) == 0 then
				result = TGNS.GetLastMatchingClient(teamPlayers, function(c,p) return IsTempAdminEligible(c) end)
			end
		end
		return result
	end
	
	local function svTempAdmin(client)
		local message
		if pbr:IsClientBlacklisted(client) then
			message = "Contact an Admin to get access to Temp Admin: tacticalgamer.com/natural-selection-contact-admin"
		else
			local tempAdminData = pdr:Load(TGNS.GetClientSteamId(client))
			tempAdminData.optin = not tempAdminData.optin
			pdr:Save(tempAdminData)
			if tempAdminData.optin then
				message = "You are opted into Temp Admin. Only Supporting Members who have signed the TGNS Primer are considered."
			else
				message = "You will no longer be considered for Temp Admin."
			end
		end
		TGNS.ConsolePrint(client, message, "TEMPADMIN")
	end
	DAKCreateServerAdminCommand("Console_sv_tempadmin", svTempAdmin, "Toggle opt in/out of Temp Admin responsibilities.", true)

	local function AddTempAdminToClient(client)
		AddSteamIDToGroup(TGNS.GetClientSteamId(client), "tempadmin_group")
		TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, "You are Temp Admin. Apply exemplarily. Console: sv_help") end)
		TGNS.UpdateAllScoreboards()
	end
	
	local function RemoveTempAdminFromClient(client)
		local steamId = TGNS.GetClientSteamId(client)
		RemoveSteamIDFromGroup(steamId, "tempadmin_group")
		TGNS.PlayerAction(client, function(p) TGNS.SendChatMessage(p, "You are no longer Temp Admin.") end)
		TGNS.UpdateAllScoreboards()
	end
	
	local function EnsureTempAdminAmongPlayers(players)
		local tempAdminCandidateClient = GetTempAdminCandidateClient(players)
		
		if tempAdminCandidateClient ~= nil then
			AddTempAdminToClient(tempAdminCandidateClient)
		end
	end
	
	local function CheckRoster()
		TGNS.ScheduleAction(RosterCheckInterval, CheckRoster)

		local playerList = TGNS.GetPlayerList()
		local marinePlayers = TGNS.GetMarinePlayers(playerList)
		local alienPlayers = TGNS.GetAlienPlayers(playerList)
		local readyRoomPlayers = TGNS.GetReadyRoomPlayers(playerList)

		EnsureTempAdminAmongPlayers(readyRoomPlayers)
		EnsureTempAdminAmongPlayers(marinePlayers)
		EnsureTempAdminAmongPlayers(alienPlayers)
	end
	
	local function RemoveTempAdmins(clients)
		TGNS.DoFor(clients, function(c)
				if TGNS.IsClientTempAdmin(c) then
					RemoveTempAdminFromClient(c)
				end
			end
		)
	end
	
	local function TempAdminOnTeamJoin(self, player, newTeamNumber, force)
		local playerIsAdmin = TGNS.ClientAction(player, TGNS.IsClientAdmin)
		local playerIsTempAdmin = TGNS.ClientAction(player, function(c) return TGNS.IsClientTempAdmin(c) end)
		local teamClients = TGNS.GetTeamClients(newTeamNumber, TGNS.GetPlayerList())
		if playerIsAdmin then
			RemoveTempAdmins(teamClients)
		end
		if playerIsTempAdmin then
			local teamPlayers = TGNS.GetPlayers(teamClients)
			local numberOfTempAdminsOnNewTeam = GetExistingTempAdminsCount(teamPlayers)
			Shared.Message(tostring(numberOfTempAdminsOnNewTeam))
			local numberOfAdminsOnNewTeam = GetExistingAdminsCount(teamPlayers)
			Shared.Message(tostring(numberOfAdminsOnNewTeam))
			if (numberOfTempAdminsOnNewTeam > 0 or numberOfAdminsOnNewTeam > 0) then
				TGNS.ClientAction(player, RemoveTempAdminFromClient)
			end
		end
	end
	DAKRegisterEventHook("kDAKOnTeamJoin", TempAdminOnTeamJoin, 5)

	TGNS.ScheduleAction(RosterCheckInterval, CheckRoster)
end

Shared.Message("TempAdmin Loading Complete")