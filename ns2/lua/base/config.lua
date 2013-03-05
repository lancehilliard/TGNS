//DAK loader/Base Config

DAK.config = nil //variable storing all configuration items for mods

local ConfigFileName = "config://DAKConfig.json"

local function tablemerge(tab1, tab2)
	if tab1 == nil then
		tab1 = { }
	end
	if tab2 ~= nil then
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
	if DAK.config ~= nil then
		DAK.config = tablemerge(DAK.config, DAK:LoadConfigFile(ConfigFileName) or { })
	else
		DAK.config = DAK:LoadConfigFile(ConfigFileName) or { }
	end
end

local function SaveDAKConfig()
	DAK:SaveConfigFile(ConfigFileName, DAK.config)
end

local function GenerateDefaultDAKConfig(Plugin, Save)

	if DAK.config == nil then
		DAK.config = { }
	end
	
	if Plugin == "loader" or Plugin == "ALL" then
		//Base DAK Config
		local DefaultConfig = { }
		DefaultConfig.DelayedClientConnect = 2
		DefaultConfig.DelayedServerUpdate = 1
		DefaultConfig.PluginsList = { "afkkick", "baseadmincommands", "mapvote", "motd",
												 "unstuck", "voterandom", "votesurrender" }
		DefaultConfig.GamerulesExtensions = true
		DefaultConfig.GamerulesClassName = "NS2Gamerules"
		DefaultConfig.TeamOneName = "Marines"
		DefaultConfig.TeamTwoName = "Aliens"
		
		DAK.config["loader"] = tablemerge(DAK.config["loader"], DefaultConfig)
		
		DefaultConfig = { }
		DefaultConfig.MapChangeDelay = 5
		DefaultConfig.ReconnectTime = 120
		DefaultConfig.ServerTimeZoneAdjustment = 0
		DefaultConfig.UpdateDelay = 60
		DefaultConfig.QueryTimeout = 10
		DefaultConfig.QueryURL = ""
		DefaultConfig.BansQueryURL = ""
		DefaultConfig.BanSubmissionURL = ""
		DefaultConfig.UnBanSubmissionURL = ""
		DefaultConfig.CryptographyKey = ""
		
		DAK.config["serveradmin"] = tablemerge(DAK.config["serveradmin"], DefaultConfig)
		
		DefaultConfig = { }
		DefaultConfig.LanguageList = { "EN", "Default" }
		DefaultConfig.LanguageChatCommands = { "/lang" }
		DefaultConfig.DefaultLanguage = "EN"
		DefaultConfig.MessageSender = "Admin"
				
		DAK.config["language"] = tablemerge(DAK.config["language"], DefaultConfig)
		
		DefaultConfig = { }
		DefaultConfig.Interp = 100
		DefaultConfig.UpdateRate = 20
		DefaultConfig.MoveRate = 30
		
		DAK.config["serverconfig"] = tablemerge(DAK.config["serverconfig"], DefaultConfig)
		
		//Base DAK Config
	end
	
	//Generate default configs for all plugins
	local funcarray = DAK:ReturnEventArray("PluginDefaultConfigs")
	if funcarray ~= nil then
		for i = 1, #funcarray do
			PluginDefaultConfig = funcarray[i].func
			if Plugin == PluginDefaultConfig.PluginName or Plugin == "ALL" then
				if DAK.config[PluginDefaultConfig.PluginName] == nil then
					DAK.config[PluginDefaultConfig.PluginName] = { }
				end
				tablemerge(DAK.config[PluginDefaultConfig.PluginName], PluginDefaultConfig.DefaultConfig())
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
	if DAK.config == nil or DAK.config == { } then
		GenerateDefaultDAKConfig("loader", false)
	end
	
	//Load config files for plugins specified - if a plugin isnt loaded than its config will not be generated.
	if DAK.config and DAK.config.loader and DAK.config.loader.PluginsList then
		for i = 1, #DAK.config.loader.PluginsList do
			local plugin = DAK.config.loader.PluginsList[i]
			if plugin ~= nil and plugin ~= "" then
				local filename = string.format("lua/configs/%s.lua", plugin)
				Script.Load(filename)
			end
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
			
local function OnCommandLoadDAKConfig(client)

	LoadDAKConfig()
	DAK:ExecuteEventHooks("OnConfigReloaded")
	ServerAdminPrint(client, string.format("DAK Config reloaded."))
	DAK:PrintToAllAdmins("sv_reloadconfig", client)
	
end

DAK:CreateServerAdminCommand("Console_sv_reloadconfig", OnCommandLoadDAKConfig, "Will reload the configuration files.")

local function OnCommandDefaultPluginConfig(client, plugin)

	if plugin ~= nil then
		ServerAdminPrint(client, string.format("Defaulting %s config", plugin))
		GenerateDefaultDAKConfig(plugin, true)
		DAK:PrintToAllAdmins("sv_defaultconfig", client, plugin)
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_defaultconfig", OnCommandDefaultPluginConfig, "<Plugin Name> Will default the config for the plugin passed, or ALL.")