TGNS = TGNS or {}

TGNS.HIGHEST_EVENT_HANDLER_PRIORITY = -20
TGNS.VERY_HIGH_EVENT_HANDLER_PRIORITY = -10
TGNS.NORMAL_EVENT_HANDLER_PRIORITY = 0
TGNS.VERY_LOW_EVENT_HANDLER_PRIORITY = 10
TGNS.LOWEST_EVENT_HANDLER_PRIORITY = 20

TGNS.ENDGAME_TIME_TO_READYROOM = 8

TGNS.MARINE_COLOR_R = 0.302
TGNS.MARINE_COLOR_G = 219.045
TGNS.MARINE_COLOR_B = 255
TGNS.ALIEN_COLOR_R = 255
TGNS.ALIEN_COLOR_G = 201.96
TGNS.ALIEN_COLOR_B = 57.885

TGNS.READYROOM_LOCATION_ID = 1000

TGNS.ShineTextAlignmentMin = 0
TGNS.ShineTextAlignmentCenter = 1
TGNS.ShineTextAlignmentMax = 2

function TGNS.ReplaceClassMethod(className, methodName, method)
	return Shine.ReplaceClassMethod(className, methodName, method)
end

function TGNS.GetTeamRgb(teamNumber)
	local r, g, b
	if teamNumber == kMarineTeamType or teamNumber == kAlienTeamType then
		r = teamNumber == kMarineTeamType and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
		g = teamNumber == kMarineTeamType and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
		b = teamNumber == kMarineTeamType and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
	else
		r = 255
		g = 255
		b = 255
	end
	return {R=r,G=g,B=b}
end

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
	elseif Predict then
		Predict.HookNetworkMessage(messageName, callback)
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

function TGNS.GetCurrentMapName()
	local result = Shared.GetMapName()
	return result
end

function TGNS.EnhancedLog(message)
	Shine:LogString(message)
	Shared.Message(message)
end

function TGNS.IndexOf(s, part)
	return s:find(part) or -1
end

function TGNS.Contains(s, part)
	return TGNS.IndexOf(s, part) >= 1
end

function TGNS.Replace(original, pattern, replace)
	local result = string.gsub(original, pattern, replace)
	return result
end

function TGNS.HasNonEmptyValue(stringValue)
	local result = stringValue ~= nil and stringValue ~= ""
	return result
end

function TGNS.DoTimes(count, action)
	for i=1,count do
		action(i)
	end
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

function TGNS.ConvertSecondsToMinutes(seconds)
	local result = seconds / 60
	return result
end

function TGNS.ConvertMinutesToSeconds(minutes)
	local result = minutes * 60
	return result
end

function TGNS.ConvertHoursToSeconds(hours)
	local result = TGNS.ConvertMinutesToSeconds(hours * 60)
	return result
end

function TGNS.ConvertDaysToSeconds(days)
	local result = TGNS.ConvertHoursToSeconds(days * 24)
	return result
end

function TGNS.Join(list, delimiter)
	local result = ""
	TGNS.DoFor(list, function(item, index)
		result = string.format("%s%s%s", result, index > 1 and delimiter or "", item)
	end)
	return result
end

function TGNS.Split(d,p)
  local t, ll
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+1 -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

function TGNS.Has(elements, element)
	local result = TGNS.Any(elements, function(e) return element == e end)
	return result
end

function TGNS.IsProduction()
	local result
	if Server then
		result = TGNS.Has({"8v8", "Taunt","Chuckle"}, TGNS.GetSimpleServerName())
	else
		result = TGNS.Contains(Client.GetConnectedServerName(), "Taunt") or TGNS.Contains(Client.GetConnectedServerName(), "Chuckle") or TGNS.Contains(Client.GetConnectedServerName(), "8v8")
	end
	return result
end

function TGNS.RemoveAll(elements)
	TGNS.DoForReverse(elements, function(e, index)
		table.remove(elements, index)
	end)
end

function TGNS.TableReverse(elements)
	local temp = {}
	TGNS.DoFor(elements, function(e) table.insert(temp, e) end)
	TGNS.RemoveAll(elements)
	TGNS.DoForReverse(temp, function(e) table.insert(elements, e) end)
end

function TGNS.SortDescending(elements, sortFunction)
	TGNS.SortAscending(elements, sortFunction)
	TGNS.TableReverse(elements)
end

function TGNS.SortAscending(elements, sortFunction)
	sortFunction = sortFunction or function(x) return x end
	table.sort(elements, function(e1, e2)
		return sortFunction(e1) < sortFunction(e2)
	end)
end

function TGNS.RemoveAllWhere(elements, predicate)
	TGNS.DoForReverse(elements, function(e, index)
		if predicate == nil or predicate(e) then
			table.remove(elements, index)
		end
	end)
end

function TGNS.TableValueCount(tt, item)
	local result = 0
	TGNS.DoForPairs(tt, function(key, value)
		if item == value then
			result = result + 1
		end
	end)
	return result
end

function TGNS.TableKeyCount(tt)
	local result = 0
	TGNS.DoForPairs(tt, function(key, value)
		result = result + 1
	end)
	return result
end

function TGNS.GetUniqueTableValues(tt)
	local result = {}
	TGNS.DoForPairs(tt, function(key, value)
		if TGNS.TableValueCount(result, value) == 0 then
			result[#result+1] = value
		end
	end)
	return result
end

function TGNS.GetUniqueTableKeys(tt)
	local result = {}
	TGNS.DoForPairs(tt, function(key, value)
		if TGNS.TableValueCount(result, key) == 0 then
			result[#result+1] = key
		end
	end)
	return result
end

function TGNS.StartsWith(s,part)
   return string.sub(s,1,string.len(part))==part
end

function TGNS.EndsWith(s, part)
	return #s >= #part and s:find(part, #s-#part+1, true) and true or false
end

function TGNS.Substring(s, startIndex, length)
	local endIndex = length ~= nil and startIndex + length - 1 or nil
	local result = string.sub(s, startIndex, endIndex)
	return result
end

function TGNS.Truncate(s, length)
	local result = TGNS.Substring(s, 1, length)
	return result
end

function TGNS.ToLower(s)
	local result = string.lower(s)
	return result
end

function TGNS.ToUpper(s)
	local result = string.upper(s)
	return result
end

function TGNS.SeparateThousands(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

function TGNS.UrlEncode(str) PROFILE("TGNS.UrlEncode")
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

function TGNS.PrintTable(t, tableDescription, printAction) PROFILE("TGNS.PrintTable")
	printAction = printAction and printAction or function(x) Shared.Message(x) end
	local keys = {}
	for key,value in pairs(t) do table.insert(keys, key) end
	TGNS.SortAscending(keys, function(k) return tostring(k) end)
	TGNS.DoFor(keys, function(k)
		printAction(string.format("%s.%s: %s", tableDescription, k, t[k]))
	end)
end