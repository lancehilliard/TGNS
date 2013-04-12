//DAK loader/Base Config

DAK.settings = nil 							//Global variable storing all settings for mods

local SettingsFileName = "config://DAKSettings.json"

local function LoadDAKSettings()
	DAK.settings = DAK:LoadConfigFile(SettingsFileName) or { }
	local tmpsettings = { }
	//Convert some old crapp
	if DAK.settings.connectedclients ~= nil then
		tmpsettings.connectedclients = { }
		for id, t in pairs(DAK.settings.connectedclients) do
			if tmpsettings.connectedclients[tonumber(id)] == nil then
				tmpsettings.connectedclients[tonumber(id)] = t
			end
		end
	end
	if DAK.settings.clientlanguages ~= nil then
		tmpsettings.clientlanguages = { }
		for id, t in pairs(DAK.settings.clientlanguages) do
			if tmpsettings.clientlanguages[tonumber(id)] == nil then
				tmpsettings.clientlanguages[tonumber(id)] = t
			end
		end
	end
	DAK.settings.connectedclients = tmpsettings.connectedclients
	DAK.settings.clientlanguages = tmpsettings.clientlanguages
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