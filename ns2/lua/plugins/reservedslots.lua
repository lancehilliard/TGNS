//NS2 Reserved Slot

local ReservedPlayers = { }
local disconnectclients = { }
local lastpasswordupdate = 0
local lastdisconnect = 0
local reserveslotactionslog = { }
local serverlockstatus = false

local ReservedPlayersFileName = "config://ReservedPlayers.json"

local function LoadReservedPlayers()
	ReservedPlayers = DAK:LoadConfigFile(ReservedPlayersFileName) or { }
end

LoadReservedPlayers()

local function SaveReservedPlayers()
	DAK:SaveConfigFile(reservedPlayersFileName, ReservedPlayers)
end

local function DisconnectClientForReserveSlot(client)
	Server.DisconnectClient(client)	
end

local function GetPlayerList()

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	return playerList
	
end

local function CheckReserveStatus(client, silent)

	if client:GetIsVirtual() then
		//Bots dont get reserve slot
		return false
	end
	
	if DAK:GetClientCanRunCommand(client, "sv_hasreserve") then
		if not silent then 
			table.insert(reserveslotactionslog, "Reserved Slot Entry For - id: " .. tostring(client:GetUserId()) .. " - Is Valid") 
			ServerAdminPrint(client, "Reserved Slot Entry For - id: " .. tostring(client:GetUserId()) .. " - Is Valid")
		end
		return true
	end
	
	for r = #ReservedPlayers, 1, -1 do
		local ReservePlayer = ReservedPlayers[r]
		local UserId = client:GetUserId()
		
		if ReservePlayer.id == UserId then
			// Check if enough time has passed on a temporary reserve slot.
			if not silent then table.insert(reserveslotactionslog, "Reserve Slot check for " .. tostring(ReservePlayer.name) .. " - id: " .. tostring(ReservePlayer.id)) end
			local now = Shared.GetSystemTime()
			if ReservePlayer.time ~= 0 and now > ReservePlayer.time then
				if not silent then ServerAdminPrint(client, "Reserved Slot Entry For " .. tostring(ReservePlayer.name) .. " - id: " .. tostring(ReservePlayer.id) .. " - Has Expired") end
				return false
			else
				if not silent then ServerAdminPrint(client, "Reserved Slot Entry For " .. tostring(ReservePlayer.name) .. " - id: " .. tostring(ReservePlayer.id) .. " - Is Valid") end
				return true
			end
		end	
	end
end

local function CheckOccupiedReserveSlots()
	//check for current number of occupied reserveslots
	local reserveCount = 0
	local playerList = GetPlayerList()
	for r = #playerList, 1, -1 do
		if playerList[r] ~= nil then
			local plyr = playerList[r]
			local clnt = playerList[r]:GetClient()
			if plyr ~= nil and clnt ~= nil then
				if CheckReserveStatus(clnt, true) then
					reserveCount = reserveCount + 1
				end
			end
			if reserveCount >= DAK.config.reservedslots.kReservedSlots then
				reserveCount = DAK.config.reservedslots.kReservedSlots
				break
			end
		end
	end
	return reserveCount
end

local function UpdateServerLockStatus()
	if DAK.config.reservedslots.kReservePassword ~= "" then
		local MaxPlayers = Server.GetMaxPlayers()
		local CurPlayers = Server.GetNumPlayers()
		if MaxPlayers - (CurPlayers - CheckOccupiedReserveSlots()) <= (DAK.config.reservedslots.kReservedSlots + DAK.config.reservedslots.kMinimumSlots) then
			if not serverlockstatus then
				table.insert(reserveslotactionslog, string.format("Locking Server at %s of %s players at %s.", CurPlayers, MaxPlayers, DAK:GetDateTimeString(false)))
			end
			Server.SetPassword(DAK.config.reservedslots.kReservePassword)
			serverlockstatus = true
		elseif MaxPlayers - (CurPlayers - CheckOccupiedReserveSlots()) > (DAK.config.reservedslots.kReservedSlots + DAK.config.reservedslots.kMinimumSlots) then
			if serverlockstatus then
				table.insert(reserveslotactionslog, string.format("Unlocking Server at %s of %s players at %s.", CurPlayers, MaxPlayers, DAK:GetDateTimeString(false)))
			end
			Server.SetPassword("")
			serverlockstatus = false
		end
	end
end

local function CheckReserveSlotSync()
	
	if #disconnectclients > 0 then
		for r = #disconnectclients, 1, -1 do
			if disconnectclients[r] ~= nil and DAK:VerifyClient(disconnectclients[r].clnt) ~= nil and disconnectclients[r].disctime < Shared.GetTime() then
				DisconnectClientForReserveSlot(disconnectclients[r].clnt)
				disconnectclients[r] = nil
			end
		end
	end
	
	if lastdisconnect ~= 0 and Shared.GetTime() > lastdisconnect then
		UpdateServerLockStatus()
		lastdisconnect = 0
	end
	
	if (Shared.GetTime() - lastpasswordupdate) >= 10 then
		UpdateServerLockStatus()
		lastpasswordupdate = Shared.GetTime()
	end
	
end

DAK:RegisterEventHook("OnServerUpdate", CheckReserveSlotSync, 5, "reserveslots")

local function OnReserveSlotClientConnected(client)

	local MaxPlayers = Server.GetMaxPlayers()
	local CurPlayers = Server.GetNumPlayers()
	
	local serverFull = MaxPlayers - (CurPlayers - CheckOccupiedReserveSlots()) < (DAK.config.reservedslots.kReservedSlots + DAK.config.reservedslots.kMinimumSlots)
	local serverReallyFull = MaxPlayers - CurPlayers < DAK.config.reservedslots.kMinimumSlots
	local reserved = CheckReserveStatus(client, false)

	UpdateServerLockStatus()
	
	if serverFull and not reserved then
	
		DAK:DisplayMessageToClient(client, "ReserveSlotServerFull")
		table.insert(reserveslotactionslog, "Kicking player "  .. tostring(client:GetUserId()) .. " for no reserve slot.")
		DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, "Kicking player "  .. tostring(client:GetUserId()) .. " for no reserve slot.")
		client.disconnectreason = DAK.config.reservedslots.kReserveSlotServerFullDisconnectReason
		table.insert(disconnectclients, {clnt = client, disctime = Shared.GetTime() + DAK.config.reservedslots.kDelayedKickTime})
		return true
		
	end
	if serverReallyFull and reserved then

		local playertokick
		local connectiontime = 0
		local playerList = GetPlayerList()
				
		for r = #playerList, 1, -1 do
			if playerList[r] ~= nil then
				local plyr = playerList[r]
				local clnt = playerList[r]:GetClient()
				if plyr ~= nil and clnt ~= nil then
					local clntconntime = DAK:GetClientConnectionTime(clnt)
					if (clntconntime <= connectiontime or connectiontime == 0) and not plyr:GetIsCommander() and not CheckReserveStatus(clnt, true) then
						connectiontime = clntconntime
						playertokick = plyr
					end
				end
			end
		end

		if playertokick ~= nil then

			table.insert(reserveslotactionslog, "Kicking player "  .. tostring(playertokick.name) .. " - id: " .. tostring(playertokick:GetClient():GetUserId()) .. " with connection time: " .. tostring(connectiontime))
			DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, "Kicking player "  .. tostring(playertokick.name) .. " - id: " .. tostring(playertokick:GetClient():GetUserId()) .. " with connection time: " .. tostring(connectiontime))
			DAK:DisplayMessageToClient(playertokick:GetClient(), "ReserveSlotKickedForRoom")
			playertokick.disconnectreason = "Kicked due to a reserved slot."
			table.insert(disconnectclients, {clnt = playertokick:GetClient(), disctime = Shared.GetTime() + DAK.config.reservedslots.kDelayedKickTime})
		else
			table.insert(reserveslotactionslog, "Attempted to kick player but no valid player could be located")
			DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, "Attempted to kick player but no valid player could be located")
		end

	end
	
end

DAK:RegisterEventHook("OnClientConnect", OnReserveSlotClientConnected, 6, "reserveslots")

local function ReserveSlotClientDisconnect(client)    
	lastdisconnect = Shared.GetTime() + DAK.config.reservedslots.kDelayedSyncTime
end

DAK:RegisterEventHook("OnClientDisconnect", ReserveSlotClientDisconnect, 5, "reserveslots")

local function AddReservePlayer(client, parm1, parm2, parm3, parm4)

	local idNum = tonumber(parm2)
	local exptime = tonumber(parm4)
	if parm1 and idNum then
		local ReservePlayer = { name = ToString(parm1), id = idNum, reason = ToString(parm3 or ""), time = ConditionalValue(exptime, exptime, 0) }
		table.insert(ReservedPlayers, ReservePlayer)
		DAK:PrintToAllAdmins("sv_addreserve", client, ToString(parm1) .. ToString(parm2) .. ToString(parm3) .. ToString(parm4))
		if client ~= nil then
			DAK:DisplayMessageToClient(client, "ReserveSlotGranted", ToString(parm2))
		end
	end
	SaveReservedPlayers()
end

DAK:CreateServerAdminCommand("Console_sv_addreserve", AddReservePlayer, "<name> <id> <reason> <time> Will add a reserve player to the list.")

local function DebugReserveSlots(client)

	if client ~= nil then
		for r = 1, #reserveslotactionslog, 1 do
			if reserveslotactionslog[r] ~= nil then
				ServerAdminPrint(client, reserveslotactionslog[r])
			end
		end
	else
		for r = 1, #reserveslotactionslog, 1 do
			if reserveslotactionslog[r] ~= nil then
				Shared.Message(reserveslotactionslog[r])
			end
		end
	end

end

DAK:CreateServerAdminCommand("Console_sv_reservedebug", DebugReserveSlots, "Will print messages logged during actions taken by reserve slot plugin.")