//loader Plugin loader

//Load Plugins
local function LoadPlugins()
	
	if DAK.config ~= nil and DAK.config.loader ~= nil then
		for i = 1, #DAK.config.loader.PluginsList do
			local Plugin = DAK.config.loader.PluginsList[i]
			if Plugin ~= nil and Plugin ~= "" then
				local filename = string.format("lua/plugins/%s.lua", Plugin)
				Script.Load(filename)
				//Shared.Message(string.format("Plugin %s loaded.", Plugin))
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

	ServerAdminPrint(client, string.format("Loader v%s is installed.", DAK.version))
	ServerAdminPrint(client, string.format("Loader is %s.", ConditionalValue(DAK.enabled, "enabled", "disabled")))
	for i = 1, #DAK.config.loader.PluginsList do
		local Plugin = DAK.config.loader.PluginsList[i]
		if Plugin ~= nil then
			local message = string.format("Plugin %s is loaded.", Plugin)
			ServerAdminPrint(client, message)
		end
	end	
	
end

DAK:CreateServerAdminCommand("Console_sv_listplugins", OnCommandListPlugins, "Will list the state of all plugins.")