//Chat config

kDAKRevisions["Chat"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.Chat == nil then
		kDAKConfig.Chat = { }
	end
	kDAKConfig.Chat.Channels = {}
	kDAKConfig.Chat.Channels["sv_chat"] = { label = "PMADMIN", triggerChar = "@", help = "<Message>  Sends a message to every admin on the server.", canPM = true }
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "Chat", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })