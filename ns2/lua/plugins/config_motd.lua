//motd config

kDAKRevisions["motd"] = "0.1.128a"

local function SetupDefaultConfig()
	kDAKConfig.MOTD = { }
	kDAKConfig.MOTD.kMOTDMessageDelay = 6
	kDAKConfig.MOTD.kMOTDMessageRevision = 1
	kDAKConfig.MOTD.kMOTDMessagesPerTick = 5
	kDAKConfig.MOTD.kAcceptMOTDChatCommands = { "acceptmotd" }
	kDAKConfig.MOTD.kPrintMOTDChatCommands = { "printmotd" }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "motd", DefaultConfig = SetupDefaultConfig })

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
	DefaultLangStrings["kPeriodicMessages"]	= kMessages
	local DefaultLangStrings = { }
	DefaultLangStrings["kMOTDAccepted"] 							= "You accepted the MOTD."
	DefaultLangStrings["kMOTDAlreadyAccepted"]	 					= "You already accepted the MOTD."
	DefaultLangStrings["kMOTDMessage"] 								= kMessages
	return DefaultLangStrings
end

DAKRegisterEventHook("kDAKPluginDefaultLanguageDefinitions", SetupDefaultLanguageStrings)