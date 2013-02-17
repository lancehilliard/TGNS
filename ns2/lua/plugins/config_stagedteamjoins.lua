//Staged Team Joins config

kDAKRevisions["stagedteamjoins"] = "0.1"

local function SetupDefaultConfig(Save)
	kDAKConfig.StagedTeamJoins = { }
end

DAKRegisterEventHook("kDAKPluginDefaultConfigs", {PluginName = "stagedteamjoins", DefaultConfig = SetupDefaultConfig })