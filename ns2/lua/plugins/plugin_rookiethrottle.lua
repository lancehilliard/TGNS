// disallow too many concurrent rookies

if kDAKConfig and kDAKConfig.RookieThrottle then
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
		if TGNS.GetPlayerCount() > kDAKConfig.RookieThrottle.kPlayerCountThreshold and GetRookieCount() > kDAKConfig.RookieThrottle.kRookieCountThreshold and playerIsRookie then
			TGNS.SendChatMessage(player, kDAKConfig.RookieThrottle.kPreKickChatMessage)
			TGNS.KickClient(client, kDAKConfig.RookieThrottle.kKickReason)
		end
	end
	DAKRegisterEventHook("kDAKOnClientDelayedConnect", RookieThrottleOnClientDelayedConnect, 5)
end

Shared.Message("RookieThrottle Loading Complete")