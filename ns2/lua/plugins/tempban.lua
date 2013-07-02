Script.Load("lua/TGNSCommon.lua")

//Still need to add to list of denied and allowed functions by type
function svTempBan(client, playerName, ...)
	TGNS.SendAdminChat("svTempban initiated", "ADMINDEBUG")
//	local player = TGNS.GetPlayerMatching(id, nil)
//	local reason =  StringConcatArgs(...) or "No Reason"
//	if player ~= nil then
//			local playerId = TGNS.GetPlayerId(player)	
//			TGNS.Ban(client, playerId, 15, ...)
//			TGNS.SendAdminChat(player:GetName() .. " has been banned.", "ADMINDEBUG")
//	else
//		TGNS.SendAdminChat("svTempban initiated no target found", "ADMINDEBUG")
//	end
end
TGNS.RegisterCommandHook("Console_sv_tempban", svTempBan, "<player> <reason> Bans players for 15 minutes.")