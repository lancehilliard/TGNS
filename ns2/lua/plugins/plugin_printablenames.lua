// require printable characters in player names

if kDAKConfig and kDAKConfig.PrintableNames then

	local function PrintableNamesOnClientDelayedConnect(client)
		local player = client:GetControllingPlayer()

		local _, nonPrintableCharactersCount = string.gsub(player:GetName(), "[^\32-\126]", "")

		if nonPrintableCharactersCount>0 then
			Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, kDAKConfig.PrintableNames.kPrintableNamesWarnMessage), true)
		end
		return true
	end
	table.insert(kDAKOnClientDelayedConnect, function(client) return PrintableNamesOnClientDelayedConnect(client) end)

	local function PrintableNamesOnTeamJoin(player, newTeamNumber, force)
		local _, nonPrintableCharactersCount = string.gsub(player:GetName(), "[^\32-\126]", "")
		if nonPrintableCharactersCount>0 and newTeamNumber ~= kTeamReadyRoom then
			local client = Server.GetOwner(player)
			client.disconnectreason = kDAKConfig.PrintableNames.kPrintableNamesKickMessage
			Server.DisconnectClient(client)
		end
		return true
	end
	table.insert(kDAKOnTeamJoin, function(player, newTeamNumber, force) return PrintableNamesOnTeamJoin(player, newTeamNumber, force) end)

	function PrintableNamesOnCommandSetName(client, name)
		if client ~= nil and name ~= nil then
			local player = client:GetControllingPlayer()
			local _, nonPrintableCharactersCount = string.gsub(player:GetName(), "[^\32-\126]", "")
			if nonPrintableCharactersCount>0 and player:GetTeamNumber() ~= kTeamReadyRoom then
				local gamerules = GetGamerules()
				if gamerules then
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, kDAKConfig.PrintableNames.kPrintableNamesWarnMessage), true)
					gamerules:JoinTeam(player, kTeamReadyRoom)
				end
			end
		end
	end
	Event.Hook("Console_name", PrintableNamesOnCommandSetName)

end

Shared.Message("PrintableNames Loading Complete")