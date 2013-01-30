// give some players limited admin commands when no admin is present

if kDAKConfig and kDAKConfig.TempAdmin then
	Script.Load("lua/TGNSCommon.lua")
	Script.Load("lua/TGNSPlayerDataRepository.lua")
	
	local RosterCheckInterval = 10
	local pdr = TGNSPlayerDataRepository.Create("tempadmin", function(tempAdminData)
				tempAdminData.optin = tempAdminData.optin ~= nil and tempAdminData.optin or false
				return tempAdminData
			end
		)
		
	local function GetDataFilename(steamId)
		return TGNS:GetDataFilename("tempadmin", steamId)
	end

	local function IsClientOptedIn(client)
		local tempAdminData = pdr:Load(TGNS:GetClientSteamId(client))
		local result = tempAdminData.optin
		return result
	end

	local function IsTempAdminEligible(client)
		local result = TGNS:IsClientSM(client) and TGNS:HasClientSignedPrimer(client) and IsClientOptedIn(client)
		return result
	end
	
	local function GetTempAdminCandidateClient(teamPlayers)
		local result = nil
		local teamNeedsAdmin = TGNS:GetLastMatchingClient(TGNS.IsClientAdmin, teamPlayers) == nil
		if teamNeedsAdmin then
			local existingTempAdmins = TGNS:GetMatchingClients(function(c,p) return TGNS:IsClientTempAdmin(c) end, teamPlayers)
			if #existingTempAdmins == 0 then
				result = TGNS:GetLastMatchingClient(function(c,p) return IsTempAdminEligible(c) end, teamPlayers)
			end
		end
		return result
	end
	
	local function svTempAdmin(client)
		local tempAdminData = pdr:Load(TGNS:GetClientSteamId(client))
		tempAdminData.optin = not tempAdminData.optin
		pdr:Save(tempAdminData)
		local message
		if tempAdminData.optin then
			message = "You are opted into Temp Admin. Only Supporting Members who have signed the TGNS Primer are considered."
		else
			message = "You will no longer be considered for Temp Admin."
		end
		TGNS:ConsolePrint(client, message, "TEMPADMIN")
	end
	DAKCreateServerAdminCommand("Console_sv_tempadmin", svTempAdmin, "Toggle opt in/out of Temp Admin responsibilities.", true)

	
	function AddTempAdminToClient(client)
		AddSteamIDToGroup(TGNS:GetClientSteamId(client), "tempadmin_group")
		TGNS:PlayerAction(client, function(p) TGNS:SendChatMessage(p, "You are Temp Admin. Apply exemplarily. Console: sv_help") end)
	end
	
	function RemoveTempAdminFromClient(client)
		local steamId = TGNS:GetClientSteamId(client)
		RemoveSteamIDFromGroup(steamId, "tempadmin_group")
		TGNS:PlayerAction(client, function(p) TGNS:SendChatMessage(p, "You are no longer Temp Admin.") end)
	end
	
	function EnsureTempAdminAmongPlayers(players)
		local tempAdminCandidateClient = GetTempAdminCandidateClient(players)
		
		if tempAdminCandidateClient ~= nil then
			AddTempAdminToClient(tempAdminCandidateClient)
		end
	end
	
	local function CheckRoster()
		TGNS:ScheduleAction(RosterCheckInterval, CheckRoster)

		local playerList = TGNS:GetPlayerList()
		local marinePlayers = TGNS:GetMarinePlayers(playerList)
		local alienPlayers = TGNS:GetAlienPlayers(playerList)

		EnsureTempAdminAmongPlayers(marinePlayers)
		EnsureTempAdminAmongPlayers(alienPlayers)
	end
	
	local function RemoveTempAdmins(clients)
		TGNS:DoFor(clients, function(c)
				if TGNS:IsClientTempAdmin(c) then
					RemoveTempAdminFromClient(c)
				end
			end
		)
	end
	
	local function TempAdminOnTeamJoin(self, player, newTeamNumber, force)
		local playerIsAdmin = TGNS:ClientAction(player, TGNS.IsClientAdmin)
		local playerIsTempAdmin = TGNS:ClientAction(player, function(c) return TGNS:IsClientTempAdmin(c) end)
		if playerIsAdmin then
			local teamClients = TGNS:GetTeamClients(newTeamNumber, TGNS:GetPlayerList())
			RemoveTempAdmins(teamClients)
		end
		if playerIsTempAdmin then
			TGNS:ClientAction(player, function(c) RemoveTempAdminFromClient(c) end)
		end
	end
	DAKRegisterEventHook(kDAKOnTeamJoin, TempAdminOnTeamJoin, 5)

	TGNS:ScheduleAction(RosterCheckInterval, CheckRoster)
end

Shared.Message("TempAdmin Loading Complete")