//baseadmincommands default config

DAK.revisions["baseadmincommands"] = "0.1.302a"
local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMapChangeDelay = 5
	DefaultConfig.kUpdateDelay = 60
	DefaultConfig.DefaultGagTime = 5
	DefaultConfig.ChatLimit = 5
	DefaultConfig.ChatRecoverRate = 1
	DefaultConfig.GaggedClientMessage = "Imma Lamma!"
	DefaultConfig.kBlacklistedCommands = { "Console_sv_kick", "Console_sv_eject", "Console_sv_switchteam", "Console_sv_randomall", "Console_sv_rrall", "Console_sv_reset",
															"Console_sv_changemap", "Console_sv_statusip", "Console_sv_status", "Console_sv_say", "Console_sv_tsay", "Console_sv_psay", 
															"Console_sv_slay", "Console_sv_password", "Console_sv_ban", "Console_sv_unban", "Console_sv_listbans"  }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "baseadmincommands", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local DefaultLangStrings = { }
	DefaultLangStrings["GaggedMessage"] 							= "You have been gagged."
	DefaultLangStrings["UngaggedMessage"] 							= "You have been ungagged."
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)