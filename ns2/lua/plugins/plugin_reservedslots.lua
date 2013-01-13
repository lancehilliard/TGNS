//NS2 Reserved Slot

if kDAKConfig and kDAKConfig.ReservedSlots then

	local ReservedPlayers = { }
	local lastconnect = 0
	local lastdisconnect = 0
	local disconnectclients = { }
	local disconnectclienttime = 0
	local reserveslotactionslog = { }

	local ReservedPlayersFileName = "config://ReservedPlayers.json"

	local function LoadReservedPlayers()
		local ReservedPlayersFile = io.open(ReservedPlayersFileName, "r")
		if ReservedPlayersFile then
			Shared.Message("Loading Reserve slot players.")
			ReservedPlayers = json.decode(ReservedPlayersFile:read("*all"))
			ReservedPlayersFile:close()
		end
	end
	
	LoadReservedPlayers()

	local function SaveReservedPlayers()

		local ReservedPlayersFile = io.open(reservedPlayersFileName, "w+")
		ReservedPlayersFile:write(json.encode(ReservedPlayers, { indent = true, level = 1 }))
		ReservedPlayersFile:close()
		
	end
	
	local function DisconnectClientForReserveSlot(client)

		Server.DisconnectClient(client)
		lastdisconnect = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedSyncTime
		
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
		
		if DAKGetClientCanRunCommand(client, "sv_hasreserve") then
			if not silent then ServerAdminPrint(client, "Reserved Slot Entry For - id: " .. tostring(client:GetUserId()) .. " - Is Valid") end
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
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		for r = #playerList, 1, -1 do
			if playerList[r] ~= nil then
				local plyr = playerList[r]
				local clnt = playerList[r]:GetClient()
				if plyr ~= nil and clnt ~= nil then
					if CheckReserveStatus(clnt, true) then
						reserveCount = reserveCount + 1
					end
				end
				if reserveCount >= kDAKConfig.ReservedSlots.kReservedSlots then
					break
				end
			end
		end
		return reserveCount
	end
	
	local function UpdateServerLockStatus()
		if kDAKConfig.ReservedSlots.kReservePassword ~= "" then
			local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
			if kDAKConfig.ReservedSlots.kMaximumSlots - (#playerList - CheckOccupiedReserveSlots()) <= (kDAKConfig.ReservedSlots.kReservedSlots + kDAKConfig.ReservedSlots.kMinimumSlots) then
				Server.SetPassword(kDAKConfig.ReservedSlots.kReservePassword)
			else
				Server.SetPassword("")
			end
		end
	end

	local function OnReserveSlotClientConnected(client)
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		local serverFull = kDAKConfig.ReservedSlots.kMaximumSlots - (#playerList - CheckOccupiedReserveSlots()) < (kDAKConfig.ReservedSlots.kReservedSlots + kDAKConfig.ReservedSlots.kMinimumSlots)
		local serverReallyFull = kDAKConfig.ReservedSlots.kMaximumSlots - #playerList < kDAKConfig.ReservedSlots.kMinimumSlots
		local reserved = CheckReserveStatus(client, false)

		UpdateServerLockStatus()
		
		if serverFull and not reserved then
		
			DAKDisplayMessageToClient(client, "kReserveSlotServerFull")
			local player = client:GetControllingPlayer()
			if player ~= nil then
				table.insert(reserveslotactionslog, "Kicking player "  .. tostring(player.name) .. " - id: " .. tostring(client:GetUserId()) .. " for no reserve slot.")
				EnhancedLog("Kicking player "  .. tostring(player.name) .. " - id: " .. tostring(client:GetUserId()) .. " for no reserve slot.")
			end
			client.disconnectreason = kDAKConfig.ReservedSlots.kReserveSlotServerFullDisconnectReason
			table.insert(disconnectclients, client)
			disconnectclienttime = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedKickTime
			return true
		end
		if serverReallyFull and reserved then

			local playertokick
			local lowestscore = 9999

			for r = #playerList, 1, -1 do
				if playerList[r] ~= nil then
					local plyr = playerList[r]
					local clnt = playerList[r]:GetClient()
					if plyr ~= nil and clnt ~= nil then
						if plyr.score == nil then
							plyr.score = 0
						end

						if (plyr.score <= lowestscore) and not plyr:GetIsCommander() and not CheckReserveStatus(clnt, true) then
							lowestscore = plyr.score
							playertokick = plyr
						end
					end
				end
			end

			if playertokick ~= nil then

				table.insert(reserveslotactionslog, "Kicking player "  .. tostring(playertokick.name) .. " - id: " .. tostring(playertokick:GetClient():GetUserId()) .. " with score: " .. tostring(playertokick.score))
				EnhancedLog("Kicking player "  .. tostring(playertokick.name) .. " - id: " .. tostring(playertokick:GetClient():GetUserId()) .. " with score: " .. tostring(playertokick.score))
				DAKDisplayMessageToClient(playertokick:GetClient(), "kReserveSlotKickedForRoom")
				playertokick.disconnectreason = kDAKConfig.ReservedSlots.kReserveSlotKickedDisconnectReason
				table.insert(disconnectclients, playertokick:GetClient())
				disconnectclienttime = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedKickTime
			else
				table.insert(reserveslotactionslog, "Attempted to kick player but no valid player could be located")
				EnhancedLog("Attempted to kick player but no valid player could be located")
			end

		end
		lastconnect = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedSyncTime
		
	end
	
	DAKRegisterEventHook(kDAKOnClientConnect, OnReserveSlotClientConnected, 6)

	local function ReserveSlotClientDisconnect(client)    
	
		lastdisconnect = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedSyncTime
		
	end
	
	DAKRegisterEventHook(kDAKOnClientDisconnect, ReserveSlotClientDisconnect, 5)

	local function CheckReserveSlotSync()

		PROFILE("ReserveSlots:CheckReserveSlotSync")

		if #disconnectclients > 0 and disconnectclienttime < Shared.GetTime() then
			for r = #disconnectclients, 1, -1 do
				if disconnectclients[r] ~= nil and VerifyClient(disconnectclients[r]) ~= nil then
					DisconnectClientForReserveSlot(disconnectclients[r])
				end
			end
			disconnectclients = { }
			disconnectclienttime = 0
		end

		if lastconnect ~= 0 or lastdisconnect ~= 0 then
			if (lastconnect >= lastdisconnect and lastconnect < Shared.GetTime()) or (lastdisconnect >= lastconnect and lastdisconnect < Shared.GetTime()) then
				lastconnect = 0
				lastdisconnect = 0
				UpdateServerLockStatus()
			end
		end
		
	end

	DAKRegisterEventHook(kDAKOnServerUpdate, CheckReserveSlotSync, 5)

	local function AddReservePlayer(client, parm1, parm2, parm3, parm4)

		local idNum = tonumber(parm2)
		local exptime = tonumber(parm4)
		if client ~= nil and parm1 and idNum then
			local ReservePlayer = { name = ToString(parm1), id = idNum, reason = ToString(parm3 or ""), time = ConditionalValue(exptime, exptime, 0) }
			table.insert(ReservedPlayers, ReservePlayer)
			PrintToAllAdmins("sv_addreserve", client, ToString(parm1) .. ToString(parm2) .. ToString(parm3) .. ToString(parm4))
			DAKDisplayMessageToClient(client, "kReserveSlotGranted", ToString(parm2))
		end
		
		SaveReservedPlayers()
	end

	DAKCreateServerAdminCommand("Console_sv_addreserve", AddReservePlayer, "<name> <id> <reason> <time> Will add a reserve player to the list.")
	
	local function DebugReserveSlots(client)
	
		if client ~= nil then
			for r = 1, #reserveslotactionslog, 1 do
				if reserveslotactionslog[r] ~= nil then
					ServerAdminPrint(client, reserveslotactionslog[r])
				end
			end
		end

	end

	DAKCreateServerAdminCommand("Console_sv_reservedebug", DebugReserveSlots, "Will print messages logged during actions taken by reserve slot plugin.")
	
end

Shared.Message("ReserveSlot Loading Complete")