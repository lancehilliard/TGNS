Script.Load("lua/TGNSCommon.lua")

local function GetChannelOrTgns(channel)
	local result = TGNS.HasNonEmptyValue(channel) and channel or "TGNS"
	return result
end

local function SendConsoleMessage(client, message, channel, isTeamMessage)
	if client ~= nil then
		channel = GetChannelOrTgns(channel)
		channel = isTeamMessage and string.format("%s-TEAM", channel) or channel
		message = string.format("[%s] %s", channel, message)
		ServerAdminPrint(client, message)
		local debugMessage = string.format("TGNSMessageDisplayer: To %s: %s", TGNS.GetClientName(client), message)
		Shared.Message(debugMessage)
	end
end

local function SendChatMessage(player, message, channel, isTeamMessage)
	if player ~= nil then
		channel = GetChannelOrTgns(channel)
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
	result.messagesChannel = messagesChannel
	
	function result:ToPlayerChat(player, message)
		SendChatMessage(player, message, self.messagesChannel)
	end
	
	function result:ToClientConsole(client, message)
		SendConsoleMessage(client, message, self.messagesChannel)
	end
	
	function result:ToAdminChat(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			TGNS.PlayerAction(c, function(p) SendChatMessage(p, message, self.messagesChannel) end)
		end)
	end
	
	function result:ToAdminConsole(message)
		TGNS.DoFor(TGNS.GetMatchingClients(TGNS.GetPlayerList(), TGNS.IsClientAdmin), function(c)
			SendConsoleMessage(c, message, self.messagesChannel)
		end)
	end
	
	function result:ToPlayersChat(players, message)
		TGNS.DoFor(players, function(p)
			SendChatMessage(p, message, self.messagesChannel)
		end)
	end
	
	function result:ToClientsConsole(clients, message)
		TGNS.DoFor(clients, function(c)
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

	return result
end