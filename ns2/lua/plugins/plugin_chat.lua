// Chat

if kDAKConfig and kDAKConfig.Chat then

	local function GetPlayerList()

		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
		return playerList
		
	end

	local function PMAllPlayersWithAccess(srcClient, message, command, showCommand)
		if srcClient then
			local srcPlayer = srcClient:GetControllingPlayer()
			if srcPlayer then
				srcName = srcPlayer:GetName()
			else
				srcName = kDAKConfig.DAKLoader.MessageSender
			end
		else
			srcName = kDAKConfig.DAKLoader.MessageSender
		end

		if showCommand then
			chatName =  command .. " - " .. srcName
		else
			chatName = srcName
		end

		consoleChatMessage = chatName ..": " .. message

		for _, player in pairs(GetPlayerList()) do
			local client = Server.GetOwner(player)
			if client ~= nil and DAKGetClientCanRunCommand(client, command) then
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, chatName, -1, kTeamReadyRoom, kNeutralTeamType, message), true)
				ServerAdminPrint(client, consoleChatMessage)
			end
		end
	end

	local function GetChatMessage(...)

		local chatMessage = StringConcatArgs(...)
		if chatMessage then
			return string.sub(chatMessage, 1, kMaxChatLength)
		end
		
		return ""
		
	end
	
	local function Chat(client, command, ...)
		local chatMessage = GetChatMessage(...)
		if string.len(chatMessage) > 0 then
			PMAllPlayersWithAccess(client, chatMessage, command, true)
		end
	end

	for command, help in pairs(kDAKConfig.Chat.Types) do
		DAKCreateServerAdminCommand("Console_" .. command, function(client, ...) Chat(client, command, ...) end, help)
	end

end

Shared.Message("Chat Loading Complete")