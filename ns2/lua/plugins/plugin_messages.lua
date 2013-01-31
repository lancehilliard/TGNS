//NS2 Client Messages

local lastMessageTime = kDAKConfig.Messages.kMessageStartDelay
local messageline = 0
local messagetick = 0

local function DisplayMessage(client, message)

	local player = client:GetControllingPlayer()
	chatMessage = string.sub(string.format(message), 1, kMaxChatLength)
	Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)

end

local function ProcessMessagesforUser(client, messagestart)

	local messages = DAKGetLanguageSpecificMessage("kPeriodicMessages", DAKGetClientLanguageSetting(client))
	if messages ~= nil then
		for i = messagestart, #messages do
		
			if i < kDAKConfig.Messages.kMessagesPerTick + messagestart then
				DisplayMessage(client, messages[i])
			else
				messagetick = Shared.GetTime() + kDAKConfig.Messages.kMessageTickDelay
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
	if lastMessageTime + (kDAKConfig.Messages.kMessageInterval * 60) < tt and messagetick < tt then
	
		local oldmessageline = ConditionalValue(messageline > 0, messageline, 1)
		for index, player in ientitylist(Shared.GetEntitiesWithClassname("Player")) do
			local client = Server.GetOwner(player)
			
			if client ~= nil and VerifyClient(client) ~= nil then
				ProcessMessagesforUser(client, oldmessageline)
			end
			
		end
		if messageline == 0 then
			lastMessageTime = Shared.GetTime()
		end
		
	end
	
end

DAKRegisterEventHook("kDAKOnServerUpdate", ProcessMessageQueue, 5)