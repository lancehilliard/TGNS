//DAK Loader/Base Config

if Server then

	local DAKConfigFileName = "config://DAKConfig.json"
	
	local function tablemerge(tab1, tab2)
		if tab1 ~= nil and tab2 ~= nil then
			for k, v in pairs(tab2) do
				if (type(v) == "table") and (type(tab1[k] or false) == "table") and table.getn(v) == 0 then
					tablemerge(tab1[k], tab2[k])
				else
					tab1[k] = v
				end
			end
		end
		return tab1
	end
	
	local function LoadDAKConfig()
		local DAKConfigFile = io.open(DAKConfigFileName, "r")
		if DAKConfigFile then
			Shared.Message("Loading DAK configuration.")
			if kDAKConfig ~= nil then
				local config = json.decode(DAKConfigFile:read("*all"))
				kDAKConfig = tablemerge(kDAKConfig, config)
			else
				kDAKConfig = json.decode(DAKConfigFile:read("*all"))
			end
			DAKConfigFile:close()
		end
	end
	
	local function SaveDAKConfig()
		//Write config to file
		local DAKConfigFile = io.open(DAKConfigFileName, "w+")
		if DAKConfigFile then
			DAKConfigFile:write(json.encode(kDAKConfig, { indent = true, level = 1 }))
			Shared.Message("Saving DAK configuration.")
			DAKConfigFile:close()
		end
	end
	
	local function GenerateDefaultDAKConfig(Plugin, Save)
	
		if kDAKConfig == nil then
			kDAKConfig = { }
		end
		
		if Plugin == "DAKLoader" or Plugin == "ALL" then
			//Base DAK Config
			kDAKConfig.DAKLoader = { }
			kDAKConfig.DAKLoader.kDelayedClientConnect = 2
			kDAKConfig.DAKLoader.kDelayedServerUpdate = 1
			kDAKConfig.DAKLoader.kPluginsList = { "afkkick", "baseadmincommands", "mapvote", "motd",
													 "unstuck", "voterandom", "votesurrender" }
			kDAKConfig.DAKLoader.GamerulesExtensions = true
			kDAKConfig.DAKLoader.GamerulesClassName = "NS2Gamerules"
			kDAKConfig.DAKLoader.MessageSender = "Admin"
			kDAKConfig.DAKLoader.kLanguageList = { "EN", "Default" }
			kDAKConfig.DAKLoader.kLanguageChatCommands = { "/lang" }
			kDAKConfig.DAKLoader.kDefaultLanguage = "EN"
			kDAKConfig.DAKLoader.OverrideInterp = { }
			kDAKConfig.DAKLoader.OverrideInterp.kEnabled = false
			kDAKConfig.DAKLoader.OverrideInterp.kInterp = 100
			kDAKConfig.DAKLoader.ServerAdmin = { }
			kDAKConfig.DAKLoader.ServerAdmin.kMapChangeDelay = 5
			kDAKConfig.DAKLoader.ServerAdmin.kUpdateDelay = 60
			kDAKConfig.DAKLoader.ServerAdmin.kQueryTimeout = 10
			kDAKConfig.DAKLoader.ServerAdmin.kQueryURL = ""
			//Base DAK Config
		end
		
		//Generate default configs for all plugins
		local funcarray = DAKReturnEventArray("kDAKPluginDefaultConfigs")
		if funcarray ~= nil then
			for i = 1, #funcarray do
				PluginDefaultConfig = funcarray[i].func
				if Plugin == PluginDefaultConfig.PluginName or Plugin == "ALL" then
					PluginDefaultConfig.DefaultConfig()
				end
			end
		end
		
		if Save then
			SaveDAKConfig()
		end
		
	end
	
	local function LoadDAKPluginConfigs()
	
		LoadDAKConfig()
		//Load current config - if its invalid or non-existant, create default so that default plugins are loaded
		if kDAKConfig == nil or kDAKConfig == { } then
			GenerateDefaultDAKConfig("DAKLoader", false)
		end
		//Load config_ files for plugins specified - if a plugin isnt loaded than its config will not be generated.
		if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.kPluginsList then
			for i = 1, #kDAKConfig.DAKLoader.kPluginsList do
				local plugin = kDAKConfig.DAKLoader.kPluginsList[i]
				local filename = string.format("lua/plugins/config_%s.lua", plugin)
				Script.Load(filename)
			end
		end
		
		//Generate Default Config, then reload active config
		//Seems confusing, but should insure any new vars are added to existing configs.
		//This also insures that any new plugins get their config options created.
		GenerateDefaultDAKConfig("ALL", false)
		LoadDAKConfig()
		SaveDAKConfig()
		
	end
	
	LoadDAKPluginConfigs()
	
	function DAKIsPluginEnabled(CheckPlugin)
		for index, plugin in pairs(kDAKConfig.DAKLoader.kPluginsList) do
			if CheckPlugin == plugin then
				return true
			end
		end
		return false
	end
				
	local function OnCommandLoadDAKConfig(client)
	
		if client ~= nil then
			LoadDAKConfig()
			Shared.Message(string.format("%s reloaded DAK config", client:GetUserId()))
			ServerAdminPrint(client, string.format("DAK Config reloaded."))
			PrintToAllAdmins("sv_reloadconfig", client)
		end
		
	end
	
	DAKCreateServerAdminCommand("Console_sv_reloadconfig", OnCommandLoadDAKConfig, "Will reload the configuration files.")
	
	local function OnCommandDefaultPluginConfig(client, plugin)
		if client ~= nil and plugin ~= nil then
			ServerAdminPrint(client, string.format("Defaulting %s config", plugin))
			GenerateDefaultDAKConfig(plugin, true)
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_defaultconfig", client, plugin)
			end
		end
	end

    DAKCreateServerAdminCommand("Console_sv_defaultconfig", OnCommandDefaultPluginConfig, "<Plugin Name> Will default the config for the plugin passed, or ALL.")
	
end