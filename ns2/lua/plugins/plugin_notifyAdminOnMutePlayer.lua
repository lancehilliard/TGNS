// NotifyAdminOnMutePlayer

if kDAKConfig and kDAKConfig.NotifyAdminOnMutePlayer and kDAKConfig.DAKLoader then
	Print("NotifyAdminOnMutePlayer loaded")
	
	local function GetPlayerList()

		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
		return playerList
		
	end
	
	local function PMAllAdminsWithAccess(message, command)
		for _, player in pairs(GetPlayerList()) do
			local client = Server.GetOwner(player)
			if client ~= nil and DAKGetClientCanRunCommand(client, command) then
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, message), true)
			end
		end
	end
	
	local function OnMutePlayer(client, message)
		clientIndex, isMuted = ParseMutePlayerMessage(message)
		if isMuted then
			for _, player in pairs(GetPlayerList()) do
				if player:GetClientIndex() == clientIndex then
					PMAllAdminsWithAccess(client:GetControllingPlayer():GetName() .. " has muted player " .. player:GetName(), "sv_canseemuted")
					break
				end
			end
		end
	end

	//TODO: Found out alternative to Server.HookNetworkMessage("MutePlayer", OnMutePlayer)
	// This does not work.  Only 1 function can be hooked to a network message at a time
	//Server.HookNetworkMessage("MutePlayer", nil)
	Server.HookNetworkMessage("MutePlayer", OnMutePlayer)

end

Shared.Message("NotifyAdminOnMutePlayer Loading Complete")