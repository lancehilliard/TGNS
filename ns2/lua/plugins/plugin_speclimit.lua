// prevent players from joining spectator

if kDAKConfig and kDAKConfig.SpecLimit then
	Script.Load("lua/TGNSCommon.lua")
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
				TGNS.SendChatMessage(player, "Spectator is not available now.")
				cancel = true
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