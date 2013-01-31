// disallow too many concurrent rookies

if kDAKConfig and kDAKConfig.RookieThrottle then

	local function GetPlayerCount() 
		local playerRecords = Shared.GetEntitiesWithClassname("Player")
        local result = playerRecords:GetSize()
		return result
	end

	local function GetRookieCount()
		local result = 0
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		for r = #playerList, 1, -1 do
			if playerList[r] ~= nil then
				local playerIsRookie = playerList[r]:GetIsRookie()
				if playerIsRookie then
					result = result + 1
				end
			end
		end
		return result
	end
	
	local function RookieThrottleOnClientDelayedConnect(client)
		local player = client:GetControllingPlayer()
		local playerCount = GetPlayerCount()
		local rookieCount = GetRookieCount()
		local playerIsRookie = player:GetIsRookie()
		if playerCount > kDAKConfig.RookieThrottle.kPlayerCountThreshold and rookieCount > kDAKConfig.RookieThrottle.kRookieCountThreshold and playerIsRookie then
			Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, kDAKConfig.RookieThrottle.kPreKickChatMessage), true)
			local client = Server.GetOwner(player)
			client.disconnectreason = kDAKConfig.RookieThrottle.kKickReason
			Server.DisconnectClient(client)
		end
	end
	DAKRegisterEventHook("kDAKOnClientDelayedConnect", RookieThrottleOnClientDelayedConnect, 5)
end

Shared.Message("RookieThrottle Loading Complete")