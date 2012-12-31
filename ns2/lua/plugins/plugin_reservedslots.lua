//NS2 Reserved Slot

if kDAKConfig and kDAKConfig.ReservedSlots then

	local ReservedPlayers = { }
	local lastconnect = 0
	local lastdisconnect = 0
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

	local function GetPlayerCount() 
		local playerRecords = Shared.GetEntitiesWithClassname("Player")
        local result = playerRecords:GetSize()
		return result
	end
	
	local function SaveReservedPlayers()

		local ReservedPlayersFile = io.open(reservedPlayersFileName, "w+")
		ReservedPlayersFile:write(json.encode(ReservedPlayers, { indent = true, level = 1 }))
		ReservedPlayersFile:close()
		
	end
	
	local function DisconnectClientForReserveSlot(client)

		Server.DisconnectClient(client)
		
	end

	local function CheckReserveStatus(client, silent)

		if client:GetIsVirtual() then
			//Bots dont get reserve slot
			return false
		end
		
		if DAKGetClientCanRunCommand(client, "sv_hasreserve") then
			if not silent then ServerAdminPrint(client, "Reserved Slot Entry For - id: " .. tostring(client:GetUserId()) .. " - Is Valid (" .. GetPlayerCount() .. " players)") end
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
					if not silent then ServerAdminPrint(client, "Reserved Slot Entry For " .. tostring(ReservePlayer.name) .. " - id: " .. tostring(ReservePlayer.id) .. " - Is Valid (" .. GetPlayerCount() .. " players)") end
					return true
				end
			end	
		end
	end
	
	local function ServerIsFull(playerCount)
		local result = playerCount >= kDAKConfig.ReservedSlots.kMaximumSlots - kDAKConfig.ReservedSlots.kReservedSlots
		return result
	end
	
	local function UpdateServerLockStatus()
		local playerCount = GetPlayerCount()
		if ServerIsFull(playerCount) then
			Server.SetPassword(kDAKConfig.ReservedSlots.kReservePassword)
		else
			Server.SetPassword("")
		end
	end

	local function OnReserveSlotClientConnected(client)
		local playerCount = GetPlayerCount() - 1
		local serverFull = ServerIsFull(playerCount)
		local serverReallyFull = kDAKConfig.ReservedSlots.kMaximumSlots - playerCount <= kDAKConfig.ReservedSlots.kMinimumSlots

		
		
		local reserved = CheckReserveStatus(client, false)
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))

		UpdateServerLockStatus()
		
		if serverFull and not reserved then
			local player = client:GetControllingPlayer()
			if player ~= nil then
				chatMessage = string.sub(string.format(kDAKConfig.ReservedSlots.kReserveSlotServerFull), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				table.insert(reserveslotactionslog, "Kicking player "  .. tostring(player.name) .. " - id: " .. tostring(client:GetUserId()) .. " for no reserve slot (" .. playerCount .. " players).")
				EnhancedLog("Kicking player "  .. tostring(player.name) .. " - id: " .. tostring(client:GetUserId()) .. " for no reserve slot.")
			end
			client.disconnectreason = kDAKConfig.ReservedSlots.kReserveSlotServerFullDisconnectReason
			Server.DisconnectClient(client)
			disconnectclienttime = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedKickTime
			return false
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
				chatMessage = string.sub(string.format(kDAKConfig.ReservedSlots.kReserveSlotKickedForRoom), 1, kMaxChatLength)
				Server.SendNetworkMessage(playertokick, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				playertokick.disconnectreason = kDAKConfig.ReservedSlots.kReserveSlotKickedDisconnectReason
				Server.DisconnectClient(playertokick:GetClient())
				disconnectclienttime = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedKickTime
				return true
			else
				table.insert(reserveslotactionslog, "Attempted to kick player but no valid player could be located")
				EnhancedLog("Attempted to kick player but no valid player could be located")
			end

		end
		lastconnect = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedSyncTime
		return true
		
	end

	table.insert(kDAKOnClientDelayedConnect, function(client) return OnReserveSlotClientConnected(client) end)

	local function ReserveSlotClientDisconnect(client)    
	
		lastdisconnect = Shared.GetTime() + kDAKConfig.ReservedSlots.kDelayedSyncTime
		if client ~= nil and VerifyClient(client) ~= nil then
			UpdateServerLockStatus()
			return true
		else
			return false
		end
		
	end

	table.insert(kDAKOnClientDisconnect, function(client) return ReserveSlotClientDisconnect(client) end)

	local function AddReservePlayer(client, parm1, parm2, parm3, parm4)

		local idNum = tonumber(parm2)
		local exptime = tonumber(parm4)
		if client ~= nil and parm1 and idNum then
			local ReservePlayer = { name = ToString(parm1), id = idNum, reason = ToString(parm3 or ""), time = ConditionalValue(exptime, exptime, 0) }
			table.insert(ReservedPlayers, ReservePlayer)
			local player = client:GetControllingPlayer()
			if player ~= nil then
				chatMessage = string.sub(string.format("Player %s added to reserve players list.", ToString(parm2)), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				PrintToAllAdmins("sv_addreserve", client, ToString(parm1) .. ToString(parm2) .. ToString(parm3) .. ToString(parm4))
			end
		end
		
		SaveReservedPlayers()
	end

	DAKCreateServerAdminCommand("Console_sv_addreserve", AddReservePlayer, "<name> <id> <reason> <time> Will add a reserve player to the list.")
	
	local function DebugReserveSlots(client)
	
		if client ~= nil then
			ServerAdminPrint(client, "RESERVED SLOTS DEBUG: ")
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