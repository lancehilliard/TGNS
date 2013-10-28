local function GetChannelOrTgns(channel)
	local result = TGNS.HasNonEmptyValue(channel) and channel or "TGNS"
	return result
end

local function SendConsoleMessage(client, message, channel, isTeamMessage)
	if client ~= nil then
		channel = isTeamMessage and string.format("%s-TEAM", channel) or channel
		message = string.format("[%s] %s", channel, message)
		ServerAdminPrint(client, message)
	end
end

local function SendChatMessage(player, message, channel, isTeamMessage)
	if player ~= nil then
		message = TGNS.Truncate(message, kMaxChatLength)
		local playerLocationId = -1
		local chatNetworkMessage = BuildChatMessage(isTeamMessage, channel, playerLocationId, kTeamReadyRoom, kNeutralTeamType, message)
		local iSureWouldLikeToKnowOneDayWhatThisParameterIsNamedAndWhatItMeans = true
		Server.SendNetworkMessage(player, "Chat", chatNetworkMessage, iSureWouldLikeToKnowOneDayWhatThisParameterIsNamedAndWhatItMeans)
		SendConsoleMessage(TGNS.GetClient(player), message, channel)
	end
end

TGNSMessageDisplayer = {}

function TGNSMessageDisplayer.Create(messagesChannel)
	local result = {}
	result.messagesChannel = GetChannelOrTgns(messagesChannel)

	function result:ToPlayerChat(player, message)
		SendChatMessage(player, message, self.messagesChannel)
		Shared.Message(string.format("TGNSMessageDisplayer: To %s chat: %s", TGNS.GetClientName(client), message))
	end

	function result:ToClientConsole(client, message)
		SendConsoleMessage(client, message, self.messagesChannel)
		Shared.Message(string.format("TGNSMessageDisplayer: To %s console: %s", TGNS.GetClientName(client), message))
	end

	function result:ToAdminChat(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) SendChatMessage(p, message, self.messagesChannel) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To admin chat: %s", message))
	end

	function result:ToAdminConsole(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To admin console: %s", message))
	end

	function result:ToPlayersChat(players, message)
		TGNS.DoFor(players, function(p)
			SendChatMessage(p, message, self.messagesChannel)
		end)
		local playerNames = TGNS.Join(TGNS.Select(players, TGNS.GetPlayerName), ",")
		Shared.Message(string.format("TGNSMessageDisplayer: To %s chat: %s", playerNames, message))
	end

	function result:ToClientsConsole(clients, message)
		TGNS.DoFor(clients, function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
		local clientNames = TGNS.Join(TGNS.Select(clients, TGNS.GetClientName), ",")
		Shared.Message(string.format("TGNSMessageDisplayer: To %s console: %s", clientNames, message))
	end

	function result:ToAllConsole(message)
		TGNS.DoFor(TGNS.GetClientList(), function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To all console: %s", message))
	end

	function result:ToTeamChat(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) SendChatMessage(p, message, self.messagesChannel, true) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To team %s chat: %s", teamNumber, message))
	end

	function result:ToTeamConsole(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To team %s console: %s", teamNumber, message))
	end

	function result:ToAllChat(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			SendChatMessage(p, message, self.messagesChannel)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To all chat: %s", message))
	end

	function result:ToPlayerNotifyInfo(player, message)
		Shine:NotifyDualColour(player, 240, 230, 130, "[" .. self.messagesChannel .. "]", 255, 255, 255, message)
		SendConsoleMessage(TGNS.GetClient(player), message, self.messagesChannel)
		Shared.Message(string.format("TGNSMessageDisplayer: To %s notifyinfo: %s", TGNS.GetPlayerName(player), message))
	end

	function result:ToPlayerNotifyError(player, message)
		Shine:NotifyDualColour(player, 255, 0, 0, "[" .. self.messagesChannel .. " ERROR]", 255, 255, 255, message)
		SendConsoleMessage(TGNS.GetClient(player), message, self.messagesChannel)
		Shared.Message(string.format("TGNSMessageDisplayer: To %s notifyerror: %s", TGNS.GetPlayerName(player), message))
	end

	function result:ToAllNotifyInfo(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			self:ToPlayerNotifyInfo(p, message)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To all notifyinfo: %s", message))
	end

	function result:ToAllNotifyError(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			self:ToPlayerNotifyError(p, message)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To all notifyerror: %s", message))
	end

	function result:ToTeamNotifyInfo(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) self:ToPlayerNotifyInfo(p, message, self.messagesChannel, true) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To team %s notifyinfo: %s", teamNumber, message))
	end

	function result:ToTeamNotifyError(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) self:ToPlayerNotifyError(p, message, self.messagesChannel, true) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To team %s notifyerror: %s", teamNumber, message))
	end

	function result:ToAdminNotifyInfo(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) self:ToPlayerNotifyInfo(p, message) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To admin notifyinfo: %s", message))
	end

	function result:ToAuthorizedNotifyInfo(message, commandName)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c) return TGNS.ClientCanRunCommand(c, commandName) end), function(c)
			TGNS.PlayerAction(c, function(p) self:ToPlayerNotifyInfo(p, message) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To %s authorized notifyinfo: %s", commandName, message))
	end

	return result
end