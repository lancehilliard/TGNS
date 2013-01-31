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

/*local function OnCommandCheats(client)
	if client ~= nil then
		local statuschange = ConditionalValue(Shared.GetCheatsEnabled(), 0, 1)
		ServerAdminPrint(client, string.format("Cheats have been %s.", ConditionalValue(statuschange == 1,"enabled", "disabled")))
		Shared.ConsoleCommand("cheats " .. statuschange)
		local player = client:GetControllingPlayer()
		if player ~= nil then
			PrintToAllAdmins("sv_cheats", client, " " .. statuschange)
		end
	end
end

DAKCreateServerAdminCommand("Console_sv_cheats", OnCommandCheats, "Will enable/disable cheats.")*/

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
	Server.GetClientAddress(nil)
	//Alriiight found a new crash bug
end

DAKCreateServerAdminCommand("Console_sv_killserver", OnCommandKillServer, "Will crash the server (lol).")