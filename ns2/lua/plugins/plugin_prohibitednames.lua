// disallow certain player names

if kDAKConfig and kDAKConfig.ProhibitedNames then

	local function PlayerNameIsProhibited(name)
		for _,prohibitedName in ipairs(kDAKConfig.ProhibitedNames.kProhibitedNames) do
			if prohibitedName == name then
				return true
			end
		end
		return false
	end
	
	local function ProhibitedNamesOnClientDelayedConnect(client)
		local player = client:GetControllingPlayer()
		
		if PlayerNameIsProhibited(player:GetName()) then
			Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, kDAKConfig.ProhibitedNames.kProhibitedNamesWarnMessage), true)
		end
		return true
	end
	DAKRegisterEventHook(kDAKOnClientDelayedConnect, ProhibitedNamesOnClientDelayedConnect, 5)

	local function ProhibitedNamesOnTeamJoin(player, newTeamNumber, force)
		if PlayerNameIsProhibited(player:GetName()) and newTeamNumber ~= kTeamReadyRoom then
			local client = Server.GetOwner(player)
			client.disconnectreason = kDAKConfig.ProhibitedNames.kProhibitedNamesKickMessage
			Server.DisconnectClient(client)
		end
		return true
	end
	DAKRegisterEventHook(kDAKOnTeamJoin, ProhibitedNamesOnTeamJoin, 5)

	function ProhibitedNamesOnCommandSetName(client, name)
		if client ~= nil and name ~= nil then
			local player = client:GetControllingPlayer()
			if PlayerNameIsProhibited(name) then
				local gamerules = GetGamerules()
				if gamerules then
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, kDAKConfig.ProhibitedNames.kProhibitedNamesWarnMessage), true)
					gamerules:JoinTeam(player, kTeamReadyRoom)
				end
			end
		end
	end
	Event.Hook("Console_name", ProhibitedNamesOnCommandSetName)

end

Shared.Message("ProhibitedNames Loading Complete")