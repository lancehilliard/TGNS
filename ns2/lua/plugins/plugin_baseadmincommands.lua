//Base Admin Commands
//This is designed to replace the base admin system.

if kDAKConfig and kDAKConfig.BaseAdminCommands then

	function CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)

		// Remove the prefix.
		if kDAKServerAdminCommands == nil then 
			kDAKServerAdminCommands = { }
		end
		local fixedCommandName = string.gsub(commandName, "Console_", "")
		local newCommand = function(client, ...)
		
			if not client or optionalAlwaysAllowed == true or DAKGetClientCanRunCommand(client, fixedCommandName, true) then
				return commandFunction(client, ...)
			end
			
		end
		
		table.insert(kDAKServerAdminCommands, { name = fixedCommandName, help = helpText or "No help provided" })
		Event.Hook(commandName, newCommand)
		
	end

	local function PrintHelpForCommand(client, optionalCommand)

		for c = 1, #kDAKServerAdminCommands do
		
			local command = kDAKServerAdminCommands[c]
			if optionalCommand == command.name or optionalCommand == nil then
			
				if not client or DAKGetClientCanRunCommand(client, command.name, false) then
					ServerAdminPrint(client, command.name .. ": " .. command.help)
				elseif optionalCommand then
					ServerAdminPrint(client, "You do not have access to " .. optionalCommand)
				end
				
			end
			
		end
		
	end
	Event.Hook("Console_sv_help", function(client, command) PrintHelpForCommand(client, command) end)

	local function GetPlayerList()

		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
		return playerList
		
	end

	/**
	 * Iterates over all players sorted in alphabetically calling the passed in function.
	 */
	local function AllPlayers(doThis)

		return function(client)
		
			local playerList = GetPlayerList()
			for p = 1, #playerList do
			
				local player = playerList[p]
				doThis(player, client, p)
				
			end
			
		end
		
	end

	local function GetPlayerMatchingSteamId(steamId)

		assert(type(steamId) == "number")
		
		local match = nil
		
		local function Matches(player)
		
			local playerClient = Server.GetOwner(player)
			if playerClient and playerClient:GetUserId() == steamId then
				match = player
			end
			
		end
		AllPlayers(Matches)()
		
		return match
		
	end

	local function GetPlayerMatchingName(name)

		assert(type(name) == "string")
		
		local match = nil
		
		local function Matches(player)
		
			if player:GetName() == name then
				match = player
			end
			
		end
		AllPlayers(Matches)()
		
		return match
		
	end

	local function GetPlayerMatching(id)

		local idNum = tonumber(id)
		if idNum then
			return GetPlayerMatchingGameId(idNum) or GetPlayerMatchingSteamId(idNum)
		elseif type(id) == "string" then
			return GetPlayerMatchingName(id)
		end
			
	end

	local function PrintStatus(player, client, index)

		local playerClient = Server.GetOwner(player)
		if not playerClient then
			Shared.Message("playerClient is nil in PrintStatus, alert Brian")
		else
			
			if DAKGetClientCanRunCommand(playerClient, "sv_status") then
				local playerAddressString = IPAddressToString(Server.GetClientAddress(playerClient))
				ServerAdminPrint(client, player:GetName() .. " : Game Id = " 
				.. ToString(GetGameIdMatchingClient(playerClient))
				.. " : Steam Id = " .. playerClient:GetUserId()
				.. " : Team = " .. player:GetTeamNumber()
				.. " : Address = " .. playerAddressString)
			else
				ServerAdminPrint(client, player:GetName() .. " : Game Id = " 
				.. ToString(GetGameIdMatchingClient(playerClient))
				.. " : Steam Id = " .. playerClient:GetUserId()
				.. " : Team = " .. player:GetTeamNumber())
			end

		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_status", AllPlayers(PrintStatus), "Lists player Ids and names for use in sv commands", true)

	local function OnCommandChangeMap(client, mapName)
		PrintToAllAdmins("sv_changemap", client, mapName)

		if DAKVerifyMapName(mapName) then
			MapCycle_ChangeToMap(mapName)
		else
			chatMessage = string.format("Invalid Map Provided.")
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		end
		
	end
	DAKCreateServerAdminCommand("Console_sv_changemap", OnCommandChangeMap, "<map name> Switches to the map specified")

	local function OnCommandSVReset(client)
		PrintToAllAdmins("sv_reset", client)
		local gamerules = GetGamerules()
		if gamerules then
			gamerules:ResetGame()
		end
	end

	DAKCreateServerAdminCommand("Console_sv_reset", OnCommandSVReset, "Resets the game round")

	local function OnCommandSVrrall(client)
		PrintToAllAdmins("sv_rrall", client)
		local playerList = GetPlayerList()
		for i = 1, (#playerList) do
			local gamerules = GetGamerules()
			if gamerules then
				gamerules:JoinTeam(playerList[i], kTeamReadyRoom)
			end
		end
	end
		
	DAKCreateServerAdminCommand("Console_sv_rrall", OnCommandSVrrall, "Forces all players to go to the Ready Room")

	local function OnCommandSVRandomall(client)
		PrintToAllAdmins("sv_randomall", client)
		local playerList = ShufflePlayerList()
		for i = 1, (#playerList) do
			if playerList[i]:GetTeamNumber() == 0 then
				local teamnum = math.fmod(i,2) + 1
				//Trying just making team decision based on position in array.. two randoms seems to somehow result in similar teams..
				local gamerules = GetGamerules()
				if gamerules then
					gamerules:JoinTeam(playerList[i], teamnum)
				end
			end
		end
	end

	DAKCreateServerAdminCommand("Console_sv_randomall", OnCommandSVRandomall, "Forces all players to join a random team")

	local function SwitchTeam(client, playerId, team)

		local player = GetPlayerMatching(playerId)
		local teamNumber = tonumber(team)
		if not DAKGetLevelSufficient(client,player) then
			return
		end
		if type(teamNumber) ~= "number" or teamNumber < 0 or teamNumber > 3 then
		
			ServerAdminPrint(client, "Invalid team number")
			return
			
		end
		
		if player and teamNumber ~= player:GetTeamNumber() then
			local gamerules = GetGamerules()
			if gamerules then
				gamerules:JoinTeam(player, teamNumber)
			end
		elseif not player then
			ServerAdminPrint(client, "No player matches Id: " .. playerId)
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_switchteam", SwitchTeam, "<player id> <team number> 1 is Marine, 2 is Alien")

	local function Eject(client, playerId)

		local player = GetPlayerMatching(playerId)
		if not DAKGetLevelSufficient(client, player) then
			return
		end
		if player and player:isa("Commander") then
			player:Eject()
		else
			ServerAdminPrint(client, "Invalid player")
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_eject", Eject, "<player id> Ejects Commander from the Command Structure")

	local function Kick(client, playerId)

		local player = GetPlayerMatching(playerId)
		if not DAKGetLevelSufficient(client, player) then
			return
		end
		if player then
			local client = Server.GetOwner(player)
			client.disconnectreason = "Kicked"
			Server.DisconnectClient(client)
		else
			ServerAdminPrint(client, "No matching player")
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_kick", Kick, "<player id> Kicks the player from the server")

	local function GetChatMessage(...)

		local chatMessage = StringConcatArgs(...)
		if chatMessage then
			return string.sub(chatMessage, 1, kMaxChatLength)
		end
		
		return ""
		
	end

	local function Say(client, ...)

		local chatMessage = GetChatMessage(...)
		if string.len(chatMessage) > 0 then
		
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			Shared.Message("Chat All - Admin: " .. chatMessage)
			Server.AddChatToHistory(chatMessage, kDAKConfig.DAKLoader.MessageSender, 0, kTeamReadyRoom, false)
			
		end
		
		if string.len(chatMessage) > 0 then 
			PrintToAllAdmins("sv_say", client, chatMessage)
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_say", Say, "<message> Sends a message to every player on the server")

	local function TeamSay(client, team, ...)

		local teamNumber = tonumber(team)
		if type(teamNumber) ~= "number" or teamNumber < 0 or teamNumber > 3 then
		
			ServerAdminPrint(client, "Invalid team number")
			return
			
		end
		
		local chatMessage = GetChatMessage(...)
		if string.len(chatMessage) > 0 then
		
			local players = GetEntitiesForTeam("Player", teamNumber)
			for index, player in ipairs(players) do
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "Team - " .. kDAKConfig.DAKLoader.MessageSender, -1, teamNumber, kNeutralTeamType, chatMessage), true)
			end
			
			Shared.Message("Chat Team - Admin: " .. chatMessage)
			Server.AddChatToHistory(chatMessage, kDAKConfig.DAKLoader.MessageSender, 0, teamNumber, true)
			
		end
		
		if string.len(chatMessage) > 0 then 
			PrintToAllAdmins("sv_tsay", client, chatMessage)
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_tsay", TeamSay, "<team number> <message> Sends a message to one team")

	local function PlayerSay(client, playerId, ...)

		local chatMessage = GetChatMessage(...)
		local player = GetPlayerMatching(playerId)
		
		if player then
		
			chatMessage = string.sub(chatMessage, 1, kMaxChatLength)
			if string.len(chatMessage) > 0 then
			
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, teamNumber, kNeutralTeamType, chatMessage), true)
				Shared.Message("Chat Player - Admin: " .. chatMessage)
				
			end
			
		else
			ServerAdminPrint(client, "No matching player")
		end
		
		if string.len(chatMessage) > 0 then 
			PrintToAllAdmins("sv_psay", client, chatMessage)
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_psay", PlayerSay, "<player id> <message> Sends a message to a single player")

	local function Slay(client, playerId)

		local player = GetPlayerMatching(playerId)
		if not DAKGetLevelSufficient(client, player) then
			return
		end
		if player then
			 player:Kill(nil, nil, player:GetOrigin())
		else
			ServerAdminPrint(client, "No matching player")
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_slay", Slay, "<player id>, Kills player")

	local function SetPassword(client, newPassword)
		Server.SetPassword(newPassword or "")
		PrintToAllAdmins("sv_password", client, newPassword)		
	end

	DAKCreateServerAdminCommand("Console_sv_password", SetPassword, "<string> Changes the password on the server")

	local bannedPlayers = { }
	local bannedPlayersFileName = "config://BannedPlayers.json"

	local function LoadBannedPlayers()

		Shared.Message("Loading " .. bannedPlayersFileName)
		
		bannedPlayers = { }
		
		// Load the ban settings from file if the file exists.
		local bannedPlayersFile = io.open(bannedPlayersFileName, "r")
		if bannedPlayersFile then
			bannedPlayers = json.decode(bannedPlayersFile:read("*all")) or { }
			bannedPlayersFile:close()
		end
		
	end

	LoadBannedPlayers()

	local function SaveBannedPlayers()

		local bannedPlayersFile = io.open(bannedPlayersFileName, "w+")
		if bannedPlayersFile then
			bannedPlayersFile:write(json.encode(bannedPlayers))
			bannedPlayersFile:close()
		end
		
	end

	local function OnConnectCheckBan(client)

		local steamid = client:GetUserId()
		for b = #bannedPlayers, 1, -1 do
		
			local ban = bannedPlayers[b]
			if ban.id == steamid then
			
				// Check if enough time has passed on a temporary ban.
				local now = Shared.GetSystemTime()
				if ban.time == 0 or now < ban.time then
				
					client.disconnectreason = "Banned"
					Server.DisconnectClient(client)
					break
					
				else
				
					// No longer banned.
					LoadBannedPlayers()
					table.remove(bannedPlayers, b)
					SaveBannedPlayers()
					
				end
				
			end
			
		end
		
	end

	Event.Hook("ClientConnect", OnConnectCheckBan)

	/**
	 * Duration is specified in minutes. Pass in 0 or nil to ban forever.
	 * A reason string may optionally be provided.
	 */
	local function Ban(client, playerId, duration, ...)

		local player = GetPlayerMatching(playerId)
		local bannedUntilTime = Shared.GetSystemTime()
		duration = tonumber(duration)
		if duration == nil or duration <= 0 then
			bannedUntilTime = 0
		else
			bannedUntilTime = bannedUntilTime + (duration * 60)
		end
		if not DAKGetLevelSufficient(client, playerId) then
			return
		end
		if player then
			
			LoadBannedPlayers()
			table.insert(bannedPlayers, { name = player:GetName(), id = Server.GetOwner(player):GetUserId(), reason = StringConcatArgs(...), time = bannedUntilTime })
			SaveBannedPlayers()
			ServerAdminPrint(client, player:GetName() .. " has been banned")
			local client = Server.GetOwner(player)
			client.disconnectreason = "Banned"
			Server.DisconnectClient(client)
			
		elseif tonumber(playerId) > 0 then
		
			LoadBannedPlayers()
			table.insert(bannedPlayers, { name = "Unknown", id = tonumber(playerId), reason = StringConcatArgs(...), time = bannedUntilTime })
			SaveBannedPlayers()
			ServerAdminPrint(client, "Player with SteamId " .. playerId .. " has been banned")
			
		else
			ServerAdminPrint(client, "No matching player")
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_ban", Ban, "<player id> <duration in minutes> <reason text> Bans the player from the server, pass in 0 for duration to ban forever")

	local function UnBan(client, steamId)

		local found = false
		LoadBannedPlayers()
		for p = #bannedPlayers, 1, -1 do
		
			if bannedPlayers[p].id == steamId then
			
				table.remove(bannedPlayers, p)
				ServerAdminPrint(client, "Removed " .. steamId .. " from the ban list")
				found = true
				
			end
			
		end
		
		if found then
			SaveBannedPlayers()
		else
			ServerAdminPrint(client, "No matching Steam Id in ban list")
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_unban", UnBan, "<steam id> Removes the player matching the passed in Steam Id from the ban list")

	function GetBannedPlayersList()

		local returnList = { }
		
		for p = 1, #bannedPlayers do
		
			local ban = bannedPlayers[p]
			table.insert(returnList, { name = ban.name, id = ban.id, reason = ban.reason, time = ban.time })
			
		end
		
		return returnList
		
	end

	local function ListBans(client)

		if #bannedPlayers == 0 then
			ServerAdminPrint(client, "No players are currently banned")
		end
		
		for p = 1, #bannedPlayers do
		
			local ban = bannedPlayers[p]
			local timeLeft = ban.time == 0 and "Forever" or (((ban.time - Shared.GetSystemTime()) / 60) .. " minutes")
			ServerAdminPrint(client, "Name: " .. ban.name .. " Id: " .. ban.id .. " Time Remaining: " .. timeLeft .. " Reason: " .. (ban.reason or "Not provided"))
			
		end
		
	end

	DAKCreateServerAdminCommand("Console_sv_listbans", ListBans, "Lists the banned players")

	local function PLogAll(client)

		Shared.ConsoleCommand("p_logall")
		ServerAdminPrint(client, "Performance logging enabled")
		
	end

	DAKCreateServerAdminCommand("Console_sv_p_logall", PLogAll, "Starts performance logging")

	local function PEndLog(client)

		Shared.ConsoleCommand("p_endlog")
		ServerAdminPrint(client, "Performance logging disabled")
		
	end
	
	DAKCreateServerAdminCommand("Console_sv_p_endlog", PEndLog, "Ends performance logging")

	local function AutoBalance(client, enabled, playerCount, seconds)

		if enabled == "true" then
		
			playerCount = playerCount and tonumber(playerCount) or 2
			seconds = seconds and tonumber(seconds) or 10
			Server.SetConfigSetting("auto_team_balance", { enabled_on_unbalance_amount = playerCount, enabled_after_seconds = seconds })
			ServerAdminPrint(client, "Auto Team Balance is now Enabled. Player unbalance amount: " .. playerCount .. " Activate delay: " .. seconds)
			
		else
		
			Server.SetConfigSetting("auto_team_balance", nil)
			ServerAdminPrint(client, "Auto Team Balance is now Disabled")
			
		end
		
	end
	
	DAKCreateServerAdminCommand("Console_sv_autobalance", AutoBalance, "<true/false> <player count> <seconds> Toggles auto team balance. The player count and seconds are optional. Count defaults to 2 over balance to enable. Defaults to 10 second wait to enable.")
	
	local function EnableEventTesting(client, enabled)

		enabled = not (enabled == "false")
		SetEventTestingEnabled(enabled)
		ServerAdminPrint(client, "Event testing " .. (enabled and "enabled" or "disabled"))
		
	end
	
	DAKCreateServerAdminCommand("Console_sv_test_events", EnableEventTesting, "<true/false> Toggles event testing mode")
	
end

Shared.Message("BaseAdminCommands Loading Complete")