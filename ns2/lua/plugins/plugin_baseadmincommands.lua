//Base Admin Commands
//This is designed to replace the base admin commands.

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

local function PrintStatus(player, client, index)

	local playerClient = Server.GetOwner(player)
	if not playerClient then
		Shared.Message("playerClient is nil in PrintStatus, alert Brian")
	else
		
		if client == nil then
			local playerAddressString = IPAddressToString(Server.GetClientAddress(playerClient))
			Shared.Message(player:GetName() .. " : Game Id = " 
			.. ToString(GetGameIdMatchingClient(playerClient))
			.. " : Steam Id = " .. playerClient:GetUserId()
			.. " : Team = " .. player:GetTeamNumber()
			.. " : Address = " .. playerAddressString)
		elseif DAKGetClientCanRunCommand(client, "sv_status") then
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

	if MapCycle_VerifyMapName(mapName) then
		MapCycle_ChangeToMap(mapName)
	else
		if client ~= nil then
			DAKDisplayMessageToClient(client, "InvalidMap")
		end
	end
	
end
DAKCreateServerAdminCommand("Console_sv_changemap", OnCommandChangeMap, "<map name> Switches to the map specified")

local function OnCommandSVReset(client)
	PrintToAllAdmins("sv_reset", client)
	local gamerules = GetGamerules()
	if gamerules then
		gamerules:ResetGame()
	end
	if client then
		ServerAdminPrint(client, string.format("Game was reset."))
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
	if client then
		ServerAdminPrint(client, string.format("All players were moved to the ReadyRoom."))
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
				if not gamerules:GetCanJoinTeamNumber(teamnum) and gamerules:GetCanJoinTeamNumber(math.fmod(teamnum,2) + 1) then
					teamnum = math.fmod(teamnum,2) + 1						
				end
				gamerules:JoinTeam(playerList[i], teamnum)
			end
		end
	end
	if client then
		ServerAdminPrint(client, string.format("Teams were Randomed."))
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
	
		if client then
			ServerAdminPrint(client, "Invalid team number")
		end
		return
		
	end
	
	if player and teamNumber ~= player:GetTeamNumber() then
		local gamerules = GetGamerules()
		if gamerules then
			gamerules:JoinTeam(player, teamNumber)
		end
		if client then
			local switchedclient = Server.GetOwner(player)
			if switchedclient then
				PrintToAllAdmins("sv_switchteam", client, string.format("on %s to team %s.", GetClientUIDString(switchedclient), teamNumber))
			end
			ServerAdminPrint(client, string.format("Player %s was moved to team %s.", player:GetName(), teamNumber))
		end
	elseif not player and client then
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAKCreateServerAdminCommand("Console_sv_switchteam", SwitchTeam, "<player id> <team number> Moves passed player to provided team. 1 is Marine, 2 is Alien.")

local function Eject(client, playerId)

	local player = GetPlayerMatching(playerId)
	
	if not DAKGetLevelSufficient(client, player) then
		return
	end
	
	if player and player:isa("Commander") then
		if client then
			ServerAdminPrint(client, "Player " .. player:GetName() .. "was ejected.")
		end
		player:Eject()
	elseif client then
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAKCreateServerAdminCommand("Console_sv_eject", Eject, "<player id> Ejects Commander from the Command Structure")

local function Kick(client, playerId)

	local player = GetPlayerMatching(playerId)
	
	if not DAKGetLevelSufficient(client, player) then
		return
	end
	
	if player then
		local kickedclient = Server.GetOwner(player)
		if kickedclient then
			if client then
				ServerAdminPrint(client, "Player " .. player:GetName() .. " was kicked.")
				PrintToAllAdmins("sv_kick", client, string.format("on %s.", GetClientUIDString(kickedclient)))
			end
			kickedclient.disconnectreason = "Kicked"
			Server.DisconnectClient(kickedclient)
		end
	elseif client then
		ServerAdminPrint(client, "No matching player.")
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
		ServerAdminPrint(client, "No matching player.")
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
		if client then
			local slayedclient = Server.GetOwner(player)
			if slayedclient then
				PrintToAllAdmins("sv_slay", client, string.format("on %s.", GetClientUIDString(slayedclient)))
			end
			ServerAdminPrint(client, "Player " .. player:GetName() .. " was slayed.")
		end
	elseif client ~= nil then
		ServerAdminPrint(client, "No matching player.")
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
local bannedPlayersWeb = { }
local bannedPlayersWebFileName = "config://BannedPlayersWeb.json"
local initialbannedwebupdate = 0
local lastbannedwebupdate = 0

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
		bannedPlayersFile:write(json.encode(bannedPlayers, { indent = true, level = 1 }))
		bannedPlayersFile:close()
	end
	
end

local function LoadBannedPlayersWeb()

	Shared.Message("Loading " .. bannedPlayersWebFileName)
	
	bannedPlayersWeb = { }
	
	// Load the ban settings from file if the file exists.
	local bannedPlayersWebFile = io.open(bannedPlayersWebFileName, "r")
	if bannedPlayersWebFile then
		bannedPlayersWeb = json.decode(bannedPlayersWebFile:read("*all")) or { }
		bannedPlayersWebFile:close()
	end
	
end

local function SaveBannedPlayersWeb()

	local bannedPlayersWebFile = io.open(bannedPlayersWebFileName, "w+")
	if bannedPlayersWebFile then
		bannedPlayersWebFile:write(json.encode(bannedPlayersWeb, { indent = true, level = 1 }))
		bannedPlayersWebFile:close()
	end
	
end

local function ProcessWebResponse(response)
	local sstart = string.find(response,"<body>")
	local rstring = string.sub(response, sstart)
	if rstring then
		rstring = rstring:gsub("<body>\n", "{")
		rstring = rstring:gsub("<body>", "{")
		rstring = rstring:gsub("</body>", "}")
		rstring = rstring:gsub("<div id=\"username\"> ", "\"")
		rstring = rstring:gsub(" </div> <div id=\"steamid\"> ", "\": { \"id\": ")
		rstring = rstring:gsub(" </div> <div id=\"group\"> ", ", \"groups\": [ \"")
		rstring = rstring:gsub(" </div> <br>", "\" ] },")
		rstring = rstring:gsub("\n", "")
		return json.decode(rstring)
	end
	return nil
end

local function OnServerAdminWebResponse(response)
	if response then
		local bannedusers = ProcessWebResponse(response)
		if bannedusers and bannedPlayersWeb ~= bannedusers then
			bannedPlayersWeb = bannedusers
			SaveBannedPlayersWeb()
		end
	end
end

local function QueryForBansList()
	if kDAKConfig.BaseAdminCommands.kBansQueryURL ~= "" then
		Shared.SendHTTPRequest(kDAKConfig.BaseAdminCommands.kBansQueryURL, "GET", OnServerAdminWebResponse)
	end
	lastbannedwebupdate = Shared.GetTime()
end

local function OnServerAdminClientConnect(client)
	local tt = Shared.GetTime()
	if tt > kDAKConfig.BaseAdminCommands.kMapChangeDelay and (lastbannedwebupdate == nil or (lastbannedwebupdate + kDAKConfig.BaseAdminCommands.kUpdateDelay) < tt) and kDAKConfig.BaseAdminCommands.kBansQueryURL ~= "" and initialbannedwebupdate ~= 0 then
		QueryForBansList()
	end
end

local function DelayedBannedPlayersWebUpdate()
	if kDAKConfig.BaseAdminCommands.kBansQueryURL == "" then
		DAKDeregisterEventHook("kDAKOnServerUpdate", DelayedBannedPlayersWebUpdate)
		return
	end
	if initialbannedwebupdate == 0 then
		QueryForBansList()
		initialbannedwebupdate = Shared.GetTime() + kDAKConfig.BaseAdminCommands.kBansQueryTimeout		
	end
	if initialbannedwebupdate < Shared.GetTime() then
		if bannedPlayersWeb == nil then
			Shared.Message("Bans WebQuery failed, falling back on cached list.")
			LoadBannedPlayersWeb()
			initialbannedwebupdate = 0
		end
		DAKDeregisterEventHook("kDAKOnServerUpdate", DelayedBannedPlayersWebUpdate)
	end
end

DAKRegisterEventHook("kDAKOnServerUpdate", DelayedBannedPlayersWebUpdate, 5)

local function OnConnectCheckBan(client)

	OnServerAdminClientConnect()
	local steamid = client:GetUserId()
	for b = #bannedPlayers, 1, -1 do
	
		local ban = bannedPlayers[b]
		if ban.id == steamid then
		
			// Check if enough time has passed on a temporary ban.
			local now = Shared.GetSystemTime()
			if ban.time == 0 or now < ban.time then
			
				client.disconnectreason = "Banned"
				Server.DisconnectClient(client)
				return true
				
			else
			
				// No longer banned.
				LoadBannedPlayers()
				table.remove(bannedPlayers, b)
				SaveBannedPlayers()
				
			end
			
		end
		
	end
	
	for b = #bannedPlayersWeb, 1, -1 do
	
		local ban = bannedPlayersWeb[b]
		if ban.id == steamid then
		
			// Check if enough time has passed on a temporary ban.
			local now = Shared.GetSystemTime()
			if ban.time == 0 or now < ban.time then
			
				client.disconnectreason = "Banned"
				Server.DisconnectClient(client)
				return true
				
			else
			
				// No longer banned.
				// Remove to prevent confusion, but also should consider if this is supposed to update the PHPDB, or just assume that will handle expiring bans itself.
				table.remove(bannedPlayersWeb, b)
				SaveBannedPlayersWeb()
				
			end
			
		end
		
	end
	
end

DAKRegisterEventHook("kDAKOnClientConnect", OnConnectCheckBan, 6)

local function OnPlayerBannedResponse(response)
	if response == "TRUE" then
		//ban successful, update webbans using query URL.
		 QueryForBansList()
	end
end

local function OnPlayerUnBannedResponse(response)
	if response == "TRUE" then
		//Unban successful, anything needed here?
	end
end

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
	
	if player then
	
		if not DAKGetLevelSufficient(client, player) then
			return
		end
		
		local bannedclient = Server.GetOwner(player)
		if bannedclient then
		
			if kDAKConfig.BaseAdminCommands.kBanSubmissionURL ~= "" then
				//Submit ban with key, working on logic to hash key
				//Should these be both submitted to database and logged on server?  My thinking is no here, so going with that moving forward.
				//kDAKConfig.BaseAdminCommands.kBanSubmissionURL
				//kDAKConfig.BaseAdminCommands.kCryptographyKey
				//Will also want ban response function to reload web bans.
				//OnPlayerBannedResponse
				//Shared.SendHTTPRequest(kDAKConfig.BaseAdminCommands.kBanSubmissionURL, "POST", parms, OnPlayerBannedResponse)
			else
				LoadBannedPlayers()
				table.insert(bannedPlayers, { name = player:GetName(), id = bannedclient:GetUserId(), reason = StringConcatArgs(...), time = bannedUntilTime })
				SaveBannedPlayers()
			end
			
			if client then
				ServerAdminPrint(client, player:GetName() .. " has been banned.")
				PrintToAllAdmins("sv_ban", client, string.format("on %s for %s for %s.", GetClientUIDString(bannedclient), duration, args))
			end
			
			bannedclient.disconnectreason = "Banned"
			Server.DisconnectClient(bannedclient)
			
		end		
		
	elseif tonumber(playerId) > 0 then
	
		if not DAKGetLevelSufficient(client, playerId) then
			return
		end
	
		if kDAKConfig.BaseAdminCommands.kBanSubmissionURL ~= "" then
			//Submit ban with key, working on logic to hash key
			//Should these be both submitted to database and logged on server?  My thinking is no here, so going with that moving forward.
			//kDAKConfig.BaseAdminCommands.kBanSubmissionURL
			//kDAKConfig.BaseAdminCommands.kCryptographyKey
			//Will also want ban response function to reload web bans.
			//OnPlayerBannedResponse
			//Shared.SendHTTPRequest(kDAKConfig.BaseAdminCommands.kBanSubmissionURL, "POST", parms, OnPlayerBannedResponse)
		else
			LoadBannedPlayers()
			table.insert(bannedPlayers, { name = "Unknown", id = tonumber(playerId), reason = StringConcatArgs(...), time = bannedUntilTime })
			SaveBannedPlayers()
		end
		
		if client then
			ServerAdminPrint(client, "Player with SteamId " .. playerId .. " has been banned.")
			PrintToAllAdmins("sv_ban", client, string.format("on SteamID:%s for %s for %s.", playerId, duration, args))
		end
		
	elseif client ~= nil then
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAKCreateServerAdminCommand("Console_sv_ban", Ban, "<player id> <duration in minutes> <reason text> Bans the player from the server, pass in 0 for duration to ban forever")

local function UnBan(client, steamId)

	local found = false
	local foundweb = false
	LoadBannedPlayers()
	for p = #bannedPlayers, 1, -1 do
	
		if bannedPlayers[p].id == steamId then
		
			table.remove(bannedPlayers, p)
			if client then
				ServerAdminPrint(client, "Removed " .. steamId .. " from the ban list.")
			end
			found = true
			
		end
		
	end
	
	for p = #bannedPlayersWeb, 1, -1 do
	
		if bannedPlayersWeb[p].id == steamId then
		
			table.remove(bannedPlayersWeb, p)
			if client then
				ServerAdminPrint(client, "Removed " .. steamId .. " from the ban list.")
			end
			foundweb = true
			
		end
		
	end
	
	if found then
		if client then
			PrintToAllAdmins("sv_unban", client, string.format(" on SteamID:%s.", steamId))
		end
		SaveBannedPlayers()
	end
	if foundweb then
		//Submit unban with key
		//kDAKConfig.BaseAdminCommands.kUnBanSubmissionURL
		//kDAKConfig.BaseAdminCommands.kCryptographyKey
		//OnPlayerUnBannedResponse
		//Shared.SendHTTPRequest(kDAKConfig.BaseAdminCommands.kUnBanSubmissionURL, "GET", OnPlayerUnBannedResponse)
	end
	if not found and not foundweb then
		ServerAdminPrint(client, "No matching Steam Id in ban list.")
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

	if #bannedPlayers == 0 and #bannedPlayersWeb == 0 then
		ServerAdminPrint(client, "No players are currently banned.")
	end
	
	for p = 1, #bannedPlayers do
	
		local ban = bannedPlayers[p]
		local timeLeft = ban.time == 0 and "Forever" or (((ban.time - Shared.GetSystemTime()) / 60) .. " minutes")
		ServerAdminPrint(client, "Name: " .. ban.name .. " Id: " .. ban.id .. " Time Remaining: " .. timeLeft .. " Reason: " .. (ban.reason or "Not provided"))
		
	end
	
	for p = 1, #bannedPlayersWeb do
	
		local ban = bannedPlayersWeb[p]
		local timeLeft = ban.time == 0 and "Forever" or (((ban.time - Shared.GetSystemTime()) / 60) .. " minutes")
		ServerAdminPrint(client, "Name: " .. ban.name .. " Id: " .. ban.id .. " Time Remaining: " .. timeLeft .. " Reason: " .. (ban.reason or "Not provided"))
		
	end
	
end

DAKCreateServerAdminCommand("Console_sv_listbans", ListBans, "Lists the banned players")

local function UpdateNick(client, playerId, nick)

    local player = GetPlayerMatching(playerId)
	
    if player and nick ~= nil then
		local oldname = player:GetName()
        player:SetName(nick)
		if client then
			ServerAdminPrint(client, string.format("Player's name was changed from %s to %s.", oldname, player:GetName()))
		end
		PrintToAllAdmins("sv_nick", client, string.format(" on %s to %s.", oldname, player:GetName()))
    else
        ServerAdminPrint(client, "No matching player.")
    end
    
end
DAKCreateServerAdminCommand("Console_sv_nick", UpdateNick, "<player id> <name> Changes name of the provided player.")