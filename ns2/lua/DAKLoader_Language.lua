//DAK Loader/Base Config

if Server then

	kDAKLanguageStrings = { }
	local LanguageStrings = { }
	local ClientLanguages = { }
	
	if kDAKSettings.DAKClientLanguages == nil then
		kDAKSettings.DAKClientLanguages = { }
	end
	
	local function tablemerge(tab1, tab2)
		for k, v in pairs(tab2) do
			if (type(v) == "table") and (type(tab1[k] or false) == "table") then
				tablemerge(tab1[k], tab2[k])
			else
				tab1[k] = v
			end
		end
		return tab1
	end
	
	local function LoadLanguageDefinitions()
		for i = 1, #kDAKConfig.DAKLoader.kLanguageList do
			local filename = string.format("lua/lang/%s.json", kDAKConfig.DAKLoader.kLanguageList[i])
			local DAKLangFile = io.open(filename, "r")
			if DAKLangFile then
				kDAKLanguageStrings = tablemerge(kDAKLanguageStrings, json.decode(DAKLangFile:read("*all")))
				DAKLangFile:close()
			else
				//Look in config/lang folder for lang def.
				local filename = string.format("config://lang\\%s.json", kDAKConfig.DAKLoader.kLanguageList[i])
				local DAKLangFile = io.open(filename, "r")
				if DAKLangFile then
					kDAKLanguageStrings = tablemerge(kDAKLanguageStrings, json.decode(DAKLangFile:read("*all")))
					DAKLangFile:close()
				end
			end
		end
		LanguageStrings = kDAKLanguageStrings
		//Load, then move to local var.  Not sure if this offers any benefits, but meh might as well
	end
	
	LoadLanguageDefinitions()
	
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
		if LanguageStrings[kDAKConfig.DAKLoader.kDefaultLanguage] ~= nil then	
			local ltable = LanguageStrings[kDAKConfig.DAKLoader.kDefaultLanguage]
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
			local playerRecords =  GetEntitiesForTeam("Player", teamnum)
			for _, player in ientitylist(playerRecords) do
				
				local client = Server.GetOwner(player)
				if client ~= nil then
					DAKDisplayMessageToClient(client, messageId, ...)
				end
			
			end
		end
	end
	
	local function OnCommandSetLanguage(client, language)
	
		if language == nil then 
			language = kDAKConfig.DAKLoader.kDefaultLanguage
		else
			language = string.upper(language)
		end
				
		if client ~= nil then
			local clientID = client:GetUserId()
			local updated = false
			
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
			
			DAKDisplayMessageToClient(client, "SetLanguage", language)
			SaveDAKSettings()
		end
		
	end

	Event.Hook("Console_setlanguage",                 OnCommandSetLanguage)
	
	local function OnLanguageChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
	
		if client and steamId and steamId ~= 0 then
			for c = 1, #kDAKConfig.DAKLoader.kLanguageChatCommands do
				local chatcommand = kDAKConfig.DAKLoader.kLanguageChatCommands[c]
				if string.sub(message,1,string.len(chatcommand)) == chatcommand then
					OnCommandSetLanguage(client, string.sub(message,-2))
					return true
				end
			end
		end
	
	end
	
	DAKRegisterEventHook(kDAKOnClientChatMessage, OnLanguageChatMessage, 5)
	
end