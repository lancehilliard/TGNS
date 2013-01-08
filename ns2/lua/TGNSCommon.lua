// TGNS Common

function GetPlayerList()

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
	return playerList

end

function AllPlayers(doThis)

	return function(client)
	
		local playerList = GetPlayerList()
		for p = 1, #playerList do
		
			local player = playerList[p]
			doThis(player, client, p)
			
		end
		
	end
	
end

function GetPlayerMatchingName(name, team)

	assert(type(name) == "string")
	
	local nameMatchCount = 0
	local match = nil
	
	local function Matches(player)
		if nameMatchCount == -1 then
			return // exact match found, skip others to avoid further partial matches
		end
		local playerName =  player:GetName()
		if player:GetName() == name then // exact match
			if team == nil or team == -1 or team == player:GetTeamNumber() then
				match = player
				nameMatchCount = -1
			end
		else
			local index = string.find(string.lower(playerName), string.lower(name)) // case insensitive partial match
			if index ~= nil then
				if team == nil or team == -1 or team == player:GetTeamNumber() then
					match = player
					nameMatchCount = nameMatchCount + 1
				end
			end
		end
		
	end
	AllPlayers(Matches)()
	
	if nameMatchCount > 1 then
		match = nil // if partial match is not unique, clear the match
	end
	
	return match

end

function GetPlayerMatching(id, team)

	local idNum = tonumber(id)
	if idNum then
		return GetPlayerMatchingGameId(idNum, team) or GetPlayerMatchingSteamId(idNum, team)
	elseif type(id) == "string" then
		return GetPlayerMatchingName(id, team)
	end

end


if kDAKConfig and kDAKConfig.DAKLoader then
	function PMAllPlayersWithAccess(srcClient, message, command, showCommand)
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
end

////////////////////
// Intercept Chat //
////////////////////

kTGNSChatHooks = {}

function TGNSRegisterChatHook(func)
	DAKRegisterEventHook(kTGNSChatHooks, func, 1)
end

local originalOnChatReceived

local function OnChatReceived(client, message)
	Print("TGNS OnChatReceived")
	if #kTGNSChatHooks > 0 then
		for i = #kTGNSChatHooks, 1, -1 do
			if kTGNSChatHooks[i].func(client, message.message) then
				return
			end
		end
	end
	originalOnChatReceived(client, message)
end

local originalHookNetworkMessage = Server.HookNetworkMessage

Server.HookNetworkMessage = function(networkMessage, callback)
	if networkMessage == "ChatClient" then
		Print("Hook ChatClient network message")
		originalOnChatReceived = callback
		callback = OnChatReceived
	end
	originalHookNetworkMessage(networkMessage, callback)

end