//DAK Loader/Base Config

if Server then
	
	local settings = { groups = { }, users = { } }
	
	local DAKServerAdminFileName = "config://ServerAdmin.json"
	local DAKServerAdminWebFileName = "config://ServerAdminWeb.json"
	local ServerAdminWebCache
	local initialwebupdate = 0
	local lastwebupdate = 0
		
    local function LoadServerAdminSettings()
    
        Shared.Message("Loading " .. DAKServerAdminFileName)
		
        local initialState = { groups = { }, users = { } }
        settings = initialState
		
		local configFile = io.open(DAKServerAdminFileName, "r")
        if configFile then
            local fileContents = configFile:read("*all")
            settings = json.decode(fileContents) or initialState
			io.close(configFile)
		else
		    local defaultConfig = {
									groups =
										{
										  admin_group = { type = "disallowed", commands = { }, level = 10 },
										  mod_group = { type = "allowed", commands = { "sv_reset", "sv_ban" }, level = 5 }
										},
									users =
										{
										  NsPlayer = { id = 10000001, groups = { "admin_group" }, level = 2 }
										}
								  }
			local configFile = io.open(DAKServerAdminFileName, "w+")
			configFile:write(json.encode(defaultConfig, { indent = true, level = 1 }))
			io.close(configFile)
        end
        assert(settings.groups, "groups must be defined in " .. DAKServerAdminFileName)
        assert(settings.users, "users must be defined in " .. DAKServerAdminFileName)
        
    end
	
    LoadServerAdminSettings()
	
	local function LoadServerAdminWebSettings()
    
        Shared.Message("Loading " .. DAKServerAdminWebFileName)
		
		local configFile = io.open(DAKServerAdminWebFileName, "r")
		local users
        if configFile then
            local fileContents = configFile:read("*all")
            users = json.decode(fileContents)
			io.close(configFile)
        end
		ServerAdminWebCache = users
		return users
        
    end
	
	local function SaveServerAdminWebSettings(users)
		local configFile = io.open(DAKServerAdminWebFileName, "w+")
		if configFile ~= nil and users ~= nil then
			configFile:write(json.encode(users, { indent = true, level = 1 }))
			io.close(configFile)
		end
		ServerAdminWebCache = users
	end	
    
    function DAKGetGroupCanRunCommand(groupName, commandName)
    
        local group = settings.groups[groupName]
        if not group then
            error("There is no group defined with name: " .. groupName)
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
            error("Only \"allowed\" and \"disallowed\" are valid terms for the type of the admin group")
        end
        
    end
    
    function DAKGetClientCanRunCommand(client, commandName)
    
        // Convert to the old Steam Id format.
        local steamId = client:GetUserId()
        for name, user in pairs(settings.users) do
        
            if user.id == steamId then
            
                for g = 1, #user.groups do
                
                    local groupName = user.groups[g]
                    if DAKGetGroupCanRunCommand(groupName, commandName) then
                        return true
                    end
                    
                end
                
            end
            
        end

        return false
        
    end

    function DAKGetClientIsInGroup(client, gpName)
		local steamId = client:GetUserId()
		for name, user in pairs(settings.users) do
        
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
	
	local function CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)

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
	
	local function GetSteamIDLevel(steamId)
    
		local level = 0
        for name, user in pairs(settings.users) do
        
            if user.id == steamId then
				if user.level ~= nil then
					level = user.level
				else
					for g = 1, #user.groups do
						local groupName = user.groups[g]
						local group = settings.groups[groupName]
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

	local function AddSteamIDToGroup(steamId, groupNameToAdd)
        for name, user in pairs(settings.users) do
            if user.id == steamId then
				for g = 1, #user.groups do
					if user.groups[g] == groupNameToAdd then
						groupNameToAdd = nil
					end
				end
				if groupNameToAdd ~= nil then
					user.groups.insert(groupNameToAdd)
				end
				break
            end
        end
    end
	
	local function RemoveSteamIDFromGroup(steamId, groupNameToRemove)
        for name, user in pairs(settings.users) do
            if user.id == steamId then
				user.groups.remove(groupNameToRemove)
				break
            end
        end
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
		elseif VerifyClient(target) ~= nil then
			return GetClientLevel(target)
		elseif Server.GetOwner(target) ~= nil then
			return GetPlayerLevel(target)
		end
		return 0
	end
	
	function DAKGetLevelSufficient(client, targetclient)
		if client == nil then return true end
		if targetclient == nil then return false end
		return GetObjectLevel(client) >= GetObjectLevel(targetclient)
	end
	
	//Internal Globals
	function DAKCreateServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
		//Prefered function for creating ServerAdmin commands, not checked against blacklist
		CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
	end
	
	function CreateServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
		//Should catch other plugins commands, filters against blacklist to prevent defaults from being registered twice.
		for c = 1, #kDAKConfig.BaseAdminCommands.kBlacklistedCommands do
			local command = kDAKConfig.BaseAdminCommands.kBlacklistedCommands[c]
			if commandName == command then
				return
			end
		end
		//Assume its not blacklisted and proceed.
		CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
	end

	//Client ID Translators
	function VerifyClient(client)
	
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		for r = #playerList, 1, -1 do
			if playerList[r] ~= nil then
				local plyr = playerList[r]
				local clnt = playerList[r]:GetClient()
				if plyr ~= nil and clnt ~= nil then
					if client ~= nil and clnt == client then
						return clnt
					end
				end
			end				
		end
		return nil
	
	end
	
	function GetPlayerMatchingGameId(id)
	
		assert(type(id) == "number")
		if id > 0 and id <= #kDAKGameID then
			local client = kDAKGameID[id]
			if client ~= nil and VerifyClient(client) ~= nil then
				return client:GetControllingPlayer()
			end
		end
		
		return nil
		
	end
	
	function GetClientMatchingGameId(id)
	
		assert(type(id) == "number")
		if id > 0 and id <= #kDAKGameID then
			local client = kDAKGameID[id]
			if client ~= nil and VerifyClient(client) ~= nil then
				return client
			end
		end
		
		return nil
		
	end
	
	function GetGameIdMatchingPlayer(player)
	
		local client = Server.GetOwner(player)
		if client ~= nil and VerifyClient(client) ~= nil then
			for p = 1, #kDAKGameID do
			
				if client == kDAKGameID[p] then
					return p
				end
				
			end
		end
		
		return 0
	end
	
	function GetGameIdMatchingClient(client)
	
		if client ~= nil and VerifyClient(client) ~= nil then
			for p = 1, #kDAKGameID do
			
				if client == kDAKGameID[p] then
					return p
				end
				
			end
		end
		
		return 0
	end
	
	function GetClientMatchingSteamId(steamId)

		assert(type(steamId) == "number")
		
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		for r = #playerList, 1, -1 do
			if playerList[r] ~= nil then
				local plyr = playerList[r]
				local clnt = playerList[r]:GetClient()
				if plyr ~= nil and clnt ~= nil then
					if clnt:GetUserId() == steamId then
						return clnt
					end
				end
			end				
		end
		
		return nil
		
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
		return nil
	end
	
	local function OnServerAdminWebResponse(response)
		if response then
			local addusers = ProcessWebResponse(response)
			if addusers and ServerAdminWebCache ~= addusers then
				//If loading from file, that wont update so its not an issue.  However web queries are realtime so admin abilities can expire mid game and/or be revoked.  Going to have this reload and
				//purge old list, will insure greater accuracy (still has a couple loose ends).  Considering also adding a periodic check, or a check on command exec (still wouldnt be perfect), this seems good for now.
				LoadServerAdminSettings()
				settings.users = tablemerge(settings.users, addusers)
				SaveServerAdminWebSettings(addusers)
			end
		end
	end
	
	local function QueryForAdminList()
		Shared.SendHTTPRequest(kDAKConfig.DAKLoader.ServerAdmin.kQueryURL, "GET", OnServerAdminWebResponse)
		lastwebupdate = Shared.GetTime()
	end
	
	local function OnServerAdminClientConnect(client)
		local tt = Shared.GetTime()
		if tt > kDAKConfig.DAKLoader.ServerAdmin.kMapChangeDelay and (lastwebupdate == nil or (lastwebupdate + kDAKConfig.DAKLoader.ServerAdmin.kUpdateDelay) < tt) and kDAKConfig.DAKLoader.ServerAdmin.kQueryURL ~= "" and initialwebupdate ~= 0 then
			QueryForAdminList()
		end
	end
	
	DAKRegisterEventHook(kDAKOnClientConnect, OnServerAdminClientConnect, 5)

	local function DelayedServerCommandRegistration()
		if kDAKConfig.DAKLoader.ServerAdmin.kQueryURL == "" then
			DAKDeregisterEventHook(kDAKOnServerUpdate, DelayedServerCommandRegistration)
			return
		end
		if initialwebupdate == 0 then
			QueryForAdminList()
			initialwebupdate = Shared.GetTime() + kDAKConfig.DAKLoader.ServerAdmin.kQueryTimeout	
		end
		if initialwebupdate < Shared.GetTime() then
			if ServerAdminWebCache == nil then
				Shared.Message("ServerAdmin WebQuery failed, falling back on cached list.")
				settings.users = tablemerge(settings.users, LoadServerAdminWebSettings())
				initialwebupdate = 0
			end
			DAKDeregisterEventHook(kDAKOnServerUpdate, DelayedServerCommandRegistration)
		end
	end
	
	DAKRegisterEventHook(kDAKOnServerUpdate, DelayedServerCommandRegistration, 5)
	
	local function OnCommandListAdmins(client)
	
		if settings ~= nil then
			if settings.groups ~= nil then
				for group, commands in pairs(settings.groups) do
					if client ~= nil then
						ServerAdminPrint(client, string.format(group .. " - " .. ToString(commands)))
					end		
				end
			end
	
			if settings.users ~= nil then
				for name, user in pairs(settings.users) do
					local online = GetClientMatchingSteamId(user.id) ~= nil
					if client ~= nil then
						ServerAdminPrint(client, string.format(name .. " - " .. ToString(user) .. ConditionalValue(online, " - Online", " - Offline")))
					end		
				end
			end
		end
		
	end

    DAKCreateServerAdminCommand("Console_sv_listadmins", OnCommandListAdmins, "Will list all groups and admins.")
	
	local function OnCommandWho(client)
	
		if settings ~= nil then	
			if settings.users ~= nil then
				for name, user in pairs(settings.users) do
					local uclient = GetClientMatchingSteamId(user.id)
					local online = (uclient ~= nil)
					if online then
						local player = uclient:GetControllingPlayer()
						if player ~= nil then
							local pname = player:GetName()
							ServerAdminPrint(client, string.format(pname .. " - " .. name .. " - " .. ToString(user)))
						end	
					end
				end
			end
		end
		
	end

    DAKCreateServerAdminCommand("Console_sv_who", OnCommandWho, "Will list all online admins.", true)
	
	//This is so derp, but re-registering function to override builtin admin system without having to modify core NS2 files
	//Using registration of ServerAdminPrint network message for the correct timing
	local originalNS2CreateServerAdminCommand
	
	originalNS2CreateServerAdminCommand = Class_ReplaceMethod("Shared", "RegisterNetworkMessage", 
		function(parm1, parm2)
		
			if parm1 == "ServerAdminPrint" then
				if kDAKConfig and kDAKConfig.BaseAdminCommands and DAKIsPluginEnabled("baseadmincommands") then
					function CreateServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
						//Should catch other plugins commands, filters against blacklist to prevent defaults from being registered twice.
						for c = 1, #kDAKConfig.BaseAdminCommands.kBlacklistedCommands do
							local command = kDAKConfig.BaseAdminCommands.kBlacklistedCommands[c]
							if commandName == command then
								return
							end
						end
						//Assume its not blacklisted and proceed.
						CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
					end
				end
			end
			if parm2 == nil then
				originalNS2CreateServerAdminCommand(parm1)
			else
				originalNS2CreateServerAdminCommand(parm1, parm2)
			end

		end
	)
	
end