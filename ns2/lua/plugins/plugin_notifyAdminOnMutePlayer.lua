// NotifyAdminOnMutePlayer

if kDAKConfig and kDAKConfig.NotifyAdminOnMutePlayer and kDAKConfig.DAKLoader then
	Script.Load("lua/TGNSCommon.lua")

	local originalOnMutePlayer
	
	local function OnMutePlayer(client, message)
		originalOnMutePlayer(client, message)
		clientIndex, isMuted = ParseMutePlayerMessage(message)
		for _, player in pairs(TGNS:GetPlayerList()) do
			if player:GetClientIndex() == clientIndex then
				if isMuted then
					muteText = "muted"
				else
					muteText = "unmuted"
				end
				TGNS:PMAllPlayersWithAccess(nil, client:GetControllingPlayer():GetName() .. " has " .. muteText .. " player " .. player:GetName(), "sv_mutes", false)
				break
			end
		end
	end

	// trying this without using Class_ReplaceMethod
	local originalHookNetworkMessage = Server.HookNetworkMessage
	
	Server.HookNetworkMessage = function(networkMessage, callback)
		if networkMessage == "MutePlayer" then
			originalOnMutePlayer = callback
			callback = OnMutePlayer
		end
		originalHookNetworkMessage(networkMessage, callback)

	end
	
	local function ListMutes(client)
		// build look up table for player names by clientindex
		playerNames = {}
		
		ServerAdminPrint(client, "Player Mutes:")
		for _, player in pairs(TGNS:GetPlayerList()) do
			playerNames[player:GetClientIndex()] = player:GetName()
		end
		for _, player in pairs(TGNS:GetPlayerList()) do
			for clientIndex, name in pairs(playerNames) do
				if player:GetClientMuted(clientIndex) then
					ServerAdminPrint(client, player:GetName() .. " : " .. name)
				end
			end
		end
	end
	
	DAKCreateServerAdminCommand("Console_sv_mutes", ListMutes, help)

/* 
	local originalHookNetworkMessage

	originalHookNetworkMessage = Class_ReplaceMethod("Server", "HookNetworkMessage", 
		function(networkMessage, callback)

			if networkMessage == "MutePlayer" then
				originalOnMutePlayer = callback
				callback = OnMutePlayer
			end
			originalHookNetworkMessage(networkMessage, callback)

		end
	)
*/
end

Shared.Message("NotifyAdminOnMutePlayer Loading Complete")