--[[
	This acts as a spoof for the TGNS abstractions that delegate
	to Shine and/or NS2 to acquire information about the state of
	the game. This holds the bare data values that can be editted
	by the testing suite to affect the state of the game from the
	viewpoint of the extensions that are being tested. 
	
	This file expects both TGNSCommonShared and TGNSCommonServer s
	to be loaded first, so the functions that don't need to be edited
	can be changed there without the change being made here.
]]

TGNS = TGNS or {}
TGNS.HIGHEST_EVENT_HANDLER_PRIORITY = -20
TGNS.VERY_HIGH_EVENT_HANDLER_PRIORITY = -10
TGNS.NORMAL_EVENT_HANDLER_PRIORITY = 0
TGNS.VERY_LOW_EVENT_HANDLER_PRIORITY = 10
TGNS.LOWEST_EVENT_HANDLER_PRIORITY = 20

TGNS.ENDGAME_TIME_TO_READYROOM = 8

-- TGNSCommonShared

--- Contains all of the registered network messages. 
-- Set up such that __NetworkMessages[messageName] contains a table
-- of variable names, with the special variable callbacks as a table
-- of functions.
-- @usage __NetworkMessages[messageName].variableName
local __NetworkMessages = {}

--- Contains all of the registered event hooks, which act
-- as a way to tie a function to a string without modifying
-- global scope. This is done as a table of event names, with
-- each event name having at least one index non-nil between
-- LOWEST_EVENT_HANDLER_PRIORITY and HIGHEST_EVENT_HANDLER_PRIORITY.
-- That index is an array of functions, non nill, indexs are 1-based.
-- @usage __EventHooks['OnUse'][VERY_HIGH_EVENT_HANDLER_PRIORITY][1] Gets
-- 		the first event hook registered to 'OnUse' with very high priority.
local __EventHooks = {}


local __CPUStartTime = os.clock()
local __LastMapChange = __CPUStartTime

function TGNS.PrintInfo(message)
	print(message)
end

function TGNS.RegisterNetworkMessage(messageName, variables)
	assert.falsy(__NetworkMessages[messageName])
	variables = variables or {}
	__NetworkMessages[messageName] = variables
end

function TGNS.HookNetworkMessage(messageName, callback)
	assert.truthy(__NetworkMessages[messageName])
	__NetworkMessages[messageName].callbacks = __NetworkMessages[messageName].callbacks or {}
	
	-- This is an ugly way to find the first index after (and including) 1 that 
	-- is nil
	local index = 1
	while __NetworkMessages[messageName].callbacks[index] ~= nil do
		index = index + 1
	end
	
	__NetworkMessages[messageName].callbacks[index] = callback
end

function TGNS.RegisterEventHook(eventName, handler, priority) 
	priority = priority or TGNS.NORMAL_EVENT_HANDLER_PRIORITY
	
	__EventHooks[eventName] = __EventHooks[eventName] or {}
	__EventHooks[eventName][priority] = __EventHooks[eventName][priority] or {}
	__EventHooks[eventName][priority][#__EventHooks[eventName][priority] + 1] = handler
end

function TGNS.ExecuteEventHook(eventName, ...)
	assert.is_not.same(nil, __EventHooks[eventName])
	arg.n = nil
	for priority = TGNS.HIGHEST_EVENT_HANDLER_PRIORITY, TGNS.LOWEST_EVENT_HANDLER_PRIORITY do
		if __EventHooks[eventName][priority] then
			local ind = 1
			while __EventHooks[eventName][priority][ind] ~= nil do
				__EventHooks[eventName][priority][ind](arg)
				ind = ind + 1
			end
		end
	end
end

function TGNS.GetSecondsSinceMapLoaded() 
    return __LastMapChange - os.clock()
end

function TGNS.GetSecondsSinceServerProcessStarted()
	return __CPUStartTime - os.clock()
end

local MONTH_STRING_TABLE = {
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"June",
	"July",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec"
}

local WDAY_STRING_TABLE = {
	"Sun",
	"Mon",
	"Tue",
	"Thu",
	"Fri",
	"Sat",
	"Sun"
}
function TGNS.GetCurrentDateTimeAsGmtString()
	local gmtFormat = "%s, %d %s %d %d:%d:%d GMT"
	local d = os.date('*t')
	local result = string.format(gmtFormat, 
									WDAY_STRING_TABLE[d.wday], 
									d.day, 
									MONTH_STRING_TABLE[d.month], 
									d.year,
									d.hour,
									d.min,
									d.sec
								)
	return result
end

function TGNS.GetSecondsSinceEpoch()
	return os.clock()
end

function TGNS.GetHttpAsync(url, callback)
	-- luasocket might be the best for this
	-- GitHub\TGNS\mods\tgns\output\lua\shine\extensions\modupdatednotice.lua (1 hits)
	-- Line 55: 			TGNS.GetHttpAsync(url, function(response)
	-- GitHub\TGNS\mods\tgns\output\lua\tgns\server\TGNSNs2StatsProxy.lua (1 hits)
	-- Line 26: 			TGNS.GetHttpAsync(fetchUrl, function(response) processResponse(steamId, response) end)
	-- GitHub\TGNS\mods\tgns\output\lua\tgns\shared\TGNSCommonShared.lua (1 hits)
	-- Line 90: function TGNS.GetHttpAsync(url, callback)
	error("Not implemented yet")
end

-- TGNSCommonShared Debug Methods

function TGNS.CallNetworkMessage(messageName, ...)
	assert.truthy(__NetworkMessages[messageName])
	arg.n = nil
	local Callbacks = __NetworkMessages[messageName].callbacks or {}
	local i = 1
	while Callbacks[i] ~= nil do
		Callbacks[i](arg)
		i = i + 1
	end
end

function TGNS.RemoveNetworkMessage(messageName)
	__NetworkMessages[messageName] = nil
end

function TGNS.SetLastMapChange(cpuTime)
    __LastMapChange = cpuTime
end