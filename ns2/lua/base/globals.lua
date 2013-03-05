//DAK loader/Base Config

local function GetMonthDaysString(year, days)
	local MDays = { }
	table.insert(MDays, 31) //Jan
	table.insert(MDays, 28) //Feb
	table.insert(MDays, 31) //Mar
	table.insert(MDays, 30) //Apr
	table.insert(MDays, 31) //May
	table.insert(MDays, 30) //Jun
	table.insert(MDays, 31) //Jul
	table.insert(MDays, 31) //Aug
	table.insert(MDays, 30) //Sep
	table.insert(MDays, 31) //Oct
	table.insert(MDays, 30) //Nov
	table.insert(MDays, 31) //Dec
	local tdays = days
	local month = 1
	if math.mod((year - 1972), 4) == 0 then
		MDays[2] = 29
	end
	for i = 1, 12 do
		if tdays <= MDays[i] then
			return month, tdays
		else
			tdays = tdays - MDays[i]
		end
		month = month + 1
	end	
	return month, tdays
end

function DAK:GetDateTimeString(fileformat)

	local TIMEZONE = 0
	if self.config.serveradmin.ServerTimeZoneAdjustment and type(self.config.serveradmin.ServerTimeZoneAdjustment) == "number" then
		TIMEZONE = self.config.serveradmin.ServerTimeZoneAdjustment
	end
	local st = Shared.GetSystemTime() + (TIMEZONE * 3600)
	local DST = 0
	local Days = math.floor(st / 86400)
	local Month = 1
	local Year = math.floor(Days / 365)
	Days = Days - (Year * 365)
	Year = Year + 1970
	Days = Days - math.floor((Year - 1972) / 4)
	//Run once to test DST
	//Year will always be accurate, so just recalc using Days and time and blahblah
	Month, Day = GetMonthDaysString(Year, Days)
	if (Month == 11 and Day <= 2 or Month < 11) and (Month > 3 or Month == 3 and Day >= 10) then
		DST = 1
	end
	//Run again to get real date/time :/
	st = st + (DST * 3600)
	Days = math.floor(st / 86400)
	st = st - (Days * 86400)
	Days = Days - ((Year - 1970) * 365) - math.floor((Year - 1972) / 4)
	Month, Day = GetMonthDaysString(Year, Days)
	local Hours = math.floor(st / 3600)
	st = st - (Hours * 3600)
	Hours = Hours + DST
	local Minutes = math.floor(st / 60)
	st = st - (Minutes * 60)
	local DateTime
	if fileformat then
		DateTime = string.format("%s-%s-%s - ", Month, Day, Year)
		if Hours < 10 then
			DateTime = DateTime .. string.format("0%s", Hours)
		else
			DateTime = DateTime .. string.format("%s", Hours)
		end
		if Minutes < 10 then
			DateTime = DateTime .. string.format("-0%s", Minutes)
		else
			DateTime = DateTime .. string.format("-%s", Minutes)
		end
	else
		DateTime = string.format("%s/%s/%s - ", Month, Day, Year)
		if Hours < 10 then
			DateTime = DateTime .. string.format("0%s", Hours)
		else
			DateTime = DateTime .. string.format("%s", Hours)
		end
		if Minutes < 10 then
			DateTime = DateTime .. string.format(":0%s:", Minutes)
		else
			DateTime = DateTime .. string.format(":%s:", Minutes)
		end
		if st < 10 then
			DateTime = DateTime .. string.format("0%s", st)
		else
			DateTime = DateTime .. string.format("%s", st)
		end
	end
	return DateTime
	
end

function DAK:GetTimeStamp()
	return string.format("L " .. string.format(self:GetDateTimeString(false)) .. " - ")
end

function DAK:RegisterEventHook(functionarray, eventfunction, p)
	//Register Event in Array
	p = tonumber(p)
	if p == nil then p = 5 end
	if self.events[functionarray] == nil then
		self.events[functionarray] = { }
	end
	if functionarray ~= nil and self.events[functionarray] ~= nil then
		table.insert(self.events[functionarray], {func = eventfunction, priority = p})
		table.sort(self.events[functionarray], function(f1, f2) return f1.priority < f2.priority end)
	end
end

function DAK:DeregisterEventHook(functionarray, eventfunction)
	//Remove Event in Array
	if functionarray ~= nil and self.events[functionarray] ~= nil then
		local funcarray = self.events[functionarray]
		for i = 1, #funcarray do
			if funcarray[i].func == eventfunction then
				table.remove(funcarray, i)
				break
			end
		end
	end
end

function DAK:ExecuteEventHooks(event, ...)
	if event ~= nil and self.events[event] ~= nil then
		if #self.events[event] > 0 then
			local funcarray = self.events[event]
			for i = #funcarray, 1, -1 do
				if type(funcarray[i].func) == "function" then
					if funcarray[i].func(...) then return true end
				end
			end
		end
	end
	return false
end

function DAK:ReturnEventArray(event)
	if event ~= nil and self.events[event] ~= nil then
		if #self.events[event] > 0 then
			return self.events[event]
		end
	end
	return nil
end

function DAK:ClearEventHooks(event)
	if event ~= nil then
		self.events[event] = nil
	end
end

function DAK:RetrieveNetworkMessageLocation(netmsg)
	for i = #self.registerednetworkmessages, 1, -1 do
		if self.registerednetworkmessages[i] == netmsg then
			return i
		end
	end
	table.insert(self.registerednetworkmessages, netmsg)
	return #self.registerednetworkmessages
end

function DAK:ReplaceNetworkMessageFunction(netmsg, func)
	if netmsg ~= nil then
		local loc = self:RetrieveNetworkMessageLocation(netmsg)
		self.networkmessagefunctions[loc] = func
		return loc
	end
	return 0
end

function DAK:ExecuteNetworkMessageFunction(loc, ...)
	DAK:ExecuteEventHooks(self.registerednetworkmessages[loc], ...)
	return self.networkmessagefunctions[loc](...)
end

function DAK:RegisterChatCommand(commandstrings, eventfunction, arguments)
	if commandstrings ~= nil and eventfunction ~=nil and type(eventfunction) == "function" then
		table.insert(self.chatcommands, {func = eventfunction, commands = commandstrings, args = arguments or false})
	end
end

function DAK:ExecuteSpecificChatCommand(client, message, chatcommand)
	if chatcommand ~= nil then
		if type(chatcommand.func) == "function" and chatcommand.commands ~= nil then
			for j = #chatcommand.commands, 1, -1 do
				local chatcomm = chatcommand.commands[j]
				if string.upper(string.sub(message, 1, string.len(chatcomm))) == string.upper(chatcomm) then
					if chatcommand.args then
						chatcommand.func(client, string.sub(message, string.len(chatcomm) + 2))
					else
						chatcommand.func(client)
					end
					return true
				end
			end
		end
	end
	return false
end

function DAK:ExecuteChatCommands(client, message)
	if self.chatcommands ~= nil then
		if #self.chatcommands > 0 then
			for i = #self.chatcommands, 1, -1 do
				if self:ExecuteSpecificChatCommand(client, message, self.chatcommands[i]) then
					return true
				end
			end
		end
	end
	return false
end

function DAK:IsPluginEnabled(CheckPlugin)
	for index, plugin in pairs(self.config.loader.PluginsList) do
		if CheckPlugin == plugin then
			return true
		end
	end
	return false
end

function DAK:ExecutePluginGlobalFunction(plugin, func, ...)
	if self:IsPluginEnabled(plugin) then
		return func(...)
	end
	return nil
end

function DAK:UpdateConnectionTimeTracker(client)
	if DAK.settings.connectedclients == nil then
		DAK.settings.connectedclients = { }
	end
	if client ~= nil then
		local steamId = tostring(client:GetUserId())
		if DAK.settings.connectedclients[steamId] == nil then
			DAK.settings.connectedclients[steamId] = Shared.GetSystemTime()
			DAK:SaveSettings()
		end
	end
end

function DAK:RemoveConnectionTimeTracker(client)
	if client ~= nil and self.settings.connectedclients ~= nil then
		local steamId = tostring(client:GetUserId())
		if steamId ~= nil then
			DAK.settings.connectedclients[steamId] = nil
			DAK:SaveSettings()
		end
	end
end

function DAK:GetClientConnectionTime(client)
	if client ~= nil and DAK.settings.connectedclients ~= nil then
		local steamId = tostring(client:GetUserId())
		if steamId ~= nil then
			return math.floor(Shared.GetSystemTime() - DAK.settings.connectedclients[steamId])
		end
	end
	return 0
end

function DAK:PrintToAllAdmins(commandname, client, parm1)

	local message
	if client ~= nil then
		message = self:GetTimeStamp() .. self:GetClientUIDString(client) .. " executed " .. commandname
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
			if playerClient ~= client and self:GetClientCanRunCommand(playerClient, commandname) then
				ServerAdminPrint(playerClient, message)
			end
		end
	end
	
	DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, message)
	
	if client ~= nil then
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
		if playerList[i]:GetTeamNumber() ~= 0 or self:IsPlayerAFK(playerList[i]) then
			table.remove(playerList, i)
		end
	end
	for i = 1, (#playerList) do
		r = math.random(1, #playerList)
		local iplayer = playerList[i]
		playerList[i] = playerList[r]
		playerList[r] = iplayer
	end
	return playerList
	
end

function DAK:GetTournamentMode()
	local OverrideTournamentModes = false
	if RBPSconfig then
		//Gonna do some basic NS2Stats detection here
		OverrideTournamentModes = RBPSconfig.tournamentMode
	end
	if self.settings.TournamentMode == nil then
		self.settings.TournamentMode = false
	end
	return self.settings.TournamentMode or OverrideTournamentModes
end

function DAK:GetFriendlyFire()
	if self.settings.FriendlyFire == nil then
		self.settings.FriendlyFire = false
	end
	return self.settings.FriendlyFire
end

function DAK:AddClientToGameIDs(client)
	if client ~= nil then
		table.insert(self.gameid, client)
	end
end

function DAK:AddClientToGaggedList(client, duration)
	if client ~= nil then
		local steamID = tonumber(client:GetUserId())
		if steamID ~= nil then
			self.gaggedplayers[steamID] = Shared.GetTime() + duration
		end
	end
end

function DAK:RemoveClientFromGaggedList(client)
	if client ~= nil then
		local steamID = tonumber(client:GetUserId())
		if steamID ~= nil then
			self.gaggedplayers[steamID] = nil
		end
	end
end

function DAK:IsClientGagged(client)
	if client ~= nil then
		local steamID = tonumber(client:GetUserId())
		if steamID ~= nil then
			return self.gaggedplayers[steamID] ~= nil and self.gaggedplayers[steamID] > Shared.GetTime()
		end
	end
	return false
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
		return string.format("<%s><%s><%s><%s>", name, ToString(self:GetGameIdMatchingClient(client)), client:GetUserId(), teamnumber)
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

	local player = self:GetPlayerMatchingName(tostring(id))
	if player then
		return player
	else
		local idNum = tonumber(id)
		if idNum then
			return self:GetPlayerMatchingGameId(idNum) or self:GetPlayerMatchingSteamId(idNum)
		end
	end
	
end

function DAK:GetPlayerMatchingGameId(id)

	assert(type(id) == "number")
	if id > 0 and id <= #self.gameid then
		local client = self.gameid[id]
		if client ~= nil and self:VerifyClient(client) ~= nil then
			return client:GetControllingPlayer()
		end
	end
	
	return nil
	
end

function DAK:GetClientMatchingGameId(id)

	assert(type(id) == "number")
	if id > 0 and id <= #self.gameid then
		local client = self.gameid[id]
		if client ~= nil and self:VerifyClient(client) ~= nil then
			return client
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

function DAK:GetGameIdMatchingPlayer(player)
	local client = Server.GetOwner(player)
	return self:GetGameIdMatchingClient(client)
end

function DAK:GetClientMatchingSteamId(steamId)

	assert(type(steamId) == "number")
	
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local plyr = playerList[r]
			local clnt = playerList[r]:GetClient()
			if plyr ~= nil and clnt ~= nil then
				if clnt:GetUserId() == steamId then
					return clnt
				end
			end
		end				
	end
	
	return nil
	
end

function DAK:GetPlayerMatchingSteamId(steamId)

	assert(type(steamId) == "number")
	
	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local plyr = playerList[r]
			local clnt = playerList[r]:GetClient()
			if plyr ~= nil and clnt ~= nil then
				if clnt:GetUserId() == steamId then
					return plyr
				end
			end
		end				
	end
	
	return nil
	
end

function DAK:GetPlayerMatchingName(name)

	assert(type(name) == "string")
	
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

function DAK:ConvertOldBansFormat(bandata)
	local newdata = { }
	if bandata ~= nil then
		for id, entry in pairs(bandata) do
			if entry ~= nil then
				if entry.id ~= nil then
					newdata[entry.id] = { name = entry.name or "Unavailable", reason = entry.reason or "NotProvided", time = entry.time or 0 }
				elseif id ~= nil then
					newdata[id] = { name = entry.name or "Unavailable", reason = entry.reason or "NotProvided", time = entry.time or 0 }
				end			
			end
		end
	end
	return newdata
end