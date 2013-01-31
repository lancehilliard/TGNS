//DAK Loader/Base Config

local LanguageStrings = { }
local ClientLanguages = { }
local defaultlang = "Default"

if kDAKSettings.DAKClientLanguages == nil then
	kDAKSettings.DAKClientLanguages = { }
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
	for i = 1, #kDAKConfig.DAKLoader.kLanguageList do
		if kDAKConfig.DAKLoader.kLanguageList[i] ~= defaultlang then
			local filename = string.format("config://lang\\%s.json", kDAKConfig.DAKLoader.kLanguageList[i])
			local DAKLangFile = io.open(filename, "r")
			if DAKLangFile then
				LanguageStrings[kDAKConfig.DAKLoader.kLanguageList[i]] = json.decode(DAKLangFile:read("*all"))
				DAKLangFile:close()
			end
		end
	end
end

local function SaveDefaultLanguageDefinition()
	//Write config to file
	local DAKDefaultLangFile = io.open(string.format("config://lang\\%s.json", defaultlang), "w+")
	if DAKDefaultLangFile then
		DAKDefaultLangFile:write("{\n")
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
		Shared.Message("Saving DAK Default Language.")
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
	local funcarray = DAKReturnEventArray("kDAKPluginDefaultLanguageDefinitions")
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
		for i = 1, #kDAKConfig.DAKLoader.kLanguageList do
			if lang == kDAKConfig.DAKLoader.kLanguageList[i] then
				return true
			end
		end
	end
	return false
end

local function ClientLanguageOverride(client)
	if client ~= nil then
		local clientID = client:GetUserId()
		if ClientLanguages[clientID] ~= nil then return ClientLanguages[clientID] end
		if client ~= nil and clientID ~= nil then
			for r = #kDAKSettings.DAKClientLanguages, 1, -1 do
				if kDAKSettings.DAKClientLanguages[r] ~= nil and kDAKSettings.DAKClientLanguages[r].id == clientID and GetIsLanguageValid(kDAKSettings.DAKClientLanguages[r].lang) then
					ClientLanguages[clientID] = kDAKSettings.DAKClientLanguages[r].lang
					return kDAKSettings.DAKClientLanguages[r].lang
				end
			end
		end
		ClientLanguages[clientID] = kDAKConfig.DAKLoader.kDefaultLanguage
	end
	return kDAKConfig.DAKLoader.kDefaultLanguage
end

function DAKGetLanguageSpecificMessage(messageId, lang)
	if lang == nil or not GetIsLanguageValid(lang) then lang = kDAKConfig.DAKLoader.kDefaultLanguage end
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
	return ""
end

function DAKGetClientLanguageSetting(client)
	return ClientLanguageOverride(client)
end
   
function DAKDisplayMessageToClient(client, messageId, ...)

	if client ~= nil then
		local language = ClientLanguageOverride(client)
		local player = client:GetControllingPlayer()
		local message = DAKGetLanguageSpecificMessage(messageId, language)
		local chatMessage = string.sub(string.format(message, ...), 1, kMaxChatLength)
		Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
	end

end

function DAKDisplayMessageToAllClients(messageId, ...)

	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	//local message = DAKGetLanguageSpecificMessage(messageId, "GB")
	//Shared.Message(string.format(message, ...))
	for _, player in ientitylist(playerRecords) do
		
		local client = Server.GetOwner(player)
		if client ~= nil then
			DAKDisplayMessageToClient(client, messageId, ...)
		end
	
	end
end

function DAKDisplayMessageToTeam(teamnum, messageId, ...)
	
	if tonumber(teamnum) ~= nil then
		local playerRecords = GetEntitiesForTeam("Player", teamnum)
		for _, player in ipairs(playerRecords) do
			
			local client = Server.GetOwner(player)
			if client ~= nil then
				DAKDisplayMessageToClient(client, messageId, ...)
			end
		
		end
	end
end

local function UpdateClientLanguageSetting(clientID, language)
	local updated = false
	if tonumber(clientID) == nil then return end
	clientID = tonumber(clientID)
	if clientID ~= nil then
		for r = #kDAKSettings.DAKClientLanguages, 1, -1 do
			if kDAKSettings.DAKClientLanguages[r] ~= nil and kDAKSettings.DAKClientLanguages[r].id == clientID then
				ClientLanguages[clientID] = language
				kDAKSettings.DAKClientLanguages[r].lang = language
				updated = true
				break
			end
		end
	end
	
	if not updated then
		local NewClient = { }
		NewClient.id = clientID
		NewClient.lang = language
		ClientLanguages[clientID] = language
		table.insert(kDAKSettings.DAKClientLanguages, NewClient)
	end
	
	SaveDAKSettings()
end

local function OnCommandSetLanguage(client, language)

	if language == nil or not GetIsLanguageValid(language) and client ~= nil then
		local langs = table.concat(kDAKConfig.DAKLoader.kLanguageList, ",")
		DAKDisplayMessageToClient(client, "AvailableLanguages", langs)			
	elseif client ~= nil then
		language = string.upper(language)
		local clientID = client:GetUserId()
		UpdateClientLanguageSetting(clientID, language)
		DAKDisplayMessageToClient(client, "SetLanguage", language)		
	end
	
end

Event.Hook("Console_setlanguage",                 OnCommandSetLanguage)

local function OnLanguageChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)

	if client and steamId and steamId ~= 0 then
		for c = 1, #kDAKConfig.DAKLoader.kLanguageChatCommands do
			local chatcommand = kDAKConfig.DAKLoader.kLanguageChatCommands[c]
			if string.upper(string.sub(message,1,string.len(chatcommand))) == string.upper(chatcommand) then
				OnCommandSetLanguage(client, string.sub(message,-2))
				return true
			end
		end
	end

end

DAKRegisterEventHook("kDAKOnClientChatMessage", OnLanguageChatMessage, 5)

local function SetClientLanguage(client, playerId, language)

	local player = GetPlayerMatching(playerId)
	if player ~= nil then
		local client = Server.GetOwner(player)
		if client ~= nil then
			playerId = client:GetUserId()
		end
	end
	
	if language == nil then 
		language = kDAKConfig.DAKLoader.kDefaultLanguage
	else
		language = string.upper(language)
	end	
	
	if tonumber(playerId) > 0 then
	
		if not DAKGetLevelSufficient(client, playerId) then
			return
		end
		UpdateClientLanguageSetting(playerId, language)
		DAKDisplayMessageToClient(client, "SetLanguageAdmin", playerId, language)	
		
	end
	
end

DAKCreateServerAdminCommand("Console_sv_setlanguage", SetClientLanguage, "<player id> <language> Changes the language set for the provided player.")