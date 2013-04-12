//CommBans default config

local function SetupDefaultConfig()
	local DefaultConfig = { }
	DefaultConfig.kMinVotesNeeded = 2
	DefaultConfig.kTeamVotePercentage = .5
	return DefaultConfig
end

DAK:RegisterEventHook("PluginDefaultConfigs", {PluginName = "commbans", DefaultConfig = SetupDefaultConfig })