//DAK loader/Base Config

local LanguageStrings = { }
local defaultlang = "Default"

if DAK.settings.clientlanguages == nil then
	DAK.settings.clientlanguages = { }
end

local function pairsKeySorted(t, f)
	local a = {}
	for n in pairs(t) do
		table.insert(a, n)
	end
	table.sort(a, f)
	
	local i = 0	-- iterator variable
	local iter = function()-- iterator function
		i = i + 1
		if a[i] == nil then
			return nil
		else
			return a[i], t[a[i]]
		end
	end
	
	return iter
end

local function tablemerge(tab1, tab2)
	if tab1 ~= nil and tab2 ~= nil then
		for k, v in pairs(tab2) do
			if (type(v) == "table") and (type(tab1[k] or false) == "table") then
				tablemerge(tab1[k], tab2[k])
			else
				tab1[k] = v
			end
		end
	end
	return tab1
end

local function LoadLanguageDefinitions()
	for i = 1, #DAK.config.language.LanguageList do
		if DAK.config.language.LanguageList[i] ~= defaultlang then
			local lang = DAK.config.language.LanguageList[i]
			if lang ~= nil then
				LanguageStrings[lang] = DAK:LoadConfigFile(string.format("config://lang\\%s.json", lang)) or { }
			end
		end
	end
end

local function SaveDefaultLanguageDefinition()
	//Write config to file
	local DAKDefaultLangFile = io.open(string.format("config://lang\\%s.json", defaultlang), "w+")
	if DAKDefaultLangFile then
		DAKDefaultLangFile:write("{\n")
		DAKDefaultLangFile:write("\"_COMMENTS\":" .. [[		"This file should not be edited, it is re-created every map change.  To edit default messages, You will want to make a copy of this file, and rename
	it to EN.json.  By Default, EN is the default language for all players, and will be used as the primary source.  This file is only used if the EN.json file doesnt have the needed strings
	or doesnt exist.  You can also configure additional languages by creating multiple versions of this file, and adding them in the config.  Clients can set their language ingame with \lang. 
	You can delete this line in your custom files]] .. ".\",\n")
		for k, v in pairsKeySorted(LanguageStrings[defaultlang]) do
			if (type(v) == "table") then
				DAKDefaultLangFile:write(string.format("\"%s\":\t\t\t\t\t\t\t\[\n", k))
				for i, m in ipairs(v) do
					DAKDefaultLangFile:write(string.format("\"%s\",\n", m))
				end
				DAKDefaultLangFile:write(string.format("],\n"))
			else
				DAKDefaultLangFile:write(string.format("\"%s\":\t\t\t\t\t\t\t\"%s\",\n", k, v))
			end
		end
		DAKDefaultLangFile:write("}\n")
		DAKDefaultLangFile:close()
	end
end

local function GenerateDefaultLangDefinition()

	if LanguageStrings == nil then
		LanguageStrings = { }
	end
	if LanguageStrings[defaultlang] == nil then
		LanguageStrings[defaultlang] = { }
	end

	//Base DAK Language Strings
	local DefaultLang = { }
	DefaultLang["SetLanguage"]					= "Language changed to %s."
	DefaultLang["AvailableLanguages"]			= "Available Languages are - [%s]."
	DefaultLang["SetLanguageAdmin"]				= "Language changed for %s to %s."
	DefaultLang["InvalidMap"]					= "Invalid Map Provided."
	tablemerge(LanguageStrings[defaultlang], DefaultLang)
	//Base DAK Language Strings
	
	//Generate default language strings for all loaded plugins
	local funcarray = DAK:ReturnEventArray("PluginDefaultLanguageDefinitions")
	if funcarray ~= nil then
		for i = 1, #funcarray do
			tablemerge(LanguageStrings[defaultlang], funcarray[i].func())
		end
	end
end

local function LoadDAKLanguages()

	LoadLanguageDefinitions() //This loads all defs, no need to reload as Default should never be customized.
	//Load current languages - if its invalid or non-existant, create default
	//Config files will already be loaded here, so just generate and update default language definition right away.
	GenerateDefaultLangDefinition()
	SaveDefaultLanguageDefinition()
	
end

LoadDAKLanguages()

local function GetIsLanguageValid(lang)
	if lang ~= nil then
		for i = 1, #DAK.config.language.LanguageList do
			if lang == DAK.config.language.LanguageList[i] then
				return true
			end
		end
	end
	return false
end

local function ClientLanguageOverride(client)
	if client ~= nil then
		local clientID = tonumber(client:GetUserId())
		if clientID ~= nil then
			if DAK.settings.clientlanguages[clientID] == nil or not GetIsLanguageValid(DAK.settings.clientlanguages[clientID]) then
				DAK.settings.clientlanguages[clientID] = DAK.config.language.DefaultLanguage
			end
			return DAK.settings.clientlanguages[clientID]
		end
	end
	return DAK.config.language.DefaultLanguage
end

function DAK:GetLanguageSpecificMessage(messageId, lang)
	if lang == nil or not GetIsLanguageValid(lang) then lang = DAK.config.language.DefaultLanguage end
	if LanguageStrings[lang] ~= nil then
		local ltable = LanguageStrings[lang]
		if ltable[messageId] ~= nil then
			return ltable[messageId]
		end
	end
	if LanguageStrings[defaultlang] ~= nil then	
		local ltable = LanguageStrings[defaultlang]
		if ltable[messageId] ~= nil then
			return ltable[messageId]
		end
	end
	Shared.Message(string.format("Invalid MessageId provided - %s", messageId))
	return ""
end

function DAK:GetClientLanguageSetting(client)
	return ClientLanguageOverride(client)
end
   
function DAK:DisplayMessageToClient(client, messageId, ...)

	if client ~= nil then
		local language = ClientLanguageOverride(client)
		local player = client:GetControllingPlayer()
		local message = DAK:GetLanguageSpecificMessage(messageId, language)
		local chatMessage = string.sub(string.format(message, ...), 1, kMaxChatLength)
		Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
	end

end

function DAK:DisplayMessageToAllClients(messageId, ...)

	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	//local message = DAK:GetLanguageSpecificMessage(messageId, "GB")
	//Shared.Message(string.format(message, ...))
	for _, player in ientitylist(playerRecords) do
		
		local client = Server.GetOwner(player)
		if client ~= nil then
			DAK:DisplayMessageToClient(client, messageId, ...)
		end
	
	end
end

function DAK:DisplayMessageToTeam(teamnum, messageId, ...)
	
	if tonumber(teamnum) ~= nil then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			
			local client = Server.GetOwner(player)
			if client ~= nil then
				DAK:DisplayMessageToClient(client, messageId, ...)
			end
		
		end
	end
end

function DAK:DisplayLegacyChatMessageToClientWithoutMenus(client, messageId, ...)
	if client ~= nil and not client:GetIsVirtual() and not DAK:DoesClientHaveClientSideMenus(client) then
		DAK:DisplayMessageToClient(client, messageId, ...)
	end
end

function DAK:DisplayLegacyChatMessageToAllClientWithoutMenus(messageId, ...)
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		local client = Server.GetOwner(player)
		if client ~= nil and not client:GetIsVirtual() and not DAK:DoesClientHaveClientSideMenus(client) then
			DAK:DisplayMessageToClient(client, messageId, ...)
		end
	end
end

function DAK:DisplayLegacyChatMessageToTeamClientsWithoutMenus(teamnum, messageId, ...)
	if tonumber(teamnum) ~= nil then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			local client = Server.GetOwner(player)
			if client ~= nil and not client:GetIsVirtual() and not DAK:DoesClientHaveClientSideMenus(client) then
				DAK:DisplayMessageToClient(client, messageId, ...)
			end
		end
	end
end

local function UpdateClientLanguageSetting(clientID, language)
	if clientID ~= nil then
		DAK.settings.clientlanguages[tonumber(clientID)] = language
	end
	DAK:SaveSettings()
end

local function OnCommandSetLanguage(client, language)
	language = string.upper(language)
	if language == nil or not GetIsLanguageValid(language) and client ~= nil then
		local langs = table.concat(DAK.config.language.LanguageList, ",")
		DAK:DisplayMessageToClient(client, "AvailableLanguages", langs)			
	elseif client ~= nil then
		local clientID = client:GetUserId()
		UpdateClientLanguageSetting(clientID, language)
		DAK:DisplayMessageToClient(client, "SetLanguage", language)		
	end
	
end

Event.Hook("Console_setlanguage",                 OnCommandSetLanguage)

DAK:RegisterChatCommand(DAK.config.language.LanguageChatCommands, OnCommandSetLanguage, true)

local function SetClientLanguage(client, playerId, language)

	local player = DAK:GetPlayerMatching(playerId)
	if player ~= nil then
		local client = Server.GetOwner(player)
		if client ~= nil then
			playerId = client:GetUserId()
		end
	end
	
	if language == nil then
		language = DAK.config.language.DefaultLanguage
	else
		language = string.upper(language)
	end	
	
	if tonumber(playerId) > 0 then
	
		if not DAK:GetLevelSufficient(client, playerId) then
			return
		end
		UpdateClientLanguageSetting(playerId, language)
		DAK:DisplayMessageToClient(client, "SetLanguageAdmin", playerId, language)	
		
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_setlanguage", SetClientLanguage, "<player id> <language> Changes the language set for the provided player.")