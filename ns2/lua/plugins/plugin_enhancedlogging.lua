//NS2 EnhancedLogging and Tracking of events

Script.Load("lua/DAKLoader_Class.lua")

local EnhancedLoggingFile = nil
local lastlogupdate = 0
local pendinglogsave = false
local EnhancedLog = { }

//*******************************************************************************************************************************
//Formatting Functions
//*******************************************************************************************************************************

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

local function GetDateTimeString(logfile)

	local TIMEZONE = 0
	if kDAKConfig.EnhancedLogging.kServerTimeZoneAdjustment then
		TIMEZONE = kDAKConfig.EnhancedLogging.kServerTimeZoneAdjustment
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
	if logfile then
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
		return DateTime
	end
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
	return DateTime
	
end

local function GetTimeStamp()
	return string.format("L " .. string.format(GetDateTimeString(false)) .. " - ")
end

//*******************************************************************************************************************************
//Log Formatting Functions
//*******************************************************************************************************************************

function GetClientUIDString(client)

	if client ~= nil then
		local player = client:GetControllingPlayer()
		local name = "N/A"
		local teamnumber = 0
		if player ~= nil then
			name = player:GetName()
			teamnumber = player:GetTeamNumber()
		end
		return string.format("<%s><%s><%s><%s>", name, ToString(GetGameIdMatchingClient(client)), client:GetUserId(), teamnumber)
	end
	return ""
	
end

local function GetClientIPAddress(client)

	if client ~= nil then
		return string.format(" address %s", IPAddressToString(Server.GetClientAddress(client)))
	end
	return ""
end

local function GetFormattedPositions(attackerOrigin, targetOrigin)
	
	if attackerOrigin ~= nil and targetOrigin ~= nil then
		local attackerx = string.format("%.3f", attackerOrigin.x)
		local attackery = string.format("%.3f", attackerOrigin.y)
		local attackerz = string.format("%.3f", attackerOrigin.z)
		local targetx = string.format("%.3f", targetOrigin.x)
		local targety = string.format("%.3f", targetOrigin.y)
		local targetz = string.format("%.3f", targetOrigin.z)
		return string.format("(attacker_position %f %f %f) (victim_position %f %f %f)", attackerx, attackery, attackerz, targetx, targety, targetz)
		
	end
	
	return ""
end

	
//*******************************************************************************************************************************
//Logging Functions
//*******************************************************************************************************************************

local function SaveEnhancedLog()

	local ELogFile = assert(io.open("config://" .. kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir .. "\\" .. EnhancedLoggingFile, "w"))
	if ELogFile then
		for i = 1, #EnhancedLog do
			ELogFile:write(EnhancedLog[i] .. "\n")
		end
		ELogFile:close()
	end		
	lastlogupdate = Shared.GetTime()
	pendinglogsave = false
	
end

local function UpdateServerEnhancedLogging()
	if pendinglogsave then
		if lastlogupdate + kDAKConfig.EnhancedLogging.kLogWriteDelay < Shared.GetTime() then
			SaveEnhancedLog()
			DAKDeregisterEventHook("kDAKOnServerUpdate", UpdateServerEnhancedLogging)
		end
	end
end

local function PrintToEnhancedLog(logstring)

	if EnhancedLoggingFile == nil and Shared.GetMapName() ~= "" then
		EnhancedLoggingFile = string.format("%s - %s.txt", GetDateTimeString(true), tostring(Shared.GetMapName()))
	end
	table.insert(EnhancedLog, logstring)
	if EnhancedLoggingFile == nil then
		return
	end
	if lastlogupdate + kDAKConfig.EnhancedLogging.kLogWriteDelay < Shared.GetTime() then
		SaveEnhancedLog()
	else
		pendinglogsave = true
		DAKRegisterEventHook("kDAKOnServerUpdate", UpdateServerEnhancedLogging, 5)
	end
	
	//Append doesnt crash atleast now, still doesnt work tho which is prettty meh.
	/*local ELogFile = io.open("config://" .. kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir .. "\\" .. EnhancedLoggingFile, "a+")
	if ELogFile then
		ELogFile:seek("end")
		ELogFile:write(logstring .. "\n")
		ELogFile:close()
	else
		local ELogFile = io.open("config://" .. kDAKConfig.EnhancedLogging.kEnhancedLoggingSubDir .. "\\" .. EnhancedLoggingFile, "w")
		if ELogFile then
			ELogFile:write(logstring .. "\n")
			ELogFile:close()
		end
	end*/

end

function EnhancedLogMessage(message)
	PrintToEnhancedLog(GetTimeStamp() .. message)
end

function EnhancedLoggingAllAdmins(commandname, client, parm1)

	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	local message
	if client ~= nil then
		message = GetTimeStamp() .. GetClientUIDString(client) .. " executed " .. commandname
	else
		message = GetTimeStamp() .. "ServerConsole" .. " executed " .. commandname
	end
	if parm1 ~= nil then
		message = message .. " " .. parm1
	end
	for _, player in ientitylist(playerRecords) do
	
		local playerClient = Server.GetOwner(player)
		if playerClient ~= nil then
			if playerClient ~= client and DAKGetClientCanRunCommand(playerClient, commandname) then
				ServerAdminPrint(playerClient, message)
			end
		end
	
	end
	PrintToEnhancedLog(message)
	Shared.Message(string.format(message))
end

local function LogOnClientConnect(client)

	if client ~= nil then
		//Shared.Message( GetTimeStamp() .. GetClientUIDString(client) .. " connected," .. GetClientIPAddress(client))
		PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. " connected," .. GetClientIPAddress(client))
	end
	
end

DAKRegisterEventHook("kDAKOnClientDelayedConnect", LogOnClientConnect, 5)

local function LogOnClientDisconnect(client)
	local reason = ""
	if client ~= nil then
		if client.disconnectreason ~= nil then
			reason = client.disconnectreason
		end
		//Shared.Message(GetTimeStamp() .. GetClientUIDString(client) .. " disconnected, " .. reason)
		PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. " disconnected, " .. reason)
	end
	
end

DAKRegisterEventHook("kDAKOnClientDisconnect", LogOnClientDisconnect, 5)

function OnCommandSetName(client, name)

	if client ~= nil and name ~= nil then

		local player = client:GetControllingPlayer()

		name = TrimName(name)

		if name ~= player:GetName() and name ~= kDefaultPlayerName and string.len(name) > 0 then
		
			PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. " changed name to " .. name .. ".")
			
			local prevName = player:GetName()
			player:SetName(name)
			if prevName == kDefaultPlayerName then
				Server.Broadcast(nil, string.format("%s connected.", player:GetName()))
			elseif prevName ~= player:GetName() then
				Server.Broadcast(nil, string.format("%s is now known as %s.", prevName, player:GetName()))
			end
			
		end
	
	end

end

Event.Hook("Console_name",               OnCommandSetName)
	
if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.GamerulesExtensions then
		
	local originalNS2CommandStructureLoginPlayer
	
	originalNS2CommandStructureLoginPlayer = Class_ReplaceMethod("CommandStructure", "LoginPlayer", 
		function(self, player)
		
			if player then
				local Client = Server.GetOwner(player)
				local teamNum = self:GetTeamNumber()
				if Client and teamNum then
					PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " logged into commander for team " .. ToString(teamNum))
				end
			end
			originalNS2CommandStructureLoginPlayer( self, player )
		end
	)
	
	local originalNS2CommandStructureLogout
	
	originalNS2CommandStructureLogout = Class_ReplaceMethod("CommandStructure", "Logout", 
		function(self)
		
			local commander = self:GetCommander()
			if commander then
				local Client = Server.GetOwner(commander)
				local teamNum = self:GetTeamNumber()
				if Client and teamNum then
					PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " logged out of commander for team " .. ToString(teamNum))
				end
			end
			originalNS2CommandStructureLogout( self )
		end
	)
	
	local originalNS2RecycleMixinOnResearchComplete
	
	originalNS2RecycleMixinOnResearchComplete = Class_ReplaceMethod("RecycleMixin", "OnResearchComplete", 
		function(self, researchId)
		
			local buildingID = self:GetId()
			local buildingname = self:GetClassName()
			if researchId == kTechId.Recycle then        
				PrintToEnhancedLog(GetTimeStamp() .. buildingname .. " id: " .. ToString(buildingID) .. " was recycled.")
			end
			originalNS2RecycleMixinOnResearchComplete( self, researchId )
		end
	)
	
	local originalNS2RecycleMixinOnResearch
	
	originalNS2RecycleMixinOnResearch = Class_ReplaceMethod("RecycleMixin", "OnResearch", 
		function(self, researchId)
		
			local buildingID = self:GetId()
			local buildingname = self:GetClassName()
			local team = self:GetTeam()
			if team then
				local commander = team:GetCommander()
				if commander then
					local Client = Server.GetOwner(commander)
					if researchId == kTechId.Recycle and Client then        
						PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " started recycle of " .. buildingname .. " id: " .. ToString(buildingID))
					end
				end
			end
			originalNS2RecycleMixinOnResearch( self, researchId )
		end
	)
	
	local originalNS2ConstructMixinOnInitialized
	
	originalNS2ConstructMixinOnInitialized = Class_ReplaceMethod("ConstructMixin", "OnInitialized", 
		function(self)
		
			local buildingID = self:GetId()
			local buildingname = self:GetClassName()
			local team = self:GetTeam()
			if team then
				local owner = self:GetOwner()
				if owner == nil then
					owner = team:GetCommander()
				end
				if owner then
					local Client = Server.GetOwner(owner)
					if researchId == kTechId.Recycle and Client then        
						PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " started construction of " .. buildingname .. " id: " .. ToString(buildingID))
					end
				end
			end
			originalNS2ConstructMixinOnInitialized( self )
		end
	)
	
end

function EnhancedLoggingChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
	if client and steamId and steamId ~= 0 then
		PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(client) .. ConditionalValue(teamOnly, " teamsay ", " say ") .. message)
	else
		PrintToEnhancedLog(GetTimeStamp() .. playerName .. ConditionalValue(teamOnly, " teamsay ", " say ")  .. message)
	end
end

DAKRegisterEventHook("kDAKOnClientChatMessage", EnhancedLoggingChatMessage, 5)

local function EnhancedLoggingSetGameState(self, state, currentstate)

	if state ~= currentstate then
		if state == kGameState.Started then
			local version = ToString(Shared.GetBuildNumber())
			local map = Shared.GetMapName()
			PrintToEnhancedLog(GetTimeStamp() .. "game_started" .. " build " .. version .. " map " .. map)
		end
	end
	
end

DAKRegisterEventHook("kDAKOnSetGameState", EnhancedLoggingSetGameState, 5)

function EnhancedLoggingJoinTeam(self, player, newTeamNumber, force)

	local client = Server.GetOwner(player)
	if client ~= nil then
		PrintToEnhancedLog(GetTimeStamp() .. string.format("%s joined team %s.", GetClientUIDString(client), newTeamNumber))
	end
	
end

DAKRegisterEventHook("kDAKOnTeamJoin", EnhancedLoggingJoinTeam, 5)

function EnhancedLoggingEndGame(self, winningTeam)

	local version = ToString(Shared.GetBuildNumber())
	local winner = ToString(winningTeam:GetTeamType())
	local length = string.format("%.2f", Shared.GetTime() - self.gameStartTime)
	local map = Shared.GetMapName()
	local start_location1 = self.startingLocationNameTeam1
	local start_location2 = self.startingLocationNameTeam2
	PrintToEnhancedLog(GetTimeStamp() .. "game_ended" .. " build " .. version .. " winning_team " .. winner .. " game_length " .. length .. 
		" map " .. map .. " marine_start_loc " .. start_location1 .. " alien_start_loc " .. start_location2)
	
end

DAKRegisterEventHook("kDAKOnGameEnd", EnhancedLoggingEndGame, 5)

function EnhancedLoggingCastVoteByPlayer(self, voteTechId, player)

	if voteTechId == kTechId.VoteDownCommander1 or voteTechId == kTechId.VoteDownCommander2 or voteTechId == kTechId.VoteDownCommander3 then 
		local playerIndex = (voteTechId - kTechId.VoteDownCommander1 + 1)        
		local commanders = GetEntitiesForTeam("Commander", player:GetTeamNumber())
		
		if playerIndex <= table.count(commanders) then
			local targetCommander = commanders[playerIndex]
			if targetCommander ~= nil then
				local targetClient = Server.GetOwner(targetCommander)
				local Client = Server.GetOwner(targetClient)
				if targetClient and Client then
					PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(Client) .. " voted to eject " .. GetClientUIDString(targetClient))
				end
			end
		end
	end
	
end

DAKRegisterEventHook("kDAKOnCastVoteByPlayer", EnhancedLoggingCastVoteByPlayer, 5)

function EnhancedLoggingOnEntityKilled(self, targetEntity, attacker, doer, point, direction)
 
	if attacker and targetEntity and doer then
		local attackerOrigin = attacker:GetOrigin()
		local targetOrigin = targetEntity:GetOrigin()
		local attacker_client = Server.GetOwner(attacker)
		local target_client = Server.GetOwner(targetEntity)
		if target_client == nil and attacker_client == nil then
			PrintToEnhancedLog(GetTimeStamp() .. attacker:GetClassName() .. " killed " .. targetEntity:GetClassName() .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
		elseif target_client == nil then
			PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(attacker_client) .. " killed " .. targetEntity:GetClassName() .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
		elseif attacker_client == nil then
			PrintToEnhancedLog(GetTimeStamp() .. attacker:GetClassName() .. " killed " .. GetClientUIDString(target_client) .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
		else
			PrintToEnhancedLog(GetTimeStamp() .. GetClientUIDString(attacker_client) .. " killed " .. GetClientUIDString(target_client) .. " with " .. doer:GetClassName() .. " at " .. GetFormattedPositions(attackerOrigin, targetOrigin))
		end
	end

end

DAKRegisterEventHook("kDAKOnEntityKilled", EnhancedLoggingOnEntityKilled, 5)