//DAK Loader/Base Config

if Server then
	
	kDAKConfig = nil 							//Global variable storing all configuration items for mods
	kDAKSettings = nil 							//Global variable storing all settings for mods
	kDAKRevisions = { }							//List used to track revisions of plugins
	
	//DAK Hookable Functions
	local kDAKEvents = { }
	kDAKEvents["kDAKOnClientConnect"] = { }						//Functions run on Client Connect
	kDAKEvents["kDAKOnClientDisconnect"] = { }					//Functions run on Client Disconnect
	kDAKEvents["kDAKOnServerUpdate"] = { }						//Functions run on ServerUpdate
	kDAKEvents["kDAKOnServerUpdateEveryFrame"] = { }			//Functions run on Every ServerUpdate
	kDAKEvents["kDAKOnClientDelayedConnect"] = { }				//Functions run on DelayedClientConnect
	kDAKEvents["kDAKOnTeamJoin"] = { }							//Functions run on TeamJoin from Gamerules
	kDAKEvents["kDAKOnGameEnd"] = { }							//Functions run on GameEnd from Gamerules
	kDAKEvents["kDAKOnEntityKilled"] = { }						//Functions run on EntityKilled from Gamerules
	kDAKEvents["kDAKOnUpdatePregame"] = { }						//Functions run on UpdatePregame from Gamerules
	kDAKEvents["kDAKOnCastVoteByPlayer"] = { }					//Functions run on CastVoteByPlayer from Gamerules
	kDAKEvents["kDAKOnSetGameState"] = { }			    		//Functions run on SetGameState from Gamerules
	kDAKEvents["kDAKOnClientChatMessage"] = { }					//Functions run on ChatMessages
	kDAKEvents["kDAKCheckMapChange"] = { }	    				//List of functions run to confirm if map should change
	kDAKEvents["kDAKOverrideMapChange"] = { }	    			//Functions run before MapCycle
	kDAKEvents["kDAKPluginDefaultConfigs"] = { }				//List of functions to setup default configs per plugin
	kDAKEvents["kDAKPluginDefaultLanguageDefinitions"] = { }	//List of functions to setup language strings per plugin
	
	kDAKRevisions["dakloader"] = "0.1.128a"
	
	function DAKRegisterEventHook(functionarray, eventfunction, p)
		//Register Event in Array
		p = tonumber(p)
		if p == nil then p = 5 end
		if functionarray ~= nil and kDAKEvents[functionarray] ~= nil then
			table.insert(kDAKEvents[functionarray], {func = eventfunction, priority = p})
			table.sort(kDAKEvents[functionarray], function(f1, f2) return f1.priority < f2.priority end)
		end
	end
	
	function DAKDeregisterEventHook(functionarray, eventfunction)
		//Remove Event in Array
		if functionarray ~= nil and kDAKEvents[functionarray] ~= nil then
			local funcarray = kDAKEvents[functionarray]
			for i = 1, #funcarray do
				if funcarray[i].func == eventfunction then
					table.remove(funcarray, i)
					break
				end
			end
		end
	end
	
	function DAKExecuteEventHooks(event, ...)
		if event ~= nil and kDAKEvents[event] ~= nil then
			if #kDAKEvents[event] > 0 then
				local funcarray = kDAKEvents[event]
				for i = #funcarray, 1, -1 do
					if type(funcarray[i].func) == "function" then
						if funcarray[i].func(...) then return true end
					end
				end
			end
		end
		return false
	end
	
	function DAKReturnEventArray(event)
		if event ~= nil and kDAKEvents[event] ~= nil then
			if #kDAKEvents[event] > 0 then
				return kDAKEvents[event]
			end
		end
		return nil
	end
	
	//Hooks for logging functions
	function EnhancedLog(message)
	
		if DAKIsPluginEnabled("enhancedlogging") then
			EnhancedLogMessage(message)
		end
	
	end
		
	function PrintToAllAdmins(commandname, client, parm1)
	
		if DAKIsPluginEnabled("enhancedlogging") then
			EnhancedLoggingAllAdmins(commandname, client, parm1)
		end
	
	end

	function DAKCreateGUIVoteBase(id, OnMenuFunction, OnMenuUpdateFunction)
		if DAKIsPluginEnabled("guimenubase") then
			return CreateGUIMenuBase(id, OnMenuFunction, OnMenuUpdateFunction)
		end
		return false
	end
	
	function DAKIsPlayerAFK(player)
		if DAKIsPluginEnabled("afkkick") then
			return GetIsPlayerAFK(player)
		elseif player ~= nil and player:GetAFKTime() > 30 then
			return true
		end
		return false
	end

	function ShufflePlayerList()
	
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		for i = #playerList, 1, -1 do
			if playerList[i]:GetTeamNumber() ~= 0 or DAKIsPlayerAFK(playerList[i]) then
				table.remove(playerList, i)
			end
		end
		for i = 1, (#playerList) do
			r = math.random(1, #playerList)
			local iplayer = playerList[i]
			playerList[i] = playerList[r]
			playerList[r] = iplayer
		end
		return playerList
		
	end
	
	function GetTournamentMode()
		local OverrideTournamentModes = false
		if RBPSconfig then
			//Gonna do some basic NS2Stats detection here
			OverrideTournamentModes = RBPSconfig.tournamentMode
		end
		if kDAKSettings.TournamentMode == nil then
			kDAKSettings.TournamentMode = false
		end
		return kDAKSettings.TournamentMode or OverrideTournamentModes
	end
	
	function GetFriendlyFire()
		if kDAKSettings.FriendlyFire == nil then
			kDAKSettings.FriendlyFire = false
		end
		return kDAKSettings.FriendlyFire
	end
	
	Script.Load("lua/dkjson.lua")
	Script.Load("lua/DAKLoader_Class.lua")
	Script.Load("lua/DAKLoader_ServerAdmin.lua")
	Script.Load("lua/DAKLoader_Config.lua")
	Script.Load("lua/DAKLoader_Settings.lua")
	
	if kBaseScreenHeight == nil then
		//Assume Server.lua has not been loaded already
		//This is probably not perfect, but assuming Server.lua was not loaded first generally means this is loaded from workshop, which would allow for the client side mods to work
		//hence loading shared defs.
		Script.Load("lua/Server.lua")
		//Script.Load("lua/DAKLoader_Shared.lua")
		//Shared file just offers net msg definitions required for menus.
	end

	Script.Load("lua/DAKLoader_EventHooks.lua")
	Script.Load("lua/DAKLoader_ServerAdminCommands.lua")
	Script.Load("lua/DAKLoader_Language.lua")
	Script.Load("lua/DAKLoader_PluginLoader.lua")
	
end