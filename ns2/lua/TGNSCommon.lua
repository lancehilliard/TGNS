// TGNS Common

TGNS = {}

function TGNS:PlayerIsOnWinningTeam(player)
	local result = not player:GetTeam():GetHasTeamLost() // mlh as of build 237, PlayingTeam.lua's GetHasTeamWon() unconditionally returns false
	return result
end

function TGNS:IsGameStartingState(gameState)
	local result = gameState == kGameState.Started
	return result
end

function TGNS:IsGameWinningState(gameState)
	local result = gameState == kGameState.Team1Won or gameState == kGameState.Team2Won
	return result
end

function TGNS:IsGameplayTeam(teamNumber)
	local result = teamNumber == kMarineTeamType or teamNumber == kAlienTeamType
	return result
end

function TGNS:GetTeamName(teamNumber)
	local result
	if teamNumber == kTeamReadyRoom then
		result = "Ready Room"
	elseif teamNumber == kMarineTeamType then
		result = "Marines"
	elseif teamNumber == kAlienTeamType then
		result = "Aliens"
	elseif teamNumber == kSpectatorIndex then
		result = "Spectator"
	end
	return result
end

function TGNS:IsPlayerSpectator(player)
	local result = player:GetTeamNumber() == kSpectatorIndex
	return result
end

function TGNS:GetNumericValueOrZero(countable)
	local result = countable == nil and 0 or countable
	return result
end

function TGNS:GetClientName(client)
	local result = client:GetControllingPlayer():GetName()
	return result
end
function TGNS:DoFor(elements, elementAction)
	for i = 1, #elements, 1 do
		elementAction(elements[i])
	end
end

function TGNS:IsClientCommander(client)
	local result = false
	if client ~= nil then
		local player = client:GetControllingPlayer()
		if player ~= nil then
			result = player:GetIsCommander()
		end
	end
	return result	
end

function TGNS:HasClientSignedPrimer(client)
	local result = not client:GetIsVirtual() and DAKGetClientCanRunCommand(client, "sv_hasprimersignature")
	return result
end

function TGNS:IsClientSM(client)
	local result = not client:GetIsVirtual() and DAKGetClientCanRunCommand(client, "sv_hassupportingmembership")
	return result
end

function TGNS:IsClientStranger(client)
	local result = not self:IsClientSM(client) and not self:HasClientSignedPrimer(client)
	return result
end

function TGNS:ClientAction(player, action)
	local client = player:GetClient()
	return action(client)
end

function TGNS:ConsolePrint(client, message, prefix)
	if client ~= nil then
		prefix = prefix == nil and "TGNS" or prefix
		ServerAdminPrint(client, "[" .. prefix .. "] " .. message)
	end
end

function TGNS:GetClientSteamId(client)
	result = client:GetUserId()
	return result
end

function TGNS:GetDataFilename(dataType, steamId)
	local result = string.format("config://%s/%s.json", dataType, steamId)
	return result
end

function TGNS:GetClientNameSteamIdCombo(client)
	local result = string.format("%s (%s)", self:GetClientName(client), self:GetClientSteamId(client))
	return result	
end

function TGNS:SendChatMessage(player, chatMessage)
	if player ~= nil then
		chatMessage = string.sub(chatMessage, 1, kMaxChatLength)
		Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
	end
end

function TGNS:DisconnectClient(client, reason)
		client.disconnectreason = reason
		Server.DisconnectClient(client)
end

function TGNS:GetPlayerList()

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
	return playerList

end

function TGNS:GetPlayerCount() 
	local result = #self:GetPlayerList()
	return result
end

function TGNS:AllPlayers(doThis)

	return function(client)
	
		local playerList = self:GetPlayerList()
		for p = 1, #playerList do
		
			local player = playerList[p]
			doThis(player, client, p)
			
		end
		
	end
	
end

function TGNS:Has(elements, element)
	local found = false
	for i = 1, #elements, 1 do
		if not found and elements[i] == element then
			found = true
		end
	end
	return found
end

function TGNS:GetPlayer(client)
	local result = client:GetControllingPlayer()
	return result
end

function TGNS:GetPlayers(clients)
	local result = {}
	for i = 1, #clients, 1 do
		result.insert(client:GetControllingPlayer())
	end
	return result
end

function TGNS:GetMatchingClients(predicate, playerList)
	local result = {}
	playerList = playerList == nil and self:GetPlayerList() or playerList
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local client = playerList[r]:GetClient()
			if client ~= nil then
				if predicate(client, playerList[r]) then
					table.insert(result, client)
				end
			end
		end
	end
	return result
end

function TGNS:GetPlayingClients(playerList)
	local result = TGNS:GetMatchingClients(function(c,p) return self:IsGameplayTeam(p:GetTeamNumber()) end, playerList)
	return result
end

function TGNS:GetLastMatchingClient(predicate, playerList)
	local result = nil
	local playerList = playerList == nil and self:GetPlayerList() or playerList
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local client = playerList[r]:GetClient()
			if client ~= nil then
				if predicate(client, playerList[r]) then
					result = client
				end
			end
		end
	end
	return result
end

function TGNS:GetTeamClients(teamNumber, playerList)
	local predicate = function(client, player) return player:GetTeamNumber() == teamNumber end
	local result = self:GetMatchingClients(predicate, playerList)
	return result
end

function TGNS:GetStrangersClients(playerList)
	local predicate = function(client, player) return self:IsClientStranger(client) end
	local result = self:GetMatchingClients(predicate, playerList)
	return result
end

function TGNS:IsPrimerOnlyClient(client)
	local result = self:HasClientSignedPrimer(client) and not self:IsClientSM(client)
	return result
end

function TGNS:GetPrimerOnlyClients(playerList)
	local predicate = function(client, player) return self:IsPrimerOnlyClient(client) end
	local result = self:GetMatchingClients(predicate, playerList)
	return result
end

function TGNS:GetSmClients(playerList)
	local predicate = function(client, player) return self:IsClientSM(client) end
	local result = self:GetMatchingClients(predicate, playerList)
	return result
end

function TGNS:KickClient(client, chatMessage, disconnectReason, onPreKick)
	if client ~= nil then
		local player = client:GetControllingPlayer()
		if player ~= nil then
			if onPreKick ~= nil then
				onPreKick(client, player)
			end
			TGNS:SendChatMessage(player, chatMessage)
		end
		TGNS:DisconnectClient(client, disconnectReason)
	end
end

function TGNS:KickPlayer(player, chatMessage, disconnectReason, onPreKick)
	if player ~= nil then
		self:KickClient(player:GetClient(), chatMessage, disconnectReason, onPreKick)
	end
end

function TGNS:GetPlayerMatchingName(name, team)

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
	self:AllPlayers(Matches)()
	
	if nameMatchCount > 1 then
		match = nil // if partial match is not unique, clear the match
	end
	
	return match

end

function TGNS:GetPlayerMatchingSteamId(steamId, team)

	assert(type(steamId) == "number")
	
	local match = nil
	
	local function Matches(player)
	
		local playerClient = Server.GetOwner(player)
		if playerClient and playerClient:GetUserId() == steamId then
			if team == nil or team == -1 or team == player:GetTeamNumber() then
				match = player
			end
		end
		
	end
	self:AllPlayers(Matches)()
	
	return match

end

function TGNS:GetPlayerMatching(id, team)

	local idNum = tonumber(id)
	if idNum then
		// note: using DAK's GetPlayerMatchingGameId
		return GetPlayerMatchingGameId(idNum, team) or self:GetPlayerMatchingSteamId(idNum, team)
	elseif type(id) == "string" then
		return self:GetPlayerMatchingName(id, team)
	end

end

if kDAKConfig and kDAKConfig.DAKLoader then

	// Returns:	builtChatMessage - a ChatMessage object
	//			consoleChatMessage - a similarly formed string for printing to the console
	function TGNS:BuildPMChatMessage(srcClient, message, command, showCommand)
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
		builtChatMessage = BuildChatMessage(false, chatName, -1, kTeamReadyRoom, kNeutralTeamType, message)
		return builtChatMessage, consoleChatMessage
	end
	
	function TGNS:PMAllPlayersWithAccess(srcClient, message, command, showCommand, selfIfNoAccess)
		builtChatMessage, consoleChatMessage = self:BuildPMChatMessage(srcClient, message, command, showCommand)
		for _, player in pairs(self:GetPlayerList()) do
			local client = Server.GetOwner(player)
			if client ~= nil then
				if DAKGetClientCanRunCommand(client, command) or (selfIfNoAccess and client == srcClient) then
					Server.SendNetworkMessage(player, "Chat", builtChatMessage, true)
					ServerAdminPrint(client, consoleChatMessage)
				end
			end
		end
	end
end

////////////////////
// Intercept Chat //
////////////////////

kTGNSChatHooks = {}

function TGNS:RegisterChatHook(func)
	DAKRegisterEventHook(kTGNSChatHooks, func, 1)
end

local originalOnChatReceived

local function OnChatReceived(client, message)
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