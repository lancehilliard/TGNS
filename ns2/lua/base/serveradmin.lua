//DAK loader/Base Config

DAK.adminsettings = { groups = { }, users = { } }
DAK.bannedplayers = { }
DAK.serveradmincommands = { }
DAK.serveradmincommandsfunctions = { }
DAK.serveradmincommandshooks = { }

local ServerAdminFileName = "config://ServerAdmin.json"
local ServerAdminWebFileName = "config://ServerAdminWeb.json"
local BannedPlayersFileName = "config://BannedPlayers.json"
local BannedPlayersWebFileName = "config://BannedPlayersWeb.json"
local BannedPlayersWeb = { }
local ServerAdminWebCache = { }
local lastwebupdate = 0
	
local function LoadServerAdminSettings()
	
	local defaultConfig = {
								groups =
									{
									  admin_group = { type = "disallowed", commands = { }, level = 10 },
									  mod_group = { type = "allowed", commands = { "sv_reset", "sv_kick" }, level = 5 }
									},
								users =
									{
									  NsPlayer = { id = 10000001, groups = { "admin_group" }, level = 2 }
									}
							  }
	DAK:WriteDefaultConfigFile(ServerAdminFileName, defaultConfig)
	
	DAK.adminsettings = DAK:LoadConfigFile(ServerAdminFileName) or defaultConfig
	
	assert(DAK.adminsettings.groups, "groups must be defined in " .. ServerAdminFileName)
	assert(DAK.adminsettings.users, "users must be defined in " .. ServerAdminFileName)
	
end

LoadServerAdminSettings()

local function LoadBannedPlayers()
	DAK.bannedplayers = DAK:ConvertFromOldBansFormat(DAK:LoadConfigFile(BannedPlayersFileName)) or { }
end

LoadBannedPlayers()

local function SaveBannedPlayers()
	DAK:SaveConfigFile(BannedPlayersFileName, DAK:ConvertToOldBansFormat(DAK.bannedplayers))
end

local function LoadServerAdminWebSettings()
	ServerAdminWebCache = DAK:LoadConfigFile(ServerAdminWebFileName) or { }
end

local function LoadBannedPlayersWeb()
	BannedPlayersWeb = DAK:LoadConfigFile(BannedPlayersWebFileName) or { }
end

local function SaveServerAdminWebSettings(users)
	DAK:SaveConfigFile(ServerAdminWebFileName, users)
	ServerAdminWebCache = users
end

local function SaveBannedPlayersWeb()
	DAK:SaveConfigFile(BannedPlayersWebFileName, BannedPlayersWeb)
end

//Global Group related functions
function DAK:GetGroupCanRunCommand(groupName, commandName)

	local group = DAK.adminsettings.groups[groupName]
	if not group then
		Shared.Message("Invalid groupname defined : " .. groupName)
		return false
	end
	
	local existsInList = false
	for c = 1, #group.commands do
	
		if group.commands[c] == commandName then
		
			existsInList = true
			break
			
		end
		
	end
	
	if group.type == "allowed" then
		return existsInList
	elseif group.type == "disallowed" then
		return not existsInList
	else
		Shared.Message(string.format("Invalid grouptype - %s defined on group - %s.", tostring(group.type), groupName))
		return false
	end
	
end

function DAK:GetClientCanRunCommand(client, commandName)

	//ServerConsole can run anything
	if client == nil then return true end
	// Convert to the old Steam Id format.
	local steamId = client:GetUserId()
	for name, user in pairs(DAK.adminsettings.users) do
	
		if user.id == steamId then
		
			for g = 1, #user.groups do
			
				local groupName = user.groups[g]
				if DAK:GetGroupCanRunCommand(groupName, commandName) then
					return true
				end
				
			end
			
		end
		
	end

	return false
	
end

function DAK:GetClientIsInGroup(client, gpName)
	local steamId = client:GetUserId()
	for name, user in pairs(DAK.adminsettings.users) do
	
		if user.id == steamId then
			for g = 1, #user.groups do
				local groupName = user.groups[g]
				if groupName == gpName then
					return true
				end
			end
		end
    end
end
	
function DAK:AddSteamIDToGroup(steamId, groupNameToAdd)
	for name, user in pairs(DAK.adminsettings.users) do
		if user.id == steamId then
			for g = 1, #user.groups do
				if user.groups[g] == groupNameToAdd then
					groupNameToAdd = nil
				end
			end
			if groupNameToAdd ~= nil then
				table.insert(user.groups, groupNameToAdd)
			end
			break
		end
	end
end

function DAK:RemoveSteamIDFromGroup(steamId, groupNameToRemove)
	for name, user in pairs(DAK.adminsettings.users) do
		if user.id == steamId then
			for r = #user.groups, 1, -1 do
				if user.groups[r] ~= nil then
					if user.groups[r] == groupNameToRemove then
						table.remove(user.groups, r)
					end
				end
			end
		end
	end
end

//Client Level checking
local function GetSteamIDLevel(steamId)

	local level = 0
	for name, user in pairs(DAK.adminsettings.users) do
	
		if user.id == steamId then
			if user.level ~= nil then
				level = user.level
			else
				for g = 1, #user.groups do
					local groupName = user.groups[g]
					local group = DAK.adminsettings.groups[groupName]
					if group and group.level ~= nil and group.level > level then
						level = group.level							
					end
				end
			end
		end
	end
	if tonumber(level) == nil then
		level = 0
	end
	
	return level
end

local function GetClientLevel(client)
	local steamId = client:GetUserId()
	if steamId == nil then return 0 end
	return GetSteamIDLevel(steamId)
end

local function GetPlayerLevel(player)
	local client = Server.GetOwner(player)
	if client == nil then return 0 end
	local steamId = client:GetUserId()
	if steamId == nil then return 0 end
	return GetSteamIDLevel(steamId)
end

local function GetObjectLevel(target)
	if tonumber(target) ~= nil then
		return GetSteamIDLevel(tonumber(target))
	elseif DAK:VerifyClient(target) ~= nil then
		return GetClientLevel(target)
	elseif Server.GetOwner(target) ~= nil then
		return GetPlayerLevel(target)
	end
	return 0
end

local function EmptyServerAdminCommand()
end

function DAK:GetLevelSufficient(client, targetclient)
	if client == nil then return true end
	if targetclient == nil then return false end
	return GetObjectLevel(client) >= GetObjectLevel(targetclient)
end

function DAK:GetServerAdminFunction(commandName)
	return DAK.serveradmincommandsfunctions[commandName]
end

function DAK:DeregisterServerAdminCommand(commandName)
	DAK.serveradmincommandsfunctions[commandName] = EmptyServerAdminCommand
end

local function CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)

	local fixedCommandName = string.gsub(commandName, "Console_", "")
	DAK.serveradmincommandsfunctions[commandName] = function(client, ...)
	
		if not client or optionalAlwaysAllowed == true or DAK:GetClientCanRunCommand(client, fixedCommandName, true) then
			return commandFunction(client, ...)
		end
		
	end
	
	table.insert(DAK.serveradmincommands, { name = fixedCommandName, help = helpText or "No help provided" })
	if DAK.serveradmincommandshooks[commandName] == nil then
		DAK.serveradmincommandshooks[commandName] = true
		Event.Hook(commandName, DAK:GetServerAdminFunction(commandName))
	end
	
end

//Internal Globals
function DAK:CreateServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
	//Prefered function for creating ServerAdmin commands, not checked against blacklist
	CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
end

function CreateServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
	//Should catch other plugins commands, filters against blacklist to prevent defaults from being registered twice.
	for c = 1, #DAK.config.baseadmincommands.kBlacklistedCommands do
		local command = DAK.config.baseadmincommands.kBlacklistedCommands[c]
		if commandName == command then
			return
		end
	end
	//Assume its not blacklisted and proceed.
	CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
end

local function tablemerge(tab1, tab2)
	if tab2 ~= nil then
		for k, v in pairs(tab2) do
			if (type(v) == "table") and (type(tab1[k] or false) == "table") then
				tablemerge(tab1[k], tab2[k])
			else
				tab1[k] = v
			end
		end
	end
	return tab1
end

local function ProcessWebResponse(response)
	local sstart = string.find(response,"<body>")
	if type(sstart) == "number" then
		local rstring = string.sub(response, sstart)
		if rstring then
			rstring = rstring:gsub("<body>\n", "{")
			rstring = rstring:gsub("<body>", "{")
			rstring = rstring:gsub("</body>", "}")
			rstring = rstring:gsub("<div id=\"username\"> ", "\"")
			rstring = rstring:gsub(" </div> <div id=\"steamid\"> ", "\": { \"id\": ")
			rstring = rstring:gsub(" </div> <div id=\"group\"> ", ", \"groups\": [ \"")
			rstring = rstring:gsub("\\,", "\", \"")
			rstring = rstring:gsub(" </div> <br>", "\" ] },")
			rstring = rstring:gsub("\n", "")
			return json.decode(rstring)
		end
	end
	return nil
end

local function OnServerAdminWebResponse(response)
	if response then
		local addusers = ProcessWebResponse(response)
		if addusers and ServerAdminWebCache ~= addusers then
			//If loading from file, that wont update so its not an issue.  However web queries are realtime so admin abilities can expire mid game and/or be revoked.  Going to have this reload and
			//purge old list, will insure greater accuracy (still has a couple loose ends).  Considering also adding a periodic check, or a check on command exec (still wouldnt be perfect), this seems good for now.
			LoadServerAdminSettings()
			DAK.adminsettings.users = tablemerge(DAK.adminsettings.users, addusers)
			SaveServerAdminWebSettings(addusers)
		end
	end
end

local function OnServerAdminBansWebResponse(response)
	if response then
		local bannedusers = ProcessWebResponse(response)
		if bannedusers and BannedPlayersWeb ~= bannedusers then
			BannedPlayersWeb = bannedusers
			SaveBannedPlayersWeb()
		end
	end
end

local function OnPlayerBannedResponse(response)
	if response == "TRUE" then
		//ban successful, update webbans using query URL.
		DAK:QueryForBansList()
	end
end

local function OnPlayerUnBannedResponse(response)
	if response == "TRUE" then
		//Unban successful, anything needed here?
	end
end

function DAK:QueryForAdminList()
	if DAK.config.serveradmin.QueryURL ~= "" then
		Shared.SendHTTPRequest(DAK.config.serveradmin.QueryURL, "GET", OnServerAdminWebResponse)
	end
end

function DAK:QueryForBansList()
	if DAK.config.serveradmin.BansQueryURL ~= "" then
		Shared.SendHTTPRequest(DAK.config.serveradmin.BansQueryURL, "GET", OnServerAdminBansWebResponse)
	end
end

local function OnServerAdminClientConnect(client)
	local isBanned, Reason = DAK:IsClientBanned(client)
	if isBanned then
		client.disconnectreason = Reason
		Server.DisconnectClient(client)
	end
	local tt = Shared.GetTime()
	if tt > DAK.config.serveradmin.MapChangeDelay and (lastwebupdate == nil or (lastwebupdate + DAK.config.serveradmin.UpdateDelay) < tt) then
		DAK:QueryForAdminList()
		DAK:QueryForBansList()
		lastwebupdate = tt
	end
end

DAK:RegisterEventHook("OnClientConnect", OnServerAdminClientConnect, 6, "serveradmin")

local function CheckServerAdminQueries()
	if DAK.config.serveradmin.QueryURL ~= "" and ServerAdminWebCache == nil then
		Shared.Message("ServerAdmin WebQuery failed, falling back on cached list.")
		DAK.adminsettings.users = tablemerge(DAK.adminsettings.users, LoadServerAdminWebSettings())
	end
	if DAK.config.serveradmin.BansQueryURL ~= "" and BannedPlayersWeb == nil then
		Shared.Message("Bans WebQuery failed, falling back on cached list.")
		LoadBannedPlayersWeb()
	end
	return false
end

local function UpdateClientConnectionTime()
	if DAK.settings.connectedclients == nil then
		DAK.settings.connectedclients = { }
	end
	for id, conntime in pairs(DAK.settings.connectedclients) do
		if DAK:GetClientMatchingSteamId(tonumber(id)) == nil then
			DAK.settings.connectedclients[id] = nil
		end
	end
	DAK:SaveSettings()
	return false
end

local function DelayedServerCommandRegistration()
	DAK:QueryForAdminList()
	DAK:QueryForBansList()
	DAK:SetupTimedCallBack(CheckServerAdminQueries, DAK.config.serveradmin.QueryTimeout)
	DAK:SetupTimedCallBack(UpdateClientConnectionTime, DAK.config.serveradmin.ReconnectTime)
end

DAK:RegisterEventHook("OnPluginInitialized", DelayedServerCommandRegistration, 5, "serveradmin")

local kMaxPrintLength = 128
local kServerAdminMessage =
{
	message = string.format("string (%d)", kMaxPrintLength),
}
Shared.RegisterNetworkMessage("ServerAdminPrint", kServerAdminMessage)

function ServerAdminPrint(client, message)

	if client then
	
		// First we must split up the message into a list of messages no bigger than kMaxPrintLength each.
		local messageList = { }
		while string.len(message) > kMaxPrintLength do
		
			local messagePart = string.sub(message, 0, kMaxPrintLength)
			table.insert(messageList, messagePart)
			message = string.sub(message, kMaxPrintLength + 1)
			
		end
		table.insert(messageList, message)
		
		for m = 1, #messageList do
			Server.SendNetworkMessage(client:GetControllingPlayer(), "ServerAdminPrint", { message = messageList[m] }, true)
		end
		
	else
	
		Shared.Message(message)
		
	end
	
end

function DAK:IsClientBanned(client)
	if client ~= nil then
		return DAK:IsSteamIDBanned(client:GetUserId())		
	end
	return false, ""
end

function DAK:IsSteamIDBanned(playerId)
	playerId = tonumber(playerId)
	if playerId ~= nil then
		local bentry = DAK.bannedplayers[playerId]
		if bentry ~= nil then
			local now = Shared.GetSystemTime()
			if bentry.time == 0 or now < bentry.time then
				return true, bentry.reason or "Banned"
			else
				LoadBannedPlayers()
				DAK.bannedplayers[playerId] = nil
				SaveBannedPlayers()
			end
		end
		local bwentry = BannedPlayersWeb[playerId]
		if bwentry ~= nil then
			local now = Shared.GetSystemTime()
			if bwentry.time == 0 or now < bwentry.time then
				return true, bwentry.reason or "Banned"
			else
				BannedPlayersWeb[playerId] = nil
				SaveBannedPlayersWeb()
			end
		end
	end
	return false
end

function DAK:UnBanSteamID(playerId)
	playerId = tonumber(playerId)
	if playerId ~= nil then
		LoadBannedPlayers()
		if DAK.bannedplayers[playerId] ~= nil then
			DAK.bannedplayers[playerId] = nil
			SaveBannedPlayers()
			return true
		end
		if BannedPlayersWeb[playerId] ~= nil then
			//Submit unban with key
			//DAK.config.serveradmin.UnBanSubmissionURL
			//DAK.config.serveradmin.CryptographyKey
			//OnPlayerUnBannedResponse
			//Shared.SendHTTPRequest(DAK.config.serveradmin.UnBanSubmissionURL, "GET", OnPlayerUnBannedResponse)
			return true
		end
	end
	return false
end

function DAK:AddSteamIDBan(playerId, pname, duration, breason)
	playerId = tonumber(playerId)
	if playerId ~= nil then
		local bannedUntilTime = Shared.GetSystemTime()
		duration = tonumber(duration)
		if duration == nil or duration <= 0 then
			bannedUntilTime = 0
		else
			bannedUntilTime = bannedUntilTime + (duration * 60)
		end
		local bentry = { name = pname, reason = breason, time = bannedUntilTime }
		
		if DAK.config.serveradmin.BanSubmissionURL ~= "" then
			//Submit ban with key, working on logic to hash key
			//Should these be both submitted to database and logged on server?  My thinking is no here, so going with that moving forward.
			//DAK.config.serveradmin.BanSubmissionURL
			//DAK.config.serveradmin.CryptographyKey
			//Will also want ban response function to reload web bans.
			//OnPlayerBannedResponse
			//Shared.SendHTTPRequest(DAK.config.serveradmin.BanSubmissionURL, "POST", bentry, OnPlayerBannedResponse)
		else
			LoadBannedPlayers()
			DAK.bannedplayers[playerId] = bentry
			SaveBannedPlayers()
		end
		
		return true
	end
	return false
end

local function OnCommandListAdmins(client)

	if DAK.adminsettings ~= nil then
		if DAK.adminsettings.groups ~= nil then
			for group, commands in pairs(DAK.adminsettings.groups) do
				ServerAdminPrint(client, string.format(group .. " - " .. ToString(commands)))
			end
		end

		if DAK.adminsettings.users ~= nil then
			for name, user in pairs(DAK.adminsettings.users) do
				local online = DAK:GetClientMatchingSteamId(user.id) ~= nil
				ServerAdminPrint(client, string.format(name .. " - " .. ToString(user) .. ConditionalValue(online, " - Online", " - Offline")))
			end
		end
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_listadmins", OnCommandListAdmins, "Will list all groups and admins.")

local function ListBans(client)

	ServerAdminPrint(client, "Current Bans Listing:")
	for id, entry in pairs(DAK.bannedplayers) do
	
		local timeLeft = entry.time == 0 and "Forever" or (((entry.time - Shared.GetSystemTime()) / 60) .. " minutes")
		ServerAdminPrint(client, "Name: " .. entry.name .. " Id: " .. id .. " Time Remaining: " .. timeLeft .. " Reason: " .. (entry.reason or "Not provided"))
		
	end
	
	for id, entry in pairs(BannedPlayersWeb) do
	
		local timeLeft = entry.time == 0 and "Forever" or (((entry.time - Shared.GetSystemTime()) / 60) .. " minutes")
		ServerAdminPrint(client, "Name: " .. entry.name .. " Id: " .. id .. " Time Remaining: " .. timeLeft .. " Reason: " .. (entry.reason or "Not provided"))
		
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_listbans", ListBans, "Lists the banned players")

local function OnCommandWho(client)

	local onlineusers = false
	if DAK.adminsettings ~= nil then
		if DAK.adminsettings.users ~= nil then
			for name, user in pairs(DAK.adminsettings.users) do
				local uclient = DAK:GetClientMatchingSteamId(user.id)
				local online = (uclient ~= nil)
				if online then
					local player = uclient:GetControllingPlayer()
					if player ~= nil then
						local pname = player:GetName()
						ServerAdminPrint(client, string.format(pname .. " - " .. name .. " - " .. ToString(user)))
						onlineusers = true
					end	
				end
			end
		end
	end
	if not onlineusers then
		ServerAdminPrint(client, string.format("No admins online."))
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_who", OnCommandWho, "Will list all online admins.", true)

local function PrintHelpForCommand(client, optionalCommand)

	for c = 1, #DAK.serveradmincommands do
	
		local command = DAK.serveradmincommands[c]
		if optionalCommand == command.name or optionalCommand == nil then
		
			if not client or DAK:GetClientCanRunCommand(client, command.name, false) then
				ServerAdminPrint(client, command.name .. ": " .. command.help)
			elseif optionalCommand then
				ServerAdminPrint(client, "You do not have access to " .. optionalCommand)
			end
			
		end
		
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_help", PrintHelpForCommand, "Prints help for all commands or the specified command.", true)

//Block Default ServerAdmin load
DAK:OverrideScriptLoad("lua/ServerAdmin.lua")