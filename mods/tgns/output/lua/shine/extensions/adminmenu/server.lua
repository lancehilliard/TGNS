local commandInProgress = {}
local currentPage = {}

local rememberArgs = function(client, commandName, argName, argValue)
	commandInProgress[client] = commandInProgress[client] or {}
	commandInProgress[client][commandName] = commandInProgress[client][commandName] or {}
	commandInProgress[client][commandName][argName] = argValue
end

local getArgs = function(client, commandName, args)
	local result = ""
	TGNS.DoFor(args, function(arg)
		result = result .. commandInProgress[client][commandName][arg.name] .. " "
	end)
	return result
end

function Plugin:ClientConfirmConnect(client)
	TGNS.ScheduleAction(2, function()
		TGNS.DoForPairs(self.Config, function(pageName, pageData)
			TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), self.MAIN_BUTTONS_REQUESTED, {buttonText=pageName, pageName=pageName})
		end)
	end)
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.HookNetworkMessage(self.ADMIN_MENU_REQUESTED, function(client, message)
		local responsePageId = "Main"
		local responsePageName = "Main"
		local responseButtons = {}
		local responseArg = {}
		local chatCmd = ""
		local requestCommandName = message.commandIndex
		if requestCommandName == 0 then
			requestCommandName = ""
		else
			TGNS.DoForPairs(self.Config[currentPage[client]].Commands, function(commandName, commandData, index)
				if requestCommandName == index then
					requestCommandName = commandName
					return true
				end
			end)
		end
		local requestArgName = message.argName
		local requestArgValue = message.argValue
		rememberArgs(client, requestCommandName, requestArgName, requestArgValue)
		local requestCommand
		TGNS.DoForPairs(self.Config, function(pageName, pageData)
			local command = pageData.Commands[requestCommandName]
			if command then
				requestCommand = command
			end
		end)
		local responseBackPageId = "Main"
		if requestCommand then
			local command = Shine.Commands[requestCommandName]
			chatCmd = type(command.ChatCmd) == "string" and command.ChatCmd or ""
			responseBackPageId = currentPage[client]
			TGNS.DoForReverse(requestCommand.args, function(arg)
				if arg.name == requestArgName then
					responseBackPageId = currentPage[client] .. requestCommandName .. requestArgName
					return true
				end
				responseArg = arg
			end)
			if responseArg.name then
				responsePageId = currentPage[client] .. requestCommandName .. responseArg.name
				responsePageName = requestCommandName
				local buttonOptions = type(responseArg.options) == "string" and loadstring("return " .. responseArg.options)() or responseArg.options
				TGNS.DoFor(buttonOptions, function(option)
					local responseButton = {c=message.commandIndex, n=option.name}
					if (option.value) then
						responseButton.v = option.value
					end
					table.insert(responseButtons, responseButton)
				end)
			else
				responseBackPageId = nil
				TGNS.ExecuteClientCommand(client, string.format("%s %s", requestCommandName, getArgs(client, requestCommandName, requestCommand.args)))
			end
		else
			local immediateCommandName = nil
			TGNS.DoForPairs(self.Config[requestArgName].Commands, function(commandName, commandData, index)
				if Shine:GetPermission(client, commandName) then
					if commandData.immediate == true then
						immediateCommandName = commandName
						return true
					else
						table.insert(responseButtons, {c=index, n=commandName})
					end
				end
			end)
			if TGNS.HasNonEmptyValue(immediateCommandName) then
				responseBackPageId = nil
				TGNS.ExecuteClientCommand(client, immediateCommandName)
			else
				TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), self.HELP_TEXT, {pageName=requestArgName, helpText=self.Config[requestArgName].HelpText})
				responsePageId = requestArgName
				responsePageName = requestArgName
				currentPage[client] = requestArgName
			end
		end
		TGNS.SortAscending(responseButtons, function(b) return b.n end)
		local buttonsJson = json.encode(responseButtons)
		TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), self.MENU_DATA, {commandIndex=message.commandIndex, argName=responseArg.name or "", pageId=responsePageId, pageName=responsePageName, backPageId=responseBackPageId or "", chatCmd=chatCmd, buttonsJson=buttonsJson})
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end