// prevent players from joining spectator

if kDAKConfig and kDAKConfig.SpecLimit then
	Script.Load("lua/TGNSCommon.lua")
	local function SpecLimitOnTeamJoin(self, player, newTeamNumber, force)
		local cancel = false
		local playerIsAdmin = TGNS:ClientAction(player, TGNS.IsClientAdmin)
		if newTeamNumber == kSpectatorIndex and not playerIsAdmin then
			TGNS:SendChatMessage(player, "Spectator is not available now.")
			cancel = true
		end
		return cancel
	end
	DAKRegisterEventHook("kDAKOnTeamJoin", SpecLimitOnTeamJoin, 5)
end

Shared.Message("SpecLimit Loading Complete")