//NS2 Server Redirection

local function OnCommandSwitchServers(client, server)
	if client ~= nil then
		server = tonumber(server)
		if server == nil or server < 0 or server > #DAK.config.serverredirect.Servers then
			for s = 1, #DAK.config.serverredirect.Servers do
				DAK:DisplayMessageToClient(client, "AvailableServers", DAK.config.serverredirect.Servers[s], s)
			end
		elseif DAK.config.serverredirect.Servers[server] ~= nil then
			DAK:DisplayMessageToClient(client, "RedirectMessage", DAK.config.serverredirect.Servers[server])
			local player = client:GetControllingPlayer()
			if player ~= nil then
				Server.SendCommand(player, string.format("connect %s", DAK.config.serverredirect.Servers[server]))
			end
		end
	end
end

Event.Hook("Console_switchservers",               OnCommandSwitchServers)

DAK:RegisterChatCommand(DAK.config.serverredirect.SwitchServersChatCommands, OnCommandSwitchServers, true)