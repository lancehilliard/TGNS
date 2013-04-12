//motd config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMOTDMessageDelay = 6
	DefaultConfig.kMOTDMessageRevision = 1
	DefaultConfig.kMOTDMessagesPerTick = 5
	DefaultConfig.kMOTDOnConnectURL = "www.unknownworlds.com/ns2"
	DefaultConfig.kAcceptMOTDChatCommands = { "acceptmotd" }
	DefaultConfig.kPrintMOTDChatCommands = { "printmotd" }
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "motd", DefaultConfig = SetupDefaultConfig })

local function SetupDefaultLanguageStrings()
	local kMessages = { }
	table.insert(kMessages, "********************************************************************")
	table.insert(kMessages, "* Commands: These can be entered via chat or the console (~)        ")
	table.insert(kMessages, "* rtv: To initiate a map vote aka Rock The Vote                     ")
	table.insert(kMessages, "* random: To vote for auto-random teams for next 30 minutes         ")
	table.insert(kMessages, "* timeleft: To display the time until next map vote                 ")
	table.insert(kMessages, "* surrender: To initiate or vote in a surrender vote for your team. ")
	table.insert(kMessages, "* acceptmotd: To accept and suppress this message                   ")
	table.insert(kMessages, "* stuck: To have your player teleported to be unstuck.              ")
	table.insert(kMessages, "********************************************************************")
	local DefaultLangStrings = { }
	DefaultLangStrings["MOTDAccepted"] 							= "You accepted the MOTD."
	DefaultLangStrings["MOTDAlreadyAccepted"]	 					= "You already accepted the MOTD."
	DefaultLangStrings["MOTDMessage"] 								= kMessages
	return DefaultLangStrings
end

DAK:RegisterEventHook("PluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)