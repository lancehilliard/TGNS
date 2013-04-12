//NS2 Client Message of the Day

local MOTDClientTracker = { }

if DAK.settings.MOTDAcceptedClients == nil then
	DAK.settings.MOTDAcceptedClients = { }
end
   
local function DisplayMOTDMessage(client, message)

	local player = client:GetControllingPlayer()
	chatMessage = string.sub(string.format(message), 1, kMaxChatLength)
	Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)

end

local function IsAcceptedClient(client)
	if client ~= nil then
		local steamid = tostring(client:GetUserId())
		if DAK.settings.MOTDAcceptedClients[steamid] ~= nil and DAK.settings.MOTDAcceptedClients[steamid] == DAK.config.motd.kMOTDMessageRevision then
			return true		
		end
	end
	return false
end

local function ProcessMessagesforUser(PEntry)
	
	local messages = DAK:GetLanguageSpecificMessage("MOTDMessage", DAK:GetClientLanguageSetting(PEntry.Client))
	local messagestart = PEntry.Message
	if messages ~= nil then
		for i = messagestart, #messages do
		
			if i < DAK.config.motd.kMOTDMessagesPerTick + messagestart then
				DisplayMOTDMessage(PEntry.Client, messages[i])
			else
				PEntry.Message = i
				PEntry.Time = Shared.GetTime() + DAK.config.motd.kMOTDMessageDelay
				break
			end
			
		end
		if #messages < messagestart + DAK.config.motd.kMOTDMessagesPerTick then
			PEntry = nil
		end
	else
		PEntry = nil
	end
	return PEntry
end

local function MOTDOnClientDisconnect(client)    

	if #MOTDClientTracker > 0 then
		for i = 1, #MOTDClientTracker do
			local PEntry = MOTDClientTracker[i]
			if PEntry ~= nil and PEntry.Client ~= nil and DAK:VerifyClient(PEntry.Client) ~= nil then
				if client == PEntry.Client then
					MOTDClientTracker[i] = nil
					break
				end
			end
		end		
	end

end

DAK:RegisterEventHook("OnClientDisconnect", MOTDOnClientDisconnect, 5, "motd")

local function ProcessRemainingMOTDMessages(deltatime)

	if #MOTDClientTracker > 0 then
		
		for i = 1, #MOTDClientTracker do
			local PEntry = MOTDClientTracker[i]
			if PEntry ~= nil then
				if PEntry.Client ~= nil and DAK:VerifyClient(PEntry.Client) ~= nil then
					if PEntry.Time < Shared.GetTime() then
						MOTDClientTracker[i] = ProcessMessagesforUser(PEntry)
					end
				else
					MOTDClientTracker[i] = nil
				end
			else
				MOTDClientTracker[i] = nil
			end
		end
		if #MOTDClientTracker == 0 then
			DAK:DeregisterEventHook("OnServerUpdate", ProcessRemainingMOTDMessages)
		end
	end
	
end

local function MOTDOnClientConnect(client)

	if client == nil then
		return false
	end
	
	if client:GetIsVirtual() then
		return false
	end
	
	if DAK:VerifyClient(client) == nil then
		return true
	end
	
	if IsAcceptedClient(client) then
		return false
	end
	
	//local player = client:GetControllingPlayer()
	//if player ~= nil and DAK.config.motd.kMOTDOnConnectURL ~= "" then
		//Print("Command sent to client")
		//Server.SendCommand(player, string.format("oneffectdebug SetMenuWebView(%s, function return Vector(Client.GetScreenWidth() * 0.8, Client.GetScreenHeight() * 0.8, 0) end )", DAK.config.motd.kMOTDOnConnectURL))
	//end	
	
	local PEntry = { ID = client:GetUserId(), Client = client, Message = 1, Time = 0 }
	PEntry = ProcessMessagesforUser(PEntry)
	if PEntry ~= nil then
		if #MOTDClientTracker == 0 then
			DAK:RegisterEventHook("OnServerUpdate", ProcessRemainingMOTDMessages, 5, "motd")
		end
		table.insert(MOTDClientTracker, PEntry)
	end
end

DAK:RegisterEventHook("OnClientDelayedConnect", MOTDOnClientConnect, 5, "motd")

local function OnCommandAcceptMOTD(client)

	if client ~= nil then

		if IsAcceptedClient(client) then
			DAK:DisplayMessageToClient(client, "MOTDAlreadyAccepted")
			return
		end
		
		local steamid = client:GetUserId()
		local player = client:GetControllingPlayer()
		local name = "acceptedclient"

		if player ~= nil then
			name = player:GetName()
		end
		
		if tonumber(steamid) == nil then
			return
		end
		
		DAK:DisplayMessageToClient(client, "MOTDAccepted")
		DAK.settings.MOTDAcceptedClients[tostring(steamid)] = DAK.config.motd.kMOTDMessageRevision
		DAK:SaveSettings()
	end
	
end

Event.Hook("Console_acceptmotd",                 OnCommandAcceptMOTD)

local function OnCommandPrintMOTD(client)

	local PEntry = { ID = client:GetUserId(), Client = client, Message = 1, Time = 0 }
	PEntry = ProcessMessagesforUser(PEntry)
	if PEntry ~= nil then
		if #MOTDClientTracker == 0 then
			DAK:RegisterEventHook("OnServerUpdate", ProcessRemainingMOTDMessages, 5, "motd")
		end
		table.insert(MOTDClientTracker, PEntry)
	end
	
end

Event.Hook("Console_printmotd",                 OnCommandPrintMOTD)

DAK:RegisterChatCommand(DAK.config.motd.kAcceptMOTDChatCommands, OnCommandAcceptMOTD, false)
DAK:RegisterChatCommand(DAK.config.motd.kPrintMOTDChatCommands, OnCommandPrintMOTD, false)