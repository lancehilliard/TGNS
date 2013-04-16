//DAK loader/Base Config

local FunctionMessageTag = "#*DAK"

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

//Old/New Database conversion formulas.  'New' format uses a NS2ID indexed system, for faster lookups.  Currently the 'New' format is only used in memory, Bans are still saved in old format
//to preserve backwards compatibility.
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

//Executes a function on the client
function DAK:ExecuteFunctionOnClient(client, functionstring)
	local kMaxPrintLength = 128
	if string.len(FunctionMessageTag .. functionstring) > kMaxPrintLength then
		//Message too long.
		return false
	elseif not DAK:DoesClientHaveClientSideMenus(client) then
		//Client doesnt have client side portion
		return false
	else
		Server.SendNetworkMessage(client, "ServerAdminPrint", { message = string.sub(FunctionMessageTag .. functionstring, 0, kMaxPrintLength) }, true)	
		return true
	end
end