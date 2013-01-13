//DAKLoader SV Commands

//******************************************************************************************************************
//Extra Server Admin commands
//******************************************************************************************************************

local function OnCommandRCON(client, ...)

	 local rconcommand = StringConcatArgs(...)
	 if rconcommand ~= nil and client ~= nil then
		Shared.Message(string.format("%s executed command %s.", client:GetUserId(), rconcommand))
		Shared.ConsoleCommand(rconcommand)
		ServerAdminPrint(client, string.format("Command %s executed.", rconcommand))
		if client ~= nil then 
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_rcon", client, " " .. rconcommand)
			end
		end
	end

end

DAKCreateServerAdminCommand("Console_sv_rcon", OnCommandRCON, "<command> Will execute specified command on server.")

local function OnCommandAllTalk(client)

	if client ~= nil then
		if kDAKSettings then
			kDAKSettings.AllTalk = not kDAKSettings.AllTalk
		else
			kDAKSettings = { }
			kDAKSettings.AllTalk = true
		end
		ServerAdminPrint(client, string.format("AllTalk has been %s.", ConditionalValue(kDAKSettings.AllTalk,"enabled", "disabled")))
		local player = client:GetControllingPlayer()
		if player ~= nil then
			PrintToAllAdmins("sv_alltalk", client)
		end
	end

end

DAKCreateServerAdminCommand("Console_sv_alltalk", OnCommandAllTalk, "Will toggle the alltalk setting on server.")

local function OnCommandListPlugins(client)

	if client ~= nil and kDAKConfig then
		for k,v in pairs(kDAKConfig) do
			local plugin = k
			local version = kDAKRevisions[plugin]
			if plugin ~= nil then
				if version ~= nil then
					ServerAdminPrint(client, string.format("Plugin %s v%.1f is loaded.", plugin, version))
					//Shared.Message(string.format("Plugin %s v%.1f is loaded.", plugin, version))
				end
			end
		end
	end

end

DAKCreateServerAdminCommand("Console_sv_listplugins", OnCommandListPlugins, "Will list the state of all plugins.")

local function OnCommandListMap(client)
	local matchingFiles = { }
	Shared.GetMatchingFileNames("maps/*.level", false, matchingFiles)

	for _, mapFile in pairs(matchingFiles) do
		local _, _, filename = string.find(mapFile, "maps/(.*).level")
		if client ~= nil then
			ServerAdminPrint(client, string.format(filename))
		end		
	end
end

DAKCreateServerAdminCommand("Console_sv_maps", OnCommandListMap, "Will list all the maps currently on the server.")

local function OnCommandCheats(client, parm)
	local num = tonumber(parm)
	if client ~= nil and num ~= nil then
		ServerAdminPrint(client, string.format("Command sv_cheats %s executed.", parm))
		Shared.ConsoleCommand("cheats " .. parm)
		local player = client:GetControllingPlayer()
		if player ~= nil then
			PrintToAllAdmins("sv_cheats", client, " " .. parm)
		end
	end
end

DAKCreateServerAdminCommand("Console_sv_cheats", OnCommandCheats, "<1/0> Will enable/disable cheats.")

local function OnCommandKillServer(client)

	if client ~= nil then 
		ServerAdminPrint(client, string.format("Command sv_killserver executed."))
		local player = client:GetControllingPlayer()
		if player ~= nil then
			PrintToAllAdmins("sv_killserver", client)
		end
	end
	
	//Shared.ConsoleCommand("exit")
	//They finally fixed seek crash bug :<
end

//DAKCreateServerAdminCommand("Console_sv_killserver", OnCommandKillServer, "Will crash the server (lol).")

//Load Plugins
local function LoadPlugins()
	if kDAKConfig == nil or kDAKConfig == { } or kDAKConfig.DAKLoader == nil or kDAKConfig.DAKLoader == { } or kDAKConfig.DAKLoader.kPluginsList == nil then
		DAKGenerateDefaultDAKConfig(true)
	end
	if kDAKConfig ~= nil and kDAKConfig.DAKLoader ~= nil  then
		for i = 1, #kDAKConfig.DAKLoader.kPluginsList do
			local filename = string.format("lua/plugins/plugin_%s.lua", kDAKConfig.DAKLoader.kPluginsList[i])
			Script.Load(filename)
		end
	else
		Shared.Message("Something may be wrong with your config file.")
	end
end

LoadPlugins()

DAKCreateServerAdminCommand("Console_sv_reloadplugins", LoadPlugins, "Reloads all plugins.")