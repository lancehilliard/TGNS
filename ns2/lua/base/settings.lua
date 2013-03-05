//DAK loader/Base Config

DAK.settings = nil 							//Global variable storing all settings for mods

local SettingsFileName = "config://DAKSettings.json"

local function LoadDAKSettings()
	DAK.settings = DAK:LoadConfigFile(SettingsFileName) or { }
end

LoadDAKSettings()

function DAK:SaveSettings()
	DAK:SaveConfigFile(SettingsFileName, DAK.settings)
end

//Reset Settings file
local function ResetDAKSetting(client, setting)

	if setting ~= nil then
		DAK.settings[setting] = nil
	else
		setting = "All"
		for k, v in pairs(DAK.settings) do
			if (type(v) == "table") then
				DAK.settings[k] = { }
			else
				DAK.settings[k] = nil
			end
		end
	end
	
	DAK:SaveSettings()
	ServerAdminPrint(client, string.format("Setting %s cleared.", setting))
	DAK:PrintToAllAdmins("sv_resetsettings", client, " " .. setting)
end

DAK:CreateServerAdminCommand("Console_sv_resetsettings", ResetDAKSetting, "<optional setting name> Resets specified setting, or all DAK settings.")