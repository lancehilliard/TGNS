//PrintableNames config

kDAKRevisions["PrintableNames"] = 0.1
local function SetupDefaultConfig(Save)
	if kDAKConfig.PrintableNames == nil then
		kDAKConfig.PrintableNames = { }
	end
	kDAKConfig.PrintableNames.kPrintableNamesWarnMessage = "Your name must use only printable characters."
	kDAKConfig.PrintableNames.kPrintableNamesKickMessage = "Player names must use all printable characters."
	
	if Save then
		SaveDAKConfig()
	end
end

table.insert(kDAKPluginDefaultConfigs, {PluginName = "PrintableNames", DefaultConfig = function(Save) SetupDefaultConfig(Save) end })