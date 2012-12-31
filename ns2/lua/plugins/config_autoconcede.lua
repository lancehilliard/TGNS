//autoconcede default config

kDAKRevisions["AutoConcede"] = 1.2
local function SetupDefaultConfig(Save)
	if kDAKConfig.AutoConcede == nil then
		kDAKConfig.AutoConcede = { }
	end
	kDAKConfig.AutoConcede.kImbalanceDuration = 30
	kDAKConfig.AutoConcede.kImbalanceAmount = 4
	kDAKConfig.AutoConcede.kMinimumPlayers = 6
	kDAKConfig.AutoConcede.kWarningMessage = "Round will end in %s seconds due to imbalanced teams."
	kDAKConfig.AutoConcede.kConcedeMessage = "Round ended due to imbalanced teams."
	kDAKConfig.AutoConcede.kConcedeCancelledMessage = "Teams within autoconcede limits."
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "AutoConcede", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })