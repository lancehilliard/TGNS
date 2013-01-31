//PublicCommands config

kDAKRevisions["publiccommands"] = "0.1"
local function SetupDefaultConfig(Save)
	kDAKConfig.PublicCommands = { }
	kDAKConfig.PublicCommands.Commands = {}
	// ["feature"].command = "command string"
	// ["feature"].throttle = min seconds between execution of command
	kDAKConfig.PublicCommands.Commands["timeleft"] = { }
	kDAKConfig.PublicCommands.Commands["timeleft"].command = "timeleft"
	kDAKConfig.PublicCommands.Commands["timeleft"].throttle = 30
	kDAKConfig.PublicCommands.Commands["nextmap"] = { }
	kDAKConfig.PublicCommands.Commands["nextmap"].command = "nextmap"
	kDAKConfig.PublicCommands.Commands["nextmap"].throttle = 30
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "publiccommands", DefaultConfig = SetupDefaultConfig })