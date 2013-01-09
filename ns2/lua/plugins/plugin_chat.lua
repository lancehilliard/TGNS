// Chat
if kDAKConfig and kDAKConfig.Chat then
	Script.Load("lua/TGNSCommon.lua")

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
			TGNS:PMAllPlayersWithAccess(client, chatMessage, command, true)
		end
	end

	for command, help in pairs(kDAKConfig.Chat.Channels) do
		DAKCreateServerAdminCommand("Console_" .. command, function(client, ...) Chat(client, command, ...) end, help)
	end

end

Shared.Message("Chat Loading Complete")