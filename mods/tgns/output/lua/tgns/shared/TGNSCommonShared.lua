TGNS = TGNS or {}

TGNS.HIGHEST_EVENT_HANDLER_PRIORITY = -20
TGNS.VERY_HIGH_EVENT_HANDLER_PRIORITY = -10
TGNS.NORMAL_EVENT_HANDLER_PRIORITY = 0
TGNS.VERY_LOW_EVENT_HANDLER_PRIORITY = 10
TGNS.LOWEST_EVENT_HANDLER_PRIORITY = 20

TGNS.ENDGAME_TIME_TO_READYROOM = 8

function TGNS.GetRandomizedElements(elements)
	local result = {}
	TGNS.DoFor(elements, function(e) table.insert(result, e) end)
	TGNS.Shuffle(result)
	return result
end

function TGNS.Shuffle(elements)
	table.Shuffle(elements)
end

function TGNS.PrintInfo(message)
	Shared.Message(message)
end

function TGNS.RegisterNetworkMessage(messageName, variables)
	variables = variables or {}
	Shared.RegisterNetworkMessage(messageName, variables)
end

function TGNS.HookNetworkMessage(messageName, callback)
	if Server then
		Server.HookNetworkMessage(messageName, callback)
	elseif Client then
		Client.HookNetworkMessage(messageName, callback)
	end
end

function TGNS.RegisterEventHook(eventName, handler, priority)
	priority = priority or TGNS.NORMAL_EVENT_HANDLER_PRIORITY
	local stackInfo = debug.getinfo(2)
	local whereDidTheRegistrationOriginate = string.format("%s:%s", stackInfo.short_src, stackInfo.linedefined)
	Shine.Hook.Add(eventName, whereDidTheRegistrationOriginate, handler, priority)
end

function TGNS.ExecuteEventHooks(eventName, ...)
	Shine.Hook.Call(eventName, ... )
end

function TGNS.GetSecondsSinceMapLoaded()
	local result = Shared.GetTime()
	return result
end

function TGNS.GetSecondsSinceServerProcessStarted()
	local result = Shared.GetSystemTimeReal()
	return result
end

function TGNS.GetCurrentDateTimeAsGmtString()
	local result = Shared.GetGMTString(false)
	return result
end

function TGNS.GetSecondsSinceEpoch()
	local result = Shared.GetSystemTime()
	return result
end

function TGNS.GetHttpAsync(url, callback)
	Shared.SendHTTPRequest(url, "GET", callback)
end

function TGNS.GetCurrentMapName()
	local result = Shared.GetMapName()
	return result
end

function TGNS.EnhancedLog(message)
	Shine:LogString(message)
	Shared.Message(message)
end

function TGNS.HasNonEmptyValue(stringValue)
	local result = stringValue ~= nil and stringValue ~= ""
	return result
end

function TGNS.DoForPairs(t, pairAction)
	if t ~= nil then
		local index = 1
		for key, value in pairs(t) do
			if value ~= nil and pairAction(key, value, index) then break end
			index = index + 1
		end
	end
end

local function DoFor(elements, elementAction, start, stop, step)
	for index = start, stop, step do
		local element = elements[index]
		if element ~= nil then
			if elementAction(element, index) then
				break
			end
		end
	end
end

function TGNS.DoFor(elements, elementAction)
	if elements ~= nil then
		DoFor(elements, elementAction, 1, #elements, 1)
	end
end

function TGNS.DoForReverse(elements, elementAction)
	if elements ~= nil then
		DoFor(elements, elementAction, #elements, 1, -1)
	end
end