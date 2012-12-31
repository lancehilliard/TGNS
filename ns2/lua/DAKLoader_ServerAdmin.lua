//DAK Loader/Base Config

if Server then
	
	local settings = { groups = { }, users = { } }
	
	local DAKServerAdminFileName = "config://ServerAdmin.json"
	local DelayedServerAdminCommands = { }
	local DelayedServerCommands = false
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
	
	local function GetClientLevel(client)
        local steamId = client:GetUserId()
		if steamId == nil then return 0 end
        return DAKGetSteamIDLevel(steamId)
    end
	
	local function GetPlayerLevel(player)
		local client = Server.GetOwner(player)
        local steamId = client:GetUserId()
		if steamId == nil then return 0 end
        return DAKGetSteamIDLevel(steamId)
    end
	
	local function GetObjectLevel(target)
		if tonumber(target) ~= nil then
			return DAKGetSteamIDLevel(tonumber(target))
		elseif Server.GetOwner(target) ~= nil then
			return GetPlayerLevel(target)
		elseif VerifyClient(target) ~= nil then
			return GetClientLevel(target)
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
		local ServerAdminCmd = { cmdName = commandName, cmdFunction = commandFunction, helpT = helpText, opt = optionalAlwaysAllowed }
		table.insert(DelayedServerAdminCommands, ServerAdminCmd)
		DelayedServerCommands = true
	end
	
	function RegisterServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
		if kDAKConfig and kDAKConfig.BaseAdminCommands and CreateBaseServerAdminCommand then
			CreateBaseServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
		else
			CreateServerAdminCommand(commandName, commandFunction, helpText, optionalAlwaysAllowed)
		end
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
		for k, v in pairs(tab2) do
			if (type(v) == "table") and (type(tab1[k] or false) == "table") then
				tablemerge(tab1[k], tab2[k])
			else
				tab1[k] = v
			end
		end
		return tab1
	end
	
	local function OnServerAdminWebResponse(response)
		if response then
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
				local addusers = json.decode(rstring)
				if addusers then
					settings.users = tablemerge(settings.users, addusers)
				end
			end
		end
	end
	
	local function QueryForAdminList()
		if kDAKConfig.DAKLoader.ServerAdmin.kQueryURL ~= "" then
			Shared.SendHTTPRequest(kDAKConfig.DAKLoader.ServerAdmin.kQueryURL, "GET", function(response)
					OnServerAdminWebResponse(response)
			end)
		end
		lastwebupdate = Shared.GetTime()
	end
	
	local function OnServerAdminClientConnect(client)
		local tt = Shared.GetTime()
		if tt > kDAKConfig.DAKLoader.ServerAdmin.kMapChangeDelay and (lastwebupdate == nil or (lastwebupdate + kDAKConfig.DAKLoader.ServerAdmin.kUpdateDelay) < tt) and kDAKConfig.DAKLoader.ServerAdmin.kQueryURL ~= "" then
			QueryForAdminList()
		end
		return true
	end
	
	table.insert(kDAKOnClientConnect, function(client) return OnServerAdminClientConnect(client) end)
	
	local function DelayedServerCommandRegistration()	
		if DelayedServerCommands then
			if #DelayedServerAdminCommands > 0 then
				for i = 1, #DelayedServerAdminCommands do
					local ServerAdminCmd = DelayedServerAdminCommands[i]
					RegisterServerAdminCommand(ServerAdminCmd.cmdName, ServerAdminCmd.cmdFunction, ServerAdminCmd.helpT, ServerAdminCmd.opt)
				end
			end
			QueryForAdminList()
			Shared.Message("Server Commands Registered.")
			DelayedServerAdminCommands = nil
			//DelayedServerCommands = false
		end
		DAKDeregisterEventHook(kDAKOnServerUpdate, DelayedServerCommandRegistration)
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