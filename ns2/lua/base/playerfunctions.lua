//DAK loader/Base Config

function DAK:PrintToAllAdmins(commandname, triggeringclient, parm1)

	local message
	if triggeringclient ~= nil then
		message = self:GetTimeStamp() .. self:GetClientUIDString(triggeringclient) .. " executed " .. commandname
	else
		message = self:GetTimeStamp() .. "ServerConsole" .. " executed " .. commandname
	end
	if parm1 ~= nil then
		message = message .. " " .. parm1
	end

	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do

		local playerClient = Server.GetOwner(player)
		if playerClient ~= nil then
			if playerClient ~= triggeringclient and self:GetClientCanRunCommand(playerClient, commandname) then
				ServerAdminPrint(playerClient, message)
			end
		end
	end
	
	DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, message)
	
	if triggeringclient ~= nil then
		Shared.Message(string.format(message))
	end
	
end

function DAK:IsPlayerAFK(player)
	if self:IsPluginEnabled("afkkick") then
		return GetIsPlayerAFK(player)
	elseif player ~= nil and player:GetAFKTime() > 30 then
		return true
	end
	return false
end

function DAK:ShuffledPlayerList()

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for i = #playerList, 1, -1 do
		if playerList[i] ~= nil then
			if playerList[i]:GetTeamNumber() ~= 0 or DAK:IsPlayerAFK(playerList[i]) then
				//table.insert(ShuffleDebug, string.format("Excluding player %s for reason %s", playerList[i]:GetName(), ConditionalValue(playerList[i]:GetTeamNumber() ~= 0,"not in readyroom.", "is afk.")))
				table.remove(playerList, i)
			end
		end
	end
	for i = 1, (#playerList) do
		r = math.random(1, #playerList)
		if i ~= r then
			local iplayer = playerList[i]
			playerList[i] = playerList[r]
			playerList[r] = iplayer
		end
	end
	return playerList
	
end

function DAK:GetClientUIDString(client)

	if client ~= nil then
		local player = client:GetControllingPlayer()
		local name = "N/A"
		local teamnumber = 0
		if player ~= nil then
			name = player:GetName()
			teamnumber = player:GetTeamNumber()
		end
		return string.format("<%s><%s><%s><%s>", name, ToString(self:GetGameIdMatchingClient(client)), GetReadableSteamId(client:GetUserId()), teamnumber)
	end
	return ""
	
end

function DAK:VerifyClient(client)

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local plyr = playerList[r]
			local clnt = playerList[r]:GetClient()
			if plyr ~= nil and clnt ~= nil then
				if client ~= nil and clnt == client then
					return clnt
				end
			end
		end				
	end
	return nil

end

function DAK:GetPlayerMatching(id)
	return self:GetPlayerMatchingName(id) or self:GetPlayerMatchingGameId(id) or self:GetPlayerMatchingSteamId(id)	
end

function DAK:GetPlayerMatchingGameId(id)

	id = tonumber(id)
	if id ~= nil then
		if id > 0 and id <= #self.gameid then
			local client = self.gameid[id]
			if client ~= nil and self:VerifyClient(client) ~= nil then
				return client:GetControllingPlayer()
			end
		end
	end
	
	return nil
	
end

function DAK:GetClientMatchingGameId(id)

	id = tonumber(id)
	if id ~= nil then
		if id > 0 and id <= #self.gameid then
			local client = self.gameid[id]
			if client ~= nil and self:VerifyClient(client) ~= nil then
				return client
			end
		end
	end
	
	return nil
	
end

function DAK:GetGameIdMatchingClient(client)

	if client ~= nil and self:VerifyClient(client) ~= nil then
		for p = 1, #self.gameid do
			if client == self.gameid[p] then
				return p
			end
		end
	end
	
	return 0
end

function DAK:GetNS2IdMatchingClient(client)

	if client ~= nil and self:VerifyClient(client) ~= nil then
		local steamId = client:GetUserId()
		if steamId ~= nil and tonumber(steamId) ~= nil then
			return steamId
		end
	end
	
	return 0
end

function DAK:GetSteamIdMatchingClient(client)

	if client ~= nil and self:VerifyClient(client) ~= nil then
		local steamId = client:GetUserId()
		if steamId ~= nil and tonumber(steamId) ~= nil then
			return GetReadableSteamId(steamId)
		end
	end
	
	return 0
end

function DAK:GetGameIdMatchingPlayer(player)
	local client = Server.GetOwner(player)
	return self:GetGameIdMatchingClient(client)
end

function DAK:GetNS2IdMatchingPlayer(player)
	local client = Server.GetOwner(player)
	return self:GetNS2IdMatchingClient(client)
end

function DAK:GetSteamIdMatchingPlayer(player)
	local client = Server.GetOwner(player)
	return self:GetSteamIdMatchingClient(client)
end

function DAK:GetClientMatchingSteamId(steamId)

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local plyr = playerList[r]
			local clnt = playerList[r]:GetClient()
			if plyr ~= nil and clnt ~= nil then
				if clnt:GetUserId() == tonumber(steamId) or GetReadableSteamId(clnt:GetUserId()) == steamId then
					return clnt
				end
			end
		end				
	end
	
	return nil
	
end

function DAK:GetPlayerMatchingSteamId(steamId)

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local plyr = playerList[r]
			local clnt = playerList[r]:GetClient()
			if plyr ~= nil and clnt ~= nil then
				if clnt:GetUserId() == tonumber(steamId) or GetReadableSteamId(clnt:GetUserId()) == steamId then
					return plyr
				end
			end
		end				
	end
	
	return nil
	
end

function DAK:GetPlayerMatchingName(name)

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local plyr = playerList[r]
			if plyr:GetName() == name then
				return plyr
			end
		end
	end
	
	return nil
	
end