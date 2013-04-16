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
		local playerId = playerClient:GetUserId()
		if DAK:GetClientCanRunCommand(client, "sv_status") then
			local playerAddressString = IPAddressToString(Server.GetClientAddress(playerClient))
			ServerAdminPrint(client, player:GetName() .. " : Game Id = " 
			.. ToString(DAK:GetGameIdMatchingClient(playerClient))
			.. " : NS2 Id = " .. playerId
			.. " : Steam Id = " .. GetReadableSteamId(playerId)
			.. " : Team = " .. player:GetTeamNumber()
			.. " : Address = " .. playerAddressString
			.. " : Connection Time = " .. DAK:GetClientConnectionTime(playerClient))
		else
			ServerAdminPrint(client, player:GetName() .. " : Game Id = " 
			.. ToString(DAK:GetGameIdMatchingClient(playerClient))
			.. " : NS2 Id = " .. playerId
			.. " : Steam Id = " .. GetReadableSteamId(playerId)
			.. " : Team = " .. player:GetTeamNumber())
		end

	end
	
end

DAK:CreateServerAdminCommand("Console_sv_status", AllPlayers(PrintStatus), "Lists player Ids and names for use in sv commands", true)

local function OnCommandChangeMap(client, mapName)

	DAK:PrintToAllAdmins("sv_changemap", client, mapName)

	if MapCycle_VerifyMapName(mapName) then
		MapCycle_ChangeToMap(mapName)
	else
		DAK:DisplayMessageToClient(client, "InvalidMap")
	end
	
end
DAK:CreateServerAdminCommand("Console_sv_changemap", OnCommandChangeMap, "<map name> Switches to the map specified")

local function OnCommandSVReset(client)

	DAK:PrintToAllAdmins("sv_reset", client)
	local gamerules = GetGamerules()
	if gamerules then
		gamerules:ResetGame()
	end
	ServerAdminPrint(client, string.format("Game was reset."))
	
end

DAK:CreateServerAdminCommand("Console_sv_reset", OnCommandSVReset, "Resets the game round")

local function OnCommandSVrrall(client)

	DAK:PrintToAllAdmins("sv_rrall", client)
	local playerList = GetPlayerList()
	for i = 1, (#playerList) do
		local gamerules = GetGamerules()
		if gamerules then
			gamerules:JoinTeam(playerList[i], kTeamReadyRoom)
		end
	end
	ServerAdminPrint(client, string.format("All players were moved to the ReadyRoom."))
	
end
	
DAK:CreateServerAdminCommand("Console_sv_rrall", OnCommandSVrrall, "Forces all players to go to the Ready Room")

local function OnCommandSVRandomall(client)

	DAK:PrintToAllAdmins("sv_randomall", client)
	local playerList = DAK:ShuffledPlayerList()
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
	ServerAdminPrint(client, string.format("Teams were Randomed."))
	
end

DAK:CreateServerAdminCommand("Console_sv_randomall", OnCommandSVRandomall, "Forces all players to join a random team")

local function SwitchTeam(client, playerId, team)

	local player = DAK:GetPlayerMatching(playerId)
	local teamNumber = tonumber(team)
	
	if not DAK:GetLevelSufficient(client, player) then
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
		ServerAdminPrint(client, string.format("Player %s was moved to team %s.", player:GetName(), teamNumber))
		local switchedclient = Server.GetOwner(player)
		if switchedclient then
			DAK:PrintToAllAdmins("sv_switchteam", client, string.format("on %s to team %s.", DAK:GetClientUIDString(switchedclient), teamNumber))
		end
	elseif not player then
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_switchteam", SwitchTeam, "<player id> <team number> Moves passed player to provided team. 1 is Marine, 2 is Alien.")

local function Eject(client, playerId)

	local player = DAK:GetPlayerMatching(playerId)
	
	if not DAK:GetLevelSufficient(client, player) then
		return
	end
	
	if player and player:isa("Commander") then
		ServerAdminPrint(client, "Player " .. player:GetName() .. "was ejected.")
		player:Eject()
	else
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_eject", Eject, "<player id> Ejects Commander from the Command Structure")

local function Kick(client, playerId)

	local player = DAK:GetPlayerMatching(playerId)
	
	if not DAK:GetLevelSufficient(client, player) then
		return
	end
	
	if player then
		local kickedclient = Server.GetOwner(player)
		if kickedclient then
			ServerAdminPrint(client, "Player " .. player:GetName() .. " was kicked.")
			DAK:PrintToAllAdmins("sv_kick", client, string.format("on %s.", DAK:GetClientUIDString(kickedclient)))
			kickedclient.disconnectreason = "Kicked"
			Server.DisconnectClient(kickedclient)
		end
	else
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_kick", Kick, "<player id> Kicks the player from the server")

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
	
		Server.SendNetworkMessage("Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		Shared.Message("Chat All - Admin: " .. chatMessage)
		Server.AddChatToHistory(chatMessage, DAK.config.language.MessageSender, 0, kTeamReadyRoom, false)
		
	end
	
	if string.len(chatMessage) > 0 then 
		DAK:PrintToAllAdmins("sv_say", client, chatMessage)
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_say", Say, "<message> Sends a message to every player on the server")

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
			Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "Team - " .. DAK.config.language.MessageSender, -1, teamNumber, kNeutralTeamType, chatMessage), true)
		end
		
		Shared.Message("Chat Team - Admin: " .. chatMessage)
		Server.AddChatToHistory(chatMessage, DAK.config.language.MessageSender, 0, teamNumber, true)
		
	end
	
	if string.len(chatMessage) > 0 then 
		DAK:PrintToAllAdmins("sv_tsay", client, chatMessage)
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_tsay", TeamSay, "<team number> <message> Sends a message to one team")

local function PlayerSay(client, playerId, ...)

	local chatMessage = GetChatMessage(...)
	local player = DAK:GetPlayerMatching(playerId)
	
	if player then
	
		chatMessage = string.sub(chatMessage, 1, kMaxChatLength)
		if string.len(chatMessage) > 0 then
		
			Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, teamNumber, kNeutralTeamType, chatMessage), true)
			Shared.Message("Chat Player - Admin: " .. chatMessage)
			
		end
		
	else
		ServerAdminPrint(client, "No matching player.")
	end
	
	if string.len(chatMessage) > 0 then 
		DAK:PrintToAllAdmins("sv_psay", client, chatMessage)
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_psay", PlayerSay, "<player id> <message> Sends a message to a single player")

local function Slay(client, playerId)

	local player = DAK:GetPlayerMatching(playerId)
	
	if not DAK:GetLevelSufficient(client, player) then
		return
	end
	
	if player then
		player:Kill(nil, nil, player:GetOrigin())
		ServerAdminPrint(client, "Player " .. player:GetName() .. " was slayed.")
		local slayedclient = Server.GetOwner(player)
		if slayedclient then
			DAK:PrintToAllAdmins("sv_slay", client, string.format("on %s.", DAK:GetClientUIDString(slayedclient)))
		end
	else
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_slay", Slay, "<player id>, Kills player")

local function SetPassword(client, newPassword)
	Server.SetPassword(newPassword or "")
	ServerAdminPrint(client, "Server password changed to ********.")
	DAK:PrintToAllAdmins("sv_password", client, newPassword or "")		
end

DAK:CreateServerAdminCommand("Console_sv_password", SetPassword, "<string> Changes the password on the server")

local function Ban(client, playerId, name, duration, ...)

	local player = DAK:GetPlayerMatching(playerId)
	local reason =  StringConcatArgs(...) or "No Reason"
	if tonumber(name) ~= nil and tonumber(duration) == nil then
		duration = tonumber(name)
		if player then
			name = player:GetName()
		else
			name = "Not Provided"
		end
	end
	duration = tonumber(duration) or 0
	if player then
		if not DAK:GetLevelSufficient(client, player) then
			return
		end
		local bannedclient = Server.GetOwner(player)
		if bannedclient then
			if DAK:AddSteamIDBan(bannedclient:GetUserId(), name or player:GetName(), duration, reason) then
				ServerAdminPrint(client, player:GetName() .. " has been banned.")
				DAK:PrintToAllAdmins("sv_ban", client, string.format("on %s for %s for %s.", DAK:GetClientUIDString(bannedclient), duration, reason))
				bannedclient.disconnectreason = reason
				Server.DisconnectClient(bannedclient)
			end
		end

	elseif tonumber(playerId) > 0 then
	
		if not DAK:GetLevelSufficient(client, playerId) then
			return
		end
		if DAK:AddSteamIDBan(tonumber(playerId), name or "Unknown", duration, reason) then
			ServerAdminPrint(client, "Player with SteamId " .. playerId .. " has been banned.")
			DAK:PrintToAllAdmins("sv_ban", client, string.format("on SteamID:%s for %s for %s.", playerId, duration, reason))
		end

	else
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_ban", Ban, "<player id> <player name> <duration in minutes> <reason text> Bans the player from the server, pass in 0 for duration to ban forever")

local function UnBan(client, steamId)

	if DAK:UnBanSteamID(steamId) then
		DAK:PrintToAllAdmins("sv_unban", client, string.format(" on SteamID:%s.", steamId))
		ServerAdminPrint(client, "Player with SteamId " .. steamId .. " has been unbanned.")
	else
		ServerAdminPrint(client, "No matching Steam Id in ban list.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_unban", UnBan, "<steam id> Removes the player matching the passed in Steam Id from the ban list")

local function UpdateNick(client, playerId, nick)

    local player = DAK:GetPlayerMatching(playerId)
	
    if player and nick ~= nil then
		local oldname = player:GetName()
        player:SetName(nick)
		ServerAdminPrint(client, string.format("Player's name was changed from %s to %s.", oldname, player:GetName()))
		DAK:PrintToAllAdmins("sv_nick", client, string.format(" on %s to %s.", oldname, player:GetName()))
    else
        ServerAdminPrint(client, "No matching player.")
    end
    
end

DAK:CreateServerAdminCommand("Console_sv_nick", UpdateNick, "<player id> <name> Changes name of the provided player.")

local kChatsPerSecondAdded = DAK.config.baseadmincommands.ChatRecoverRate
local kMaxChatsInBucket = DAK.config.baseadmincommands.ChatLimit
local function CheckChatAllowed(client)

	client.chatTokenBucket = client.chatTokenBucket or CreateTokenBucket(kChatsPerSecondAdded, kMaxChatsInBucket)
	// Returns true if there was a token to remove.
	return client.chatTokenBucket:RemoveTokens(1)
	
end

local function GetChatPlayerData(client)

	local playerName = "Admin"
	local playerLocationId = -1
	local playerTeamNumber = kTeamReadyRoom
	local playerTeamType = kNeutralTeamType
	
	if client then
	
		local player = client:GetControllingPlayer()
		if not player then
			return
		end
		playerName = player:GetName()
		playerLocationId = player.locationId
		playerTeamNumber = player:GetTeamNumber()
		playerTeamType = player:GetTeamType()
		
	end
	
	return playerName, playerLocationId, playerTeamNumber, playerTeamType
	
end

local function OnChatReceived(client, message)

	if not CheckChatAllowed(client) then
		return
	end
	
	chatMessage = string.sub(message.message, 1, kMaxChatLength)
	
	if DAK:IsClientGagged(client) then
		chatMessage = DAK.config.baseadmincommands.GaggedClientMessage
	end
	
	if chatMessage and string.len(chatMessage) > 0 then
	
		local playerName, playerLocationId, playerTeamNumber, playerTeamType = GetChatPlayerData(client)
		
		if playerName then
		
			if message.teamOnly then
			
				local players = GetEntitiesForTeam("Player", playerTeamNumber)
				for index, player in ipairs(players) do
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(true, playerName, playerLocationId, playerTeamNumber, playerTeamType, chatMessage), true)
				end
				
			else
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, playerName, playerLocationId, playerTeamNumber, playerTeamType, chatMessage), true)
			end
			
			Shared.Message("Chat " .. (message.teamOnly and "Team - " or "All - ") .. playerName .. ": " .. chatMessage)
			
			// We save a history of chat messages received on the Server.
			Server.AddChatToHistory(chatMessage, playerName, client:GetUserId(), playerTeamNumber, message.teamOnly)
			
		end
		
	end
	
end

local function DelayedEventHooks()
	DAK:ReplaceNetworkMessageFunction("ChatClient", OnChatReceived)
end

DAK:RegisterEventHook("OnPluginInitialized", DelayedEventHooks, 5, "baseadmincommands")

local function OnCommandGagPlayer(client, playerId, duration)

	local player = DAK:GetPlayerMatching(playerId)
	duration = tonumber(duration)
	if duration == nil then 
		duration = DAK.config.baseadmincommands.DefaultGagTime * 60
	else
		duration = duration * 60
	end
	
	if player and duration ~= nil then
		local targetclient = Server.GetOwner(player)
		if targetclient then
			DAK:AddClientToGaggedList(targetclient, duration)
			DAK:DisplayMessageToClient(targetclient, "GaggedMessage")
			ServerAdminPrint(client, string.format("Player %s was gagged for %.1f minutes.", player:GetName(), (duration / 60)))
			DAK:PrintToAllAdmins("sv_gag", client, string.format("Player %s was gagged for %.1f minutes.", player:GetName(), (duration / 60)))
		end
	else
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_gag", OnCommandGagPlayer, "<player id> <duration> Gags the provided player for the provided minutes.")

local function OnCommandUnGagPlayer(client, playerId)

	local player = DAK:GetPlayerMatching(playerId)
	
	if player then
		local targetclient = Server.GetOwner(player)
		if targetclient then
			DAK:RemoveClientFromGaggedList(targetclient)
			DAK:DisplayMessageToClient(targetclient, "UngaggedMessage")
			ServerAdminPrint(client, string.format("Player %s was ungagged.", player:GetName()))
			DAK:PrintToAllAdmins("sv_gag", client, string.format("Player %s was ungagged.", player:GetName()))
		end
	else
		ServerAdminPrint(client, "No matching player.")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_ungag", OnCommandUnGagPlayer, "<player id> Ungags the provided player.")

local function PopulateMenuItemWithClientList(VoteUpdateMessage, page)
	for p = 1, #DAK.gameid do
		local ci = p - (page * 8)
		if ci > 0 and ci < 9 then
			VoteUpdateMessage.option[ci] = string.format(DAK:GetClientUIDString(DAK.gameid[p]))
		end
	end
end

local function OnCommandUpdateBanMenu(steamId, LastUpdateMessage, page)
	local kVoteUpdateMessage = DAK:CreateMenuBaseNetworkMessage()
	kVoteUpdateMessage.header = string.format("Player to ban.")
	PopulateMenuItemWithClientList(kVoteUpdateMessage, page)
	kVoteUpdateMessage.inputallowed = true
	kVoteUpdateMessage.footer = "BANT"
	return kVoteUpdateMessage
end

local function OnCommandBanSelection(client, selectionnumber, page)
	local targetclient = DAK.gameid[selectionnumber + (page * 8)]
	if targetclient ~= nil then
		local HeadingText = string.format("Please confirm you wish to ban %s?", DAK:GetClientUIDString(targetclient))
		DAK:DisplayConfirmationMenuItem(DAK:GetNS2IdMatchingClient(client), HeadingText, Ban, nil, DAK:GetNS2IdMatchingClient(targetclient))
	end
end

local function OnCommandUpdateKickMenu(steamId, LastUpdateMessage, page)
	local kVoteUpdateMessage = DAK:CreateMenuBaseNetworkMessage()
	kVoteUpdateMessage.header = string.format("Player to kick.")
	PopulateMenuItemWithClientList(kVoteUpdateMessage, page)
	kVoteUpdateMessage.inputallowed = true
	kVoteUpdateMessage.footer = "KICK'D"
	return kVoteUpdateMessage
end

local function OnCommandKickSelection(client, selectionnumber, page)
	local targetclient = DAK.gameid[selectionnumber + (page * 8)]
	if targetclient ~= nil then
		local HeadingText = string.format("Please confirm you wish to kick %s?", DAK:GetClientUIDString(targetclient))
		DAK:DisplayConfirmationMenuItem(DAK:GetNS2IdMatchingClient(client), HeadingText, Kick, nil, DAK:GetNS2IdMatchingClient(targetclient))
	end
end

local function OnCommandUpdateSlayMenu(steamId, LastUpdateMessage, page)
	local kVoteUpdateMessage = DAK:CreateMenuBaseNetworkMessage()
	kVoteUpdateMessage.header = string.format("Player to slay.")
	PopulateMenuItemWithClientList(kVoteUpdateMessage, page)
	kVoteUpdateMessage.inputallowed = true
	kVoteUpdateMessage.footer = "Slay'D"
	return kVoteUpdateMessage
end

local function OnCommandSlaySelection(client, selectionnumber, page)
	local targetclient = DAK.gameid[selectionnumber + (page * 8)]
	if targetclient ~= nil then
		local HeadingText = string.format("Please confirm you wish to slay %s?", DAK:GetClientUIDString(targetclient))
		DAK:DisplayConfirmationMenuItem(DAK:GetNS2IdMatchingClient(client), HeadingText, Slay, nil, DAK:GetNS2IdMatchingClient(targetclient))
	end
end

local function GetBansMenu(client)
	DAK:CreateGUIMenuBase(DAK:GetNS2IdMatchingClient(client), OnCommandBanSelection, OnCommandUpdateBanMenu, true)
end

local function GetKickMenu(client)
	DAK:CreateGUIMenuBase(DAK:GetNS2IdMatchingClient(client), OnCommandKickSelection, OnCommandUpdateKickMenu, true)
end

local function GetSlayMenu(client)
	DAK:CreateGUIMenuBase(DAK:GetNS2IdMatchingClient(client), OnCommandSlaySelection, OnCommandUpdateSlayMenu, true)
end

DAK:RegisterMainMenuItem("Kick Menu", function(client) return DAK:GetClientCanRunCommand(client, "sv_kick") end, GetKickMenu)
DAK:RegisterMainMenuItem("Ban Menu", function(client) return DAK:GetClientCanRunCommand(client, "sv_ban") end, GetBansMenu)
DAK:RegisterMainMenuItem("Slay Menu", function(client) return DAK:GetClientCanRunCommand(client, "sv_slay") end, GetSlayMenu)
