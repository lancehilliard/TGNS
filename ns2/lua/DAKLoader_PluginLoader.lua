//DAKLoader Plugin Loader
local PluginLoadAttemps = 0
local PluginMaxLoadAttemps = 3

//Load Plugins
local function LoadPlugins()
	
	if kDAKConfig ~= nil and kDAKConfig.DAKLoader ~= nil and PluginLoadAttemps < PluginMaxLoadAttemps then
		local DR = kDAKRevisions["dakloader"]
		if PluginLoadAttemps == 0 then
			//First Clear any plugin settings
			for i = 1, #kDAKConfig.DAKLoader.kPluginsList do
				kDAKSettings[kDAKConfig.DAKLoader.kPluginsList[i]] = nil
			end
		end
		PluginLoadAttemps = PluginLoadAttemps + 1
		//This allows for load tracking, keep running until all plugins are loaded, not reloading already loaded ones.
		for i = 1, #kDAKConfig.DAKLoader.kPluginsList do
			if kDAKSettings[kDAKConfig.DAKLoader.kPluginsList[i]] == nil then
				kDAKSettings[kDAKConfig.DAKLoader.kPluginsList[i]] = kDAKRevisions[kDAKConfig.DAKLoader.kPluginsList[i]]
				local filename = string.format("lua/plugins/plugin_%s.lua", kDAKConfig.DAKLoader.kPluginsList[i])
				Script.Load(filename)
				kDAKSettings[kDAKConfig.DAKLoader.kPluginsList[i]] = true
				if DR == kDAKRevisions[kDAKConfig.DAKLoader.kPluginsList[i]] then
					//Shared.Message(string.format("Plugin %s loaded.",kDAKConfig.DAKLoader.kPluginsList[i]))
				else
					Shared.Message(string.format("Plugin %s loaded, v%s DAKLoader - v%s Plugin version mismatch.", kDAKConfig.DAKLoader.kPluginsList[i], DR, kDAKRevisions[kDAKConfig.DAKLoader.kPluginsList[i]]))
				end
			elseif kDAKSettings[kDAKConfig.DAKLoader.kPluginsList[i]] == kDAKRevisions[kDAKConfig.DAKLoader.kPluginsList[i]] then
				Shared.Message(string.format("Plugin %s did not load successfully, skipping..",kDAKConfig.DAKLoader.kPluginsList[i]))
			end
		end
	else
		Shared.Message("Something may be wrong with your config file.")
	end
	//Once execution completes, Deregister after settings save.
	DAKDeregisterEventHook("kDAKOnServerUpdate", LoadPlugins)
	
end

DAKRegisterEventHook("kDAKOnServerUpdate", LoadPlugins, 10) // This needs to run first

local function ResetandLoadPlugins()
	PluginLoadAttemps = 0
	LoadPlugins()
end

DAKCreateServerAdminCommand("Console_sv_reloadplugins", ResetandLoadPlugins, "Reloads all plugins.")

local function OnCommandListPlugins(client)

	if client then
		ServerAdminPrint(client, string.format("Loader v%s is installed.", kDAKRevisions["dakloader"]))	
	else
		Shared.Message(string.format("Loader v%s is installed.", kDAKRevisions["dakloader"]))
	end
	for i = 1, #kDAKConfig.DAKLoader.kPluginsList do
		if kDAKSettings[kDAKConfig.DAKLoader.kPluginsList[i]] then
			local message
			if kDAKSettings[kDAKConfig.DAKLoader.kPluginsList[i]] == kDAKRevisions[kDAKConfig.DAKLoader.kPluginsList[i]] then
				message = string.format("Plugin %s v%s was not loaded due to error.", kDAKConfig.DAKLoader.kPluginsList[i], kDAKRevisions[kDAKConfig.DAKLoader.kPluginsList[i]])
			else
				message = string.format("Plugin %s v%s is loaded.", kDAKConfig.DAKLoader.kPluginsList[i], kDAKRevisions[kDAKConfig.DAKLoader.kPluginsList[i]])
			end
			if client then
				ServerAdminPrint(client, message)	
			else
				Shared.Message(message)
			end
		end
	end

end

DAKCreateServerAdminCommand("Console_sv_listplugins", OnCommandListPlugins, "Will list the state of all plugins.")