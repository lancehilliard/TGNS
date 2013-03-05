Script.Load("lua/TGNSCommon.lua")

local function GetRookieCount()
	local rookieClients = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p)
			return p:GetIsRookie()
		end
	)
	local result = #rookieClients
	return result
end

local function RookieThrottleOnClientDelayedConnect(client)
	local player = TGNS.GetPlayer(client)
	local playerIsRookie = player:GetIsRookie()
	if TGNS.GetPlayerCount() > DAK.config.rookiethrottle.kPlayerCountThreshold and GetRookieCount() > DAK.config.rookiethrottle.kRookieCountThreshold and playerIsRookie then
		TGNS.SendChatMessage(player, DAK.config.rookiethrottle.kPreKickChatMessage)
		TGNS.KickClient(client, DAK.config.rookiethrottle.kKickReason)
	end
end
TGNS.RegisterEventHook("OnClientDelayedConnect", RookieThrottleOnClientDelayedConnect)