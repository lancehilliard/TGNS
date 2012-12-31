//replaceGetCanPlayerHearPlayer config

kDAKRevisions["replaceGetCanPlayerHearPlayer"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.replaceGetCanPlayerHearPlayer == nil then
		kDAKConfig.replaceGetCanPlayerHearPlayer = { }
	end
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "replaceGetCanPlayerHearPlayer", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })