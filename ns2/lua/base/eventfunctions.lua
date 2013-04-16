//Event hooks
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
				if funcarray[i] ~= nil and type(funcarray[i].func) == "function" then
					local address = funcarray[i].func
					local success, result = pcall(funcarray[i].func, ...)
					if not success then
						Shared.Message(string.format("Eventhook ERROR in %s Plugin: %s", funcarray[i].name or "NotProvided", result))
						//Want to prevent wierd error
						if address == funcarray[i].func then
							table.remove(funcarray, i)
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
//End event hooks

//Timed callbacks with arg support
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
//End timed callbacks

//Network Message Override
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
//End Network Message Override

//Chat command functions
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
//End Chat commands

//Block/Replace scripts.
function DAK:OverrideScriptLoad(scripttoreplace, newscript)
	//Register overload.
	self.scriptoverrides[scripttoreplace] = newscript or true
end

//Update Client Connection Time Tracker
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

//Client GameID tracking
function DAK:AddClientToGameIDs(client)
	if client ~= nil then
		table.insert(self.gameid, client)
	end
end

//Client Gag tracking
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