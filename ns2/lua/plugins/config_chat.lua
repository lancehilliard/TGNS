//Chat config

kDAKRevisions["chat"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.Chat = { }
	kDAKConfig.Chat.Channels = {}
	kDAKConfig.Chat.Channels["sv_chat"] = { label = "PMADMIN", triggerChar = "@", help = "<Message>  Sends a message to every admin on the server.", canPM = true }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "chat", DefaultConfig = SetupDefaultConfig })