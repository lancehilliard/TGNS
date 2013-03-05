//DAKloader SV Commands

//******************************************************************************************************************
//Extra Server Admin commands
//******************************************************************************************************************

local function OnCommandRCON(client, ...)

	 local rconcommand = StringConcatArgs(...)
	 if rconcommand ~= nil and client ~= nil then
		//Shared.Message(string.format("%s executed command %s.", client:GetUserId(), rconcommand))
		Shared.ConsoleCommand(rconcommand)
		ServerAdminPrint(client, string.format("Command %s executed.", rconcommand))
		DAK:PrintToAllAdmins("sv_rcon", client, " " .. rconcommand)
	end

end

DAK:CreateServerAdminCommand("Console_sv_rcon", OnCommandRCON, "<command> Will execute specified command on server.")

local function OnCommandAllTalk(client)

	if DAK.settings then
		DAK.settings.AllTalk = not DAK.settings.AllTalk
	else
		DAK.settings = { }
		DAK.settings.AllTalk = true
	end
	
	ServerAdminPrint(client, string.format("AllTalk has been %s.", ConditionalValue(DAK.settings.AllTalk,"enabled", "disabled")))
	DAK:PrintToAllAdmins("sv_alltalk", client)

end

DAK:CreateServerAdminCommand("Console_sv_alltalk", OnCommandAllTalk, "Will toggle the alltalk setting on server.")

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

DAK:CreateServerAdminCommand("Console_sv_maps", OnCommandListMap, "Will list all the maps currently on the server.")

local function OnCommandKillServer(client)

	ServerAdminPrint(client, string.format("Command sv_killserver executed."))
	DAK:PrintToAllAdmins("sv_killserver", client)
	
	//They finally fixed seek crash bug :<
	Server.GetClientAddress(nil)
	//Alriiight found a new crash bug
end

DAK:CreateServerAdminCommand("Console_sv_killserver", OnCommandKillServer, "Will crash the server (lol).")