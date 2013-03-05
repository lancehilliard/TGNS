//loader Plugin loader

//Load Plugins
local function LoadPlugins()
	
	if DAK.config ~= nil and DAK.config.loader ~= nil then
		local DR = DAK.revisions["loader"]
		for i = 1, #DAK.config.loader.PluginsList do
			local Plugin = DAK.config.loader.PluginsList[i]
			if Plugin ~= nil and Plugin ~= "" then
				local filename = string.format("lua/plugins/%s.lua", Plugin)
				Script.Load(filename)
				if DR == DAK.revisions[Plugin] then
					//Shared.Message(string.format("Plugin %s loaded.", Plugin))
				else
					Shared.Message(string.format("Plugin %s loaded, v%s loader - v%s Plugin version mismatch.", Plugin, DR, DAK.revisions[Plugin]))
				end
			end
		end
	else
		Shared.Message("Something may be wrong with your config file.")
	end

end

LoadPlugins()

local function ResetandLoadPlugins()
	DAK:ExecuteEventHooks("OnPluginUnloaded")
	LoadPlugins()
end

DAK:CreateServerAdminCommand("Console_sv_reloadplugins", ResetandLoadPlugins, "Reloads all plugins.")

local function OnCommandListPlugins(client)

	ServerAdminPrint(client, string.format("loader v%s is installed.", DAK.revisions["loader"]))	
	for i = 1, #DAK.config.loader.PluginsList do
		local Plugin = DAK.config.loader.PluginsList[i]
		if Plugin ~= nil then
			local message = string.format("Plugin %s v%s is loaded.", Plugin, DAK.revisions[Plugin])
			ServerAdminPrint(client, message)	
		end
	end

end

DAK:CreateServerAdminCommand("Console_sv_listplugins", OnCommandListPlugins, "Will list the state of all plugins.")