//PublicCommands config

kDAKRevisions["PublicCommands"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.PublicCommands == nil then
		kDAKConfig.PublicCommands = { }
	end
	kDAKConfig.PublicCommands.Commands = {}
	// ["feature"].command = "command string"
	// ["feature"].throttle = min seconds between execution of command
	kDAKConfig.PublicCommands.Commands["timeleft"] = { }
	kDAKConfig.PublicCommands.Commands["timeleft"].command = "timeleft"
	kDAKConfig.PublicCommands.Commands["timeleft"].throttle = 30
	kDAKConfig.PublicCommands.Commands["nextmap"] = { }
	kDAKConfig.PublicCommands.Commands["nextmap"].command = "nextmap"
	kDAKConfig.PublicCommands.Commands["nextmap"].throttle = 30
	
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "PublicCommands", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })