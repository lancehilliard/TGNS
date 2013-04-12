//DAK loader/Base Config

local ShuffleDebug = { }
local ConfirmationMenus

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

/// Event hooks

function DAK:RegisterEventHook(functionarray, eventfunction, p, pluginname)
	//Register Event in Array
	p = tonumber(p)
	if p == nil then p = 5 end
	if self.events[functionarray] == nil then
		self.events[functionarray] = { }
	end
	if functionarray ~= nil and self.events[functionarray] ~= nil then
		table.insert(self.events[functionarray], {func = eventfunction, priority = p, name = pluginname})
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
	if event ~= nil and self.events[event] ~= nil and DAK.enabled then
		if #self.events[event] > 0 then
			local funcarray = self.events[event]
			for i = #funcarray, 1, -1 do
				if type(funcarray[i].func) == "function" then
					local address = funcarray[i].func
					local success, result = pcall(funcarray[i].func, ...)
					if not success then
						Shared.Message(string.format("Eventhook ERROR in %s Plugin: %s", funcarray[i].name or "NotProvided", result))
						//Want to prevent wierd error
						if address == funcarray[i].func then
							funcarray[i] = nil
						end
					else
						if result then return true end
					end
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

/// End event hooks

/// Timed callbacks with arg support

function DAK:SetupTimedCallBack(callfunc, calltime, ...)
	if callfunc ~= nil and tonumber(calltime) ~= nil then
		local callback = {func = callfunc, when = (Shared.GetTime() + tonumber(calltime)), args = arg, lastinterval = tonumber(calltime)}
		table.insert(self.timedcalledbacks, callback)
		return true
	end
	return false
end

function DAK:UpdateTimedCallBackArgs(callfunc, ...)
	for i = #self.timedcalledbacks, 1, -1 do
		if self.timedcalledbacks[i] ~= nil then
			if self.timedcalledbacks[i].func == callfunc then
				self.timedcalledbacks[i].args = arg
			end
		end
	end
end

function DAK:ProcessTimedCallBacks()
	for i = #self.timedcalledbacks, 1, -1 do
		if self.timedcalledbacks[i] ~= nil then
			if type(self.timedcalledbacks[i].func) == "function" and self.timedcalledbacks[i].when < Shared.GetTime() then
				local success, result = pcall(self.timedcalledbacks[i].func, unpack(self.timedcalledbacks[i].args or { }))
				if not success then
					Shared.Message(string.format("Callback ERROR: %s", result))
					self.timedcalledbacks[i] = nil
				else
					if result == nil or result == false then
						self.timedcalledbacks[i] = nil
					elseif result == true then
						self.timedcalledbacks[i].when = Shared.GetTime() + self.timedcalledbacks[i].lastinterval
					elseif tonumber(result) ~= nil then
						self.timedcalledbacks[i].when = Shared.GetTime() + tonumber(result)
						self.timedcalledbacks[i].lastinterval = tonumber(result)
					end
				end
			end
		end
	end
end

/// End timed callbacks

/// Main menu functions
//These define what is displayed in the main DAK menu.  Other plugins can still create and manage their own menus outside this.
//This menu is more for basic configuration, issuing of basic commands and functions.
//.name = 
//.validforclient
//.selectionfunction

function DAK:GetMainMenuItemByName(friendlyname, list)
	for i, menuitem in pairs(list or DAK.activemenuitems) do
		if menuitem.fname == friendlyname then
			return menuitem
		end
	end
	return nil
end

function DAK:GetMainMenuItemByNumber(index, list)
	if list ~= nil and #list <= index then
		return list[index]
	elseif #DAK.activemenuitems <= index then
		return DAK.activemenuitems[index]
	end
	return nil
end

function DAK:RegisterMainMenuItem(friendlyname, clientvalidation, selectfunction)
	if friendlyname ~= nil and DAK:GetMainMenuItemByName(friendlyname) == nil then
		local menuitem = {fname = friendlyname, validate = clientvalidation, selectfunc = selectfunction}
		table.insert(DAK.activemenuitems, menuitem)
		return true
	else
		return false
	end
end

function DAK:ValidateMenuOptionForClient(menuitem, client)
	if type(menuitem.validate) == "function" then
		return menuitem.validate(client)
	else
		return menuitem.validate == true
	end
end

function DAK:GetMenuItemsList(client)
	local relevantitems = { }
	for i, menuitem in pairs(DAK.activemenuitems) do
		if DAK:ValidateMenuOptionForClient(menuitem, client) then
			table.insert(relevantitems, menuitem)
		end
	end
	return relevantitems
end

function DAK:UpdateClientMainMenu(steamId, LastUpdateMessage, page)
	local MenuUpdateMessage = DAK:CreateMenuBaseNetworkMessage()
	if MenuUpdateMessage == nil then
		MenuUpdateMessage = { }
	end
	local client = DAK:GetClientMatchingSteamId(steamId)
	if client == nil then
		return LastUpdateMessage
	end
	MenuUpdateMessage.header = string.format("DAK Mod Menu")
	i = 1
	for i, menuitem in pairs(DAK:GetMenuItemsList(client)) do
		local ci = i - (page * 8)
		if ci > 0 and ci < 9 then
			MenuUpdateMessage.option[ci] = menuitem.fname
		end
		i = i + 1
	end
	MenuUpdateMessage.footer = "Press a number key to select that option."
	MenuUpdateMessage.inputallowed = true
	return MenuUpdateMessage
end

function DAK:SelectMainMenuItem(client, selecteditem, page)
	//Validate selection to prevent BS
	local menuitem = DAK:GetMainMenuItemByNumber(selecteditem + (page * 8), DAK:GetMenuItemsList(client))
	if menuitem ~= nil then
		if DAK:ValidateMenuOptionForClient(menuitem, client) then
			menuitem.selectfunc(client)
			return true
		end
	end
end

/// End Menu Functions

/// Confirmation Menu Functions
// These are really just a small extension to allow easy confirm/deny menus

local function UpdateConfirmationMenuHook(steamId, LastUpdateMessage, page)
	return DAK:UpdateConfirmationMenu(steamId, LastUpdateMessage, page)
end

local function SelectConfirmationMenuItemHook(client, selecteditem, page)
	return DAK:SelectConfirmationMenuItem(client, selecteditem, page)
end

function DAK:DisplayConfirmationMenuItem(steamId, HeadingText, ConfirmationFunction, DenyFunction, ...)
	if steamId ~= nil then
		local menuitem = {heading = HeadingText, confirmfunc = ConfirmationFunction, denyfunc = DenyFunction, args = arg}
		ConfirmationMenus[steamId] = menuitem
		DAK:CreateGUIMenuBase(steamid, SelectConfirmationMenuItemHook, UpdateConfirmationMenuHook, true)
	end
end

function DAK:UpdateConfirmationMenu(steamId, LastUpdateMessage, page)
	if ConfirmationMenus[steamId] ~= nil then
		local MenuUpdateMessage = DAK:CreateMenuBaseNetworkMessage()
		if MenuUpdateMessage == nil then
			MenuUpdateMessage = { }
		end
		MenuUpdateMessage.header = ConfirmationMenus[steamId].heading
		kVoteUpdateMessage.option[1] = "Confirm"
		kVoteUpdateMessage.option[2] = "Deny"
		MenuUpdateMessage.footer = "Press a number key to select that option."
		MenuUpdateMessage.inputallowed = true
		return MenuUpdateMessage
	else
		return LastUpdateMessage
	end
end

function DAK:SelectConfirmationMenuItem(client, selecteditem, page)
	if client ~= nil then
		local steamId = client:GetUserId()
		if ConfirmationMenus[steamId] ~= nil then
			if selecteditem == 1 and ConfirmationMenus[steamId].confirmfunc ~= nil and type(ConfirmationMenus[steamId].confirmfunc) == "function" then
				ConfirmationMenus[steamId].confirmfunc(client, unpack(ConfirmationMenus[steamId].args or { }))
			elseif selecteditem == 2 and ConfirmationMenus[steamId].denyfunc ~= nil and type(ConfirmationMenus[steamId].denyfunc) == "function" then
				ConfirmationMenus[steamId].denyfunc(client, unpack(ConfirmationMenus[steamId].args or { }))
			end
			ConfirmationMenus[steamId] = nil
		end
		return true
	end
end

/// End Confirmation Menus

/// Network Message Override

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

/// End Network Message Override

/// Chat command functions

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

/// End Chat commands

function DAK:OverrideScriptLoad(scripttoreplace, newscript)
	//Register overload.
	self.scriptoverrides[scripttoreplace] = newscript or true
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
		local steamId = tonumber(client:GetUserId())
		if DAK.settings.connectedclients[steamId] == nil or tonumber(DAK.settings.connectedclients[steamId]) == nil then
			DAK.settings.connectedclients[steamId] = Shared.GetSystemTime()
		end
	end
end

function DAK:RemoveConnectionTimeTracker(client)
	if client ~= nil and self.settings.connectedclients ~= nil then
		local steamId = tonumber(client:GetUserId())
		if steamId ~= nil then
			DAK.settings.connectedclients[steamId] = nil
		end
	end
end

function DAK:GetClientConnectionTime(client)
	if client ~= nil and DAK.settings.connectedclients ~= nil then
		local steamId = tonumber(client:GetUserId())
		if steamId ~= nil then
			if DAK.settings.connectedclients[steamId] ~= nil and tonumber(DAK.settings.connectedclients[steamId]) ~= nil then
				return math.floor(Shared.GetSystemTime() - DAK.settings.connectedclients[steamId])
			else
				//This shouldnt happen, but I think somehow it is :/
				DAK.settings.connectedclients[steamId] = Shared.GetSystemTime()
				return 0
			end
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
		if playerList[i] ~= nil then
			if playerList[i]:GetTeamNumber() ~= 0 or DAK:IsPlayerAFK(playerList[i]) then
				table.insert(ShuffleDebug, string.format("Excluding player %s for reason %s", playerList[i]:GetName(), ConditionalValue(playerList[i]:GetTeamNumber() ~= 0,"not in readyroom.", "is afk.")))
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

function DAK:ConvertFromOldBansFormat(bandata)
	local newdata = { }
	if bandata ~= nil then
		for id, entry in pairs(bandata) do
			if entry ~= nil then
				if entry.id ~= nil then
					newdata[tonumber(entry.id)] = { name = entry.name or "Unknown", reason = entry.reason or "NotProvided", time = entry.time or 0 }
				elseif id ~= nil then
					newdata[tonumber(id)] = { name = entry.name or "Unknown", reason = entry.reason or "NotProvided", time = entry.time or 0 }
				end			
			end
		end
	end
	return newdata
end

function DAK:ConvertToOldBansFormat(bandata)
	local newdata = { }
	if bandata ~= nil then
		for id, entry in pairs(bandata) do
			if entry ~= nil then
				if entry.id ~= nil then
					entry.id = tonumber(entry.id)
					table.insert(newdata, entry)
				elseif id ~= nil then
					local bentry = { id = tonumber(id), name = entry.name or "Unknown", reason = entry.reason or "NotProvided", time = entry.time or 0 }
					table.insert(newdata, bentry)
				end			
			end
		end
	end
	return newdata
end

function DAK:DisplayLegacyChatMessageToClientWithoutMenus(client, messageId, ...)
	if client ~= nil and not client:GetIsVirtual() and not DAK:DoesClientHaveClientSideMenus(client) then
		DAK:DisplayMessageToClient(client, messageId, ...)
	end
end

function DAK:DisplayLegacyChatMessageToAllClientWithoutMenus(messageId, ...)
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		local client = Server.GetOwner(player)
		if client ~= nil and not client:GetIsVirtual() and not DAK:DoesClientHaveClientSideMenus(client) then
			DAK:DisplayMessageToClient(client, messageId, ...)
		end
	end
end

function DAK:DisplayLegacyChatMessageToTeamClientsWithoutMenus(teamnum, messageId, ...)
	if tonumber(teamnum) ~= nil then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			local client = Server.GetOwner(player)
			if client ~= nil and not client:GetIsVirtual() and not DAK:DoesClientHaveClientSideMenus(client) then
				DAK:DisplayMessageToClient(client, messageId, ...)
			end
		end
	end
end

function DAK:DoesSteamIDHaveClientSideMenus(steamId)
	if steamId ~= nil and tonumber(steamId) ~= nil then
		return DAK.activemoddedclients[tonumber(steamId)]
	end
	return false
end

function DAK:DoesClientHaveClientSideMenus(client)
	if client ~= nil then
		return DAK:DoesSteamIDHaveClientSideMenus(client:GetUserId())
	end
	return false
end

function DAK:DoesPlayerHaveClientSideMenus(client)
	if player ~= nil then
		return DAK:DoesClientHaveClientSideMenus(Server.GetOwner(player))
	end
end

function DAK:CreateGUIMenuBase(id, OnMenuFunction, OnMenuUpdateFunction, override)

	if id == nil or id == 0 or tonumber(id) == nil or not DAK:DoesSteamIDHaveClientSideMenus(id) or not DAK.config.loader.AllowClientMenus then return false end
	for i = #DAK.runningmenus, 1, -1 do
		if DAK.runningmenus[i] ~= nil and DAK.runningmenus[i].clientSteamId == id then
			if override then
				DAK.runningmenus[i] = nil
			else
				return false
			end
		end
	end
	
	local GameMenu = {UpdateTime = math.max(Shared.GetTime() - 2, 0), MenuFunction = OnMenuFunction, MenuUpdateFunction = OnMenuUpdateFunction,
						MenuBaseUpdateMessage = nil, clientSteamId = id, activepage = 0}
	table.insert(DAK.runningmenus, GameMenu)
	return true
	
end

function DAK:CreateMenuBaseNetworkMessage()
	local kVoteUpdateMessage = { }
	kVoteUpdateMessage.header = ""
	kVoteUpdateMessage.option = { }
	kVoteUpdateMessage.option[1] = ""
	kVoteUpdateMessage.option[2] = ""
	kVoteUpdateMessage.option[3] = ""
	kVoteUpdateMessage.option[4] = ""
	kVoteUpdateMessage.option[5] = ""
	kVoteUpdateMessage.option[6] = ""
	kVoteUpdateMessage.option[7] = ""
	kVoteUpdateMessage.option[8] = ""
	kVoteUpdateMessage.option[9] = ""
	kVoteUpdateMessage.option[10] = ""
	kVoteUpdateMessage.footer = ""
	kVoteUpdateMessage.inputallowed = false
	kVoteUpdateMessage.menutime = Shared.GetTime()
	return kVoteUpdateMessage
end

function DAK:PrintShuffledPlayerDebugData(client)
	for i = 1, #ShuffleDebug do
		ServerAdminPrint(client, ShuffleDebug[i])
	end
	ShuffleDebug = { }
end