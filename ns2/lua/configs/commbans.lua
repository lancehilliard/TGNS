//CommBans default config

DAK.revisions["commbans"] = "0.1.302a"

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMinVotesNeeded = 2
	DefaultConfig.kTeamVotePercentage = .5
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "commbans", DefaultConfig = SetupDefaultConfig })