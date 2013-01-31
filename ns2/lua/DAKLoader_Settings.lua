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
	local function ResetDAKSetting(client, setting)

		if setting ~= nil then
			kDAKSettings[setting] = nil
		else
			setting = "All"
			for k, v in pairs(kDAKSettings) do
				if (type(v) == "table") then
					kDAKSettings[k] = { }
				else
					kDAKSettings[k] = nil
				end
			end
		end
		
		SaveDAKSettings()

		if client ~= nil then 
			ServerAdminPrint(client, string.format("Setting %s cleared.", setting))
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_resetsettings", client, " " .. setting)
			end
		end
	end
	
	DAKCreateServerAdminCommand("Console_sv_resetsettings", ResetDAKSetting, "<optional setting name> Resets specified setting, or all DAK settings.")
	
end