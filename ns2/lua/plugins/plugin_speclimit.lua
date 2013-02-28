// prevent players from joining spectator

if kDAKConfig and kDAKConfig.SpecLimit then
	Script.Load("lua/TGNSCommon.lua")
	
	local allowedSpectatorSteamIds = {}
	
	//local function RemoveSpecFromSpectatorPlayerNames()
	//	local spectatorClients = TGNS.GetSpectatorClients(TGNS.GetPlayerList())
	//	TGNS.DoFor(spectatorClients, function(c)
	//		local clientName = TGNS.GetClientName(c)
	//		if TGNS.EndsWith(clientName, "-spectate") then
	//			TGNS.PlayerAction(c, function(p) TGNS.SetPlayerName(p, clientName:gsub("-spectate", "")) end)
	//		end
	//	end)
	//end
	//
	//local function SpecLimitOnClientDelayedConnect(client)
	//	local clientName = TGNS.GetClientName(client)
	//	local steamId = TGNS.GetClientSteamId(client)
	//	table.remove(allowedSpectatorSteamIds, steamId)
	//	if TGNS.EndsWith(clientName, "-spectate") then
	//		table.insert(allowedSpectatorSteamIds, steamId)
	//		TGNS.PlayerAction(client, function(p)
	//			TGNS.ScheduleAction(2, RemoveSpecFromSpectatorPlayerNames)
	//			TGNS.SendToTeam(p, kSpectatorIndex)
	//		end)
	//		
	//	end
	//end
	//DAKRegisterEventHook("kDAKOnClientDelayedConnect", SpecLimitOnClientDelayedConnect, 5)
	
	local function SpecLimitOnTeamJoin(self, player, newTeamNumber, force)
		local cancel = false
		if TGNS.IsPlayerSpectator(player) then
			local client = TGNS.ClientAction(player, function(c) return c end)
			local steamId = TGNS.GetClientSteamId(client)
			RemoveSteamIDFromGroup(steamId, "spectator_group")
		end
		local playerIsAdmin = TGNS.ClientAction(player, TGNS.IsClientAdmin)
		if newTeamNumber == kSpectatorIndex then
			if not playerIsAdmin then
				local steamId = TGNS.GetClientSteamId(client)
				if not TGNS.Has(allowedSpectatorSteamIds, steamId) then
					TGNS.SendChatMessage(player, "Spectator is not available now.")
					cancel = true
				end
			end
			if not cancel then
				local client = TGNS.ClientAction(player, function(c) return c end)
				local steamId = TGNS.GetClientSteamId(client)
				AddSteamIDToGroup(TGNS.GetClientSteamId(client), "spectator_group")
			end
		end
		return cancel
	end
	DAKRegisterEventHook("kDAKOnTeamJoin", SpecLimitOnTeamJoin, 5)
end

Shared.Message("SpecLimit Loading Complete")