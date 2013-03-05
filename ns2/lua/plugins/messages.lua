//NS2 Client Messages

local lastMessageTime = DAK.config.messages.kMessageStartDelay
local messageline = 0
local messagetick = 0

local function DisplayMessage(client, message)

	local player = client:GetControllingPlayer()
	chatMessage = string.sub(string.format(message), 1, kMaxChatLength)
	Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)

end

local function ProcessMessagesforUser(client, messagestart)

	local messages = DAK:GetLanguageSpecificMessage("PeriodicMessages", DAK:GetClientLanguageSetting(client))
	if messages ~= nil then
		for i = messagestart, #messages do
		
			if i < DAK.config.messages.kMessagesPerTick + messagestart then
				DisplayMessage(client, messages[i])
			else
				messagetick = Shared.GetTime() + DAK.config.messages.kMessageTickDelay
				messageline = i
				return
			end
		end
	end

	messagetick = 0
	messageline = 0

end

local function ProcessMessageQueue(deltatime)

	local tt = Shared.GetTime()
	if lastMessageTime + (DAK.config.messages.kMessageInterval * 60) < tt and messagetick < tt then
	
		local oldmessageline = ConditionalValue(messageline > 0, messageline, 1)
		for index, player in ientitylist(Shared.GetEntitiesWithClassname("Player")) do
			local client = Server.GetOwner(player)
			
			if client ~= nil and DAK:VerifyClient(client) ~= nil then
				ProcessMessagesforUser(client, oldmessageline)
			end
			
		end
		if messageline == 0 then
			lastMessageTime = Shared.GetTime()
		end
		
	end
	
end

DAK:RegisterEventHook("OnServerUpdate", ProcessMessageQueue, 5)