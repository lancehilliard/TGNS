local PAGE_SIZE = 25
local md = TGNSMessageDisplayer.Create("HELP")
local histories = {}

local getBoundaryIndexes = function(pageNumber)
	local lastIndexToShow = PAGE_SIZE * pageNumber
	local firstIndexToShow = lastIndexToShow - (PAGE_SIZE - 1)
	return firstIndexToShow, lastIndexToShow
end

local commandsAppearOnPage = function(totalCommandsCount, pageNumber)
	local firstIndexToShow, lastIndexToShow = getBoundaryIndexes(pageNumber)
	local result = firstIndexToShow <= totalCommandsCount
	return result
end

local commandAppearsOnPage = function(index, pageNumber)
	local lastIndexToShow = PAGE_SIZE * pageNumber
	local firstIndexToShow = lastIndexToShow - (PAGE_SIZE - 1)
	local result = index >= firstIndexToShow and index <= lastIndexToShow
	return result
end

local Plugin = {}

function Plugin:CreateCommands()
	local helpCommand = self:BindCommand("sh_help", nil, function(client, search)
		local commandNames = {}
		TGNS.DoForPairs(Shine.Commands, function(commandName, commandData)
			if Shine:GetPermission(client, commandName) and not (commandName == "sh_help" or commandName == "sh_helplist") then
				if search == nil or TGNS.Contains(commandName, search) then
					table.insert(commandNames, commandName)
				end
			end
		end)
		TGNS.SortAscending(commandNames)
		local history = histories[client] or {}
		local pageNumber = tostring(history.search) == tostring(search) and (history.pageNumber or 0) + 1 or 1
		pageNumber = commandsAppearOnPage(#commandNames, pageNumber) and pageNumber or 1
		Shared.Message("pageNumber: " .. tostring(pageNumber))
		Shared.Message("search: " .. tostring(search))
		local firstIndexToShow, lastIndexToShow = getBoundaryIndexes(pageNumber)
		firstIndexToShow = firstIndexToShow <= #commandNames and firstIndexToShow or #commandNames
		lastIndexToShow = lastIndexToShow <= #commandNames and lastIndexToShow or #commandNames
		md:ToClientConsole(client, "Available commands (" .. firstIndexToShow .. "-" .. lastIndexToShow .. "; " .. #commandNames .. " total)" .. (search == nil and "" or " matching \"" .. search .. "\"") .. ":")
		TGNS.DoFor(commandNames, function(commandName, index)
			if commandAppearsOnPage(index, pageNumber) then
				local command = Shine.Commands[commandName]
				local helpLine = string.format("%s. %s%s: %s", index, commandName, (type(command.ChatCmd) == "string" and string.format(" (chat: !%s)", command.ChatCmd) or ""), command.Help or "No help available.")
				md:ToClientConsole(client, helpLine)
			end
		end)
		histories[client] = { search = search, pageNumber = pageNumber }
		local endMessage = ""
		if commandsAppearOnPage(#commandNames, pageNumber + 1) then
			endMessage = "There are more commands! Re-issue the \"sh_help" .. (search == nil and "" or (" " .. search)) .. "\" command to view them. "
			md:ToClientConsole(client, endMessage)
		end
		md:ToClientConsole(client, "Forums: http://rr.tacticalgamer.com/Community")
	end, true)
	helpCommand:AddParam{ Type = "string", TakeRestofLine = true, Optional = true }
	helpCommand:Help("<searchText> View help info for available commands (omit <searchText> to see all).")
end

function Plugin:Initialise()
	self.Enabled = true
	self:CreateCommands()
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("help", Plugin )