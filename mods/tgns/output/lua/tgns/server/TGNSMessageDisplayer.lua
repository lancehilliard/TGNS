local ADMINONLY_CHANNEL_DECORATOR = " (ADMINS)"

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

local function NotifyInfo(player, message, messagesChannel, prefixRed, prefixGreen, prefixBlue)
	if player ~= nil then
		prefixRed = prefixRed or 240
		prefixGreen = prefixGreen or 230
		prefixBlue = prefixBlue or 130
		Shine:NotifyDualColour(player, prefixRed, prefixGreen, prefixBlue, "[" .. messagesChannel .. "]", 255, 255, 255, message)
		SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
	end
end

local function NotifyColors(player, message, messagesChannel, channelRed, channelBlue, channelGreen, messageRed, messageBlue, messageGreen)
	if player ~= nil then
		Shine:NotifyDualColour(player, channelRed, channelBlue, channelGreen, "[" .. messagesChannel .. "]", messageRed, messageBlue, messageGreen, message)
		SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
	end
end

local function NotifyRed(player, message, messagesChannel)
	if player ~= nil then
		Shine:NotifyDualColour(player, 255, 0, 0, "[" .. messagesChannel .. "]", 255, 255, 255, message)
		SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
	end
end

local function NotifyYellow(player, message, messagesChannel)
	if player ~= nil then
		Shine:NotifyDualColour(player, 255, 255, 0, "[" .. messagesChannel .. "]", 255, 255, 255, message)
		SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
	end
end

local function NotifyGreen(player, message, messagesChannel)
	if player ~= nil then
		Shine:NotifyDualColour(player, 0, 128, 0, "[" .. messagesChannel .. "]", 255, 255, 255, message)
		SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
	end
end

local function NotifyError(player, message, messagesChannel)
	if player ~= nil then
		Shine:NotifyDualColour(player, 255, 0, 0, "[" .. messagesChannel .. " ERROR]", 255, 255, 255, message)
		SendConsoleMessage(TGNS.GetClient(player), message, messagesChannel)
	end
end

-- local function ShowTickerInfo(client, message, messagesChannel)
-- 	TGNS.SendClientCommand(client, string.format("output [%s] %s", messagesChannel, message))
-- 	SendConsoleMessage(client, message, messagesChannel)
-- end

TGNSMessageDisplayer = {}

function TGNSMessageDisplayer.Create(messagesChannel, infoPrefixColors)
	local infoPrefixRed = infoPrefixColors and infoPrefixColors.r or nil
	local infoPrefixGreen = infoPrefixColors and infoPrefixColors.g or nil
	local infoPrefixBlue = infoPrefixColors and infoPrefixColors.b or nil

	local result = {}
	result.messagesChannel = GetChannelOrTgns(messagesChannel)

	function result:ToPlayerChat(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			SendChatMessage(player, message, self.messagesChannel)
		end
	end

	function result:ToClientConsole(client, message)
		if not TGNS.GetIsClientVirtual(client) then
			SendConsoleMessage(client, message, self.messagesChannel)
		end
	end

	function result:ToAdminChat(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) SendChatMessage(p, message, string.format("%s%s", self.messagesChannel, ADMINONLY_CHANNEL_DECORATOR)) end)
		end)
	end

	function result:ToAdminConsole(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			SendConsoleMessage(c, message, string.format("%s%s", self.messagesChannel, ADMINONLY_CHANNEL_DECORATOR))
		end)
	end

	function result:ToPlayersChat(players, message)
		TGNS.DoFor(players, function(p)
			SendChatMessage(p, message, self.messagesChannel)
		end)
		local playerNames = TGNS.Join(TGNS.Select(players, TGNS.GetPlayerName), ",")
	end

	function result:ToClientsConsole(clients, message)
		TGNS.DoFor(clients, function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
		local clientNames = TGNS.Join(TGNS.Select(clients, TGNS.GetClientName), ",")
	end

	function result:ToAllConsole(message)
		TGNS.DoFor(TGNS.GetClientList(), function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
	end

	function result:ToTeamChat(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) SendChatMessage(p, message, self.messagesChannel, true) end)
		end)
	end

	function result:ToTeamConsole(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
	end

	function result:ToAllChat(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			SendChatMessage(p, message, self.messagesChannel)
		end)
	end

	function result:ToPlayerNotifyInfo(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			NotifyInfo(player, message, self.messagesChannel, infoPrefixRed, infoPrefixGreen, infoPrefixBlue)
		end
	end

	function result:ToPlayerNotifyColors(player, message, channelRed, channelBlue, channelGreen, messageRed, messageBlue, messageGreen)
		NotifyColors(player, message, self.messagesChannel, channelRed, channelBlue, channelGreen, messageRed, messageBlue, messageGreen)
	end

	function result:ToPlayerNotifyError(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			NotifyError(player, message, self.messagesChannel)
		end
	end

	function result:ToPlayerNotifyRed(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			NotifyRed(player, message, self.messagesChannel)
		end
	end

	function result:ToPlayerNotifyYellow(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			NotifyYellow(player, message, self.messagesChannel)
		end
	end

	function result:ToPlayerNotifyGreen(player, message)
		local client = TGNS.GetClient(player)
		if not TGNS.GetIsClientVirtual(client) then
			NotifyGreen(player, message, self.messagesChannel)
		end
	end

	function result:ToAllNotifyInfo(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			NotifyInfo(p, message, self.messagesChannel, infoPrefixRed, infoPrefixGreen, infoPrefixBlue)
		end)
	end

	function result:ToAllNotifyError(message)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			NotifyError(p, message, self.messagesChannel)
		end)
	end

	function result:ToTeamNotifyColors(teamNumber, message, channelRed, channelBlue, channelGreen, messageRed, messageBlue, messageGreen)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) NotifyColors(p, message, self.messagesChannel, channelRed, channelBlue, channelGreen, messageRed, messageBlue, messageGreen) end)
		end)
	end

	function result:ToTeamNotifyInfo(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) NotifyInfo(p, message, self.messagesChannel, infoPrefixRed, infoPrefixGreen, infoPrefixBlue) end)
		end)
	end

	function result:ToTeamNotifyError(teamNumber, message)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
			TGNS.PlayerAction(c, function(p) NotifyError(p, message, self.messagesChannel) end)
		end)
	end

	function result:ToAdminNotifyInfo(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) NotifyInfo(p, message, string.format("%s%s", self.messagesChannel, ADMINONLY_CHANNEL_DECORATOR), infoPrefixRed, infoPrefixGreen, infoPrefixBlue) end)
		end)
	end

	function result:ToAdminNotifyError(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) NotifyError(p, message, string.format("%s%s", self.messagesChannel, ADMINONLY_CHANNEL_DECORATOR)) end)
		end)
	end

	function result:ToAuthorizedNotifyInfo(message, commandName)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c) return TGNS.ClientCanRunCommand(c, commandName) end), function(c)
			TGNS.PlayerAction(c, function(p) NotifyInfo(p, message, self.messagesChannel, infoPrefixRed, infoPrefixGreen, infoPrefixBlue) end)
		end)
	end

	-- function result:ToTeamTickerInfo(teamNumber, message)
	-- 	TGNS.DoFor(TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList()), function(c)
	-- 		ShowTickerInfo(c, message, messagesChannel)
	-- 	end)
	-- end

	-- function result:ToAllTickerInfo(message)
	-- 	TGNS.DoFor(TGNS.GetClients(TGNS.GetPlayerList()), function(c)
	-- 		ShowTickerInfo(c, message, messagesChannel)
	-- 	end)
	-- end

	return result
end