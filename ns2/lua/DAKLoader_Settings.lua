//DAK Loader/Base Config

if Server then

	local DAKSettingsFileName = "config://DAKSettings.json"
	
	local function LoadDAKSettings()
		local DAKSettingsFile
		DAKSettingsFile = io.open(DAKSettingsFileName, "r")
		if DAKSettingsFile then
			Shared.Message("Loading DAK settings.")
			kDAKSettings = json.decode(DAKSettingsFile:read("*all"))
			DAKSettingsFile:close()
		end
		if kDAKSettings == nil then
			kDAKSettings = { }
		end
	end
	
	LoadDAKSettings()
	
	function SaveDAKSettings()
	
		local DAKSettingsFile = io.open(DAKSettingsFileName, "w+")
		if DAKSettingsFile then
			DAKSettingsFile:write(json.encode(kDAKSettings, { indent = true, level = 1 }))
			DAKSettingsFile:close()
		end
	
	end
	
	//Reset Settings file
	local function ResetSettings(setting)
		local Settings = setting or kDAKSettings
		for i = 1, #Settings do
			local setting = kDAKSettings[i]
			if type(setting) == "table" then
				ResetSettings(setting)
			else
				setting = nil
			end
		end
		SaveDAKSettings()
	end
	
	DAKCreateServerAdminCommand("Console_sv_resetsettings", ResetSettings, "<optional setting name> Resets specified setting, or all DAK settings.")
	
end