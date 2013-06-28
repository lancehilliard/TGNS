Script.Load("lua/TGNSCommon.lua")

//Still need to add to list of denied and allowed functions by type
function svTempBan(client, playerName, ...)
	local targetPlayer = TGNS.GetPlayerMatching(playerName, nil)
	if targetPlayer ~= nil then
			DisplayMessageAll("svtempban was initiated")
			TGNS.GetPlayerId(targetPlayer)	
			TGNS.Ban(client, playerId, 15, ...)
	else
		TGNS.SendAdminChat("svTempban initiated no target found", "ADMINDEBUG")
	end
end
TGNS.RegisterCommandHook("Console_sv_tempban", svTempBan, "<player> <reason> Bans players for 15 minutes.")

function TGNS.Ban(client, playerId, duration, ...)
	Ban(client, playerId, duration, ...)
end