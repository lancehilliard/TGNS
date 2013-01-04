//PublicCommands config

kDAKRevisions["PublicCommands"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.PublicCommands == nil then
		kDAKConfig.PublicCommands = { }
	end
	kDAKConfig.PublicCommands.Commands = {}
	// [feature] = command string
	kDAKConfig.PublicCommands.Commands["timeleft"] = "timeleft"
	kDAKConfig.PublicCommands.Commands["nextmap"] = "nextmap"
	
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "PublicCommands", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })