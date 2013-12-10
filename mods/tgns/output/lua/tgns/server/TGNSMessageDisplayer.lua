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

local function NotifyInfo(player, message, messagesChannel)
	Shine:NotifyDualColour(player, 240, 230, 130, "[" .. messagesChannel .. "]", 255, 255, 255, message)
	SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
end

local function NotifyError(player, message, messagesChannel)
	Shine:NotifyDualColour(player, 255, 0, 0, "[" .. messagesChannel .. " ERROR]", 255, 255, 255, message)
	SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
end

-- local function ShowTickerInfo(client, message, messagesChannel)
-- 	TGNS.SendClientCommand(client, string.format("output [%s] %s", messagesChannel, message))
-- 	SendConsoleMessage(client, message, messagesChannel)
-- end

TGNSMessageDisplayer = {}

function TGNSMessageDisplayer.Create(messagesChannel)
	local result = {}
	result.messagesChannel = GetChannelOrTgns(messagesChannel)

	function result:ToPlayerChat(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			SendChatMessage(player, message, self.messagesChannel)
			Shared.Message(string.format("TGNSMessageDisplayer: To %s chat: %s", TGNS.GetClientName(client), message))
		end
	end

	function result:ToClientConsole(client, message)
		if not TGNS.GetIsClientVirtual(client) then
			SendConsoleMessage(client, message, self.messagesChannel)
			Shared.Message(string.format("TGNSMessageDisplayer: To %s console: %s", TGNS.GetClientName(client), message))
		end
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
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			NotifyInfo(player, message, self.messagesChannel)
			Shared.Message(string.format("TGNSMessageDisplayer: To %s notifyinfo: %s", TGNS.GetPlayerName(player), message))
		end
	end

	function result:ToPlayerNotifyError(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			NotifyError(player, message, self.messagesChannel)
			Shared.Message(string.format("TGNSMessageDisplayer: To %s notifyerror: %s", TGNS.GetPlayerName(player), message))
		end
	end

	function result:ToAllNotifyInfo(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			NotifyInfo(p, message, self.messagesChannel)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To all notifyinfo: %s", message))
	end

	function result:ToAllNotifyError(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			NotifyError(p, message, self.messagesChannel)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To all notifyerror: %s", message))
	end

	function result:ToTeamNotifyInfo(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) NotifyInfo(p, message, self.messagesChannel) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To team %s notifyinfo: %s", teamNumber, message))
	end

	function result:ToTeamNotifyError(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) NotifyError(p, message, self.messagesChannel) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To team %s notifyerror: %s", teamNumber, message))
	end

	function result:ToAdminNotifyInfo(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) NotifyInfo(p, message, self.messagesChannel) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To admin notifyinfo: %s", message))
	end

	function result:ToAdminNotifyError(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) NotifyError(p, message, self.messagesChannel) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To admin notifyerror: %s", message))
	end

	function result:ToAuthorizedNotifyInfo(message, commandName)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c) return TGNS.ClientCanRunCommand(c, commandName) end), function(c)
			TGNS.PlayerAction(c, function(p) NotifyInfo(p, message, self.messagesChannel) end)
		end)
		Shared.Message(string.format("TGNSMessageDisplayer: To %s authorized notifyinfo: %s", commandName, message))
	end

	-- function result:ToTeamTickerInfo(teamNumber, message)
	-- 	TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
	-- 		ShowTickerInfo(c, message, messagesChannel)
	-- 	end)
	-- 	Shared.Message(string.format("TGNSMessageDisplayer: To team %s ticker info: %s", teamNumber, message))
	-- end

	-- function result:ToAllTickerInfo(message)
	-- 	TGNS.DoFor(TGNS.GetClients(TGNS.GetPlayerList()), function(c)
	-- 		ShowTickerInfo(c, message, messagesChannel)
	-- 	end)
	-- 	Shared.Message(string.format("TGNSMessageDisplayer: To all ticker info: %s", message))
	-- end

	return result
end