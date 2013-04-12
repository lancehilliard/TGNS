//DAK Events

//******************************************************************************************************************
//Event Hooking
//******************************************************************************************************************
//Return Codes
// false - Continue Execution
// true - Skip remaining

local DelayedClientConnect = { }
local serverupdatetime = 0
local kMaxPrintLength = 128
local MenuMessageTag = "#^DAK"

local function DAKOnClientConnected(client)
	if client ~= nil and DAK.enabled then
		DAK:AddClientToGameIDs(client)
		DAK:UpdateConnectionTimeTracker(client)
		DAK:ExecuteEventHooks("OnClientConnect", client)
		if DAK.config and DAK.config.loader and DAK.config.loader.DelayedClientConnect then
			local CEntry = { Client = client, Time = Shared.GetTime() + DAK.config.loader.DelayedClientConnect }
			table.insert(DelayedClientConnect, CEntry)
		end
	end
end

Event.Hook("ClientConnect", DAKOnClientConnected)

local function DAKOnClientDisconnected(client)
	if client ~= nil and DAK:VerifyClient(client) ~= nil and DAK.enabled then
		DAK:RemoveConnectionTimeTracker(client)
		DAK:ExecuteEventHooks("OnClientDisconnect", client)
	end	
end

Event.Hook("ClientDisconnect", DAKOnClientDisconnected)

local function UpdateClientMenu(player, menumessage)
	Server.SendNetworkMessage(player, "ServerAdminPrint", { message = menumessage }, true)	
end

local function UpdateMenuObject(menuitem)
	local success, newMenuBaseUpdateMessage
	if menuitem.MenuUpdateFunction == nil then
		newMenuBaseUpdateMessage = menuitem.MenuBaseUpdateMessage
		success = true
	else
		success, newMenuBaseUpdateMessage = pcall(menuitem.MenuUpdateFunction, menuitem.clientSteamId, menuitem.MenuBaseUpdateMessage, menuitem.activepage)
	end
	if not success then
		Shared.Message(string.format("Error encountered in menu function: %s", ""))
		menuitem = nil
	else
		//Check to see if message is updated, if not then send term message and clear
		if newMenuBaseUpdateMessage == menuitem.MenuBaseUpdateMessage then
			UpdateClientMenu(DAK:GetPlayerMatchingSteamId(menuitem.clientSteamId), string.sub(MenuMessageTag .. "menutime|0", 0, kMaxPrintLength))
			newMenuBaseUpdateMessage.menutime = 0
		else
			//Add in page messages if applicable
			if newMenuBaseUpdateMessage.option[8] ~= "" then
				newMenuBaseUpdateMessage.option[9] = "Next Page."
			end
			if menuitem.activepage > 0 then
				newMenuBaseUpdateMessage.option[10] = "Previous Page."
			else
				newMenuBaseUpdateMessage.option[10] = "Close."
			end
			//For each parm in the MenuMessage
			for item, message in pairs(newMenuBaseUpdateMessage) do
				//Prefix with start tag
				//Check if message has changed, otherwise dont send
				if item == "option" then
					for o, opt in pairs(message) do
						if menuitem.MenuBaseUpdateMessage == nil or menuitem.MenuBaseUpdateMessage.option == nil or opt ~= menuitem.MenuBaseUpdateMessage.option[o] then
							UpdateClientMenu(DAK:GetPlayerMatchingSteamId(menuitem.clientSteamId), string.sub(MenuMessageTag .. "option" .. tostring(o) .. "|" .. tostring(opt), 0, kMaxPrintLength))
						end
					end
				elseif menuitem.MenuBaseUpdateMessage == nil or message ~= menuitem.MenuBaseUpdateMessage[item] then
					UpdateClientMenu(DAK:GetPlayerMatchingSteamId(menuitem.clientSteamId), string.sub(MenuMessageTag .. tostring(item) .. "|" .. tostring(message), 0, kMaxPrintLength))
				end
			end
		end
		menuitem.MenuBaseUpdateMessage = newMenuBaseUpdateMessage
		if newMenuBaseUpdateMessage ~= nil and newMenuBaseUpdateMessage.menutime ~= nil and newMenuBaseUpdateMessage.menutime ~= 0 then
			menuitem.UpdateTime = Shared.GetTime()
		else
			menuitem = nil
		end
	end
	return menuitem
end

local function DAKUpdateServer(deltaTime)

	PROFILE("DAK:UpdateServer")
	
	if DAK.config and DAK.config.loader and DAK.enabled then
		serverupdatetime = serverupdatetime + deltaTime
		DAK:ExecuteEventHooks("OnServerUpdateEveryFrame", deltaTime)
		DAK:ProcessTimedCallBacks()
		if DAK.config.loader.DelayedServerUpdate and serverupdatetime > DAK.config.loader.DelayedServerUpdate then
		
			DAK:ExecuteEventHooks("OnServerUpdate", serverupdatetime)
			
			if #DelayedClientConnect > 0 then
				for i = #DelayedClientConnect, 1, -1 do
					local CEntry = DelayedClientConnect[i]
					if CEntry ~= nil and CEntry.Client ~= nil and DAK:VerifyClient(CEntry.Client) ~= nil then
						if CEntry.Time < Shared.GetTime() then
							DAK:ExecuteEventHooks("OnClientDelayedConnect", CEntry.Client)
							DelayedClientConnect[i] = nil
						end
					else
						DelayedClientConnect[i] = nil
					end
				end
			end
			
			if #DAK.runningmenus > 0 then
				for i = #DAK.runningmenus, 1, -1 do
					if DAK.runningmenus[i] ~= nil and DAK.runningmenus[i].UpdateTime ~= nil then
						if (Shared.GetTime() - DAK.runningmenus[i].UpdateTime) >= 1.8 then
							DAK.runningmenus[i] = UpdateMenuObject(DAK.runningmenus[i])
						end
					else
						DAK.runningmenus[i] = nil
					end
				end
			end
			
			//Print(string.format("%.5f Accuracy", (100 - math.abs(100 - ((serverupdatetime/1) * 100)))))
			serverupdatetime = serverupdatetime - DAK.config.loader.DelayedServerUpdate
			
		end
		
	end
	
end

Event.Hook("UpdateServer", DAKUpdateServer)

local function DAKRunPluginInitialized(deltaTime)
	DAK:ExecuteEventHooks("OnPluginInitialized", deltaTime)
	DAK:ClearEventHooks("OnPluginInitialized")
	DAK:DeregisterEventHook("OnServerUpdateEveryFrame", DAKRunPluginInitialized)
end

DAK:RegisterEventHook("OnServerUpdateEveryFrame", DAKRunPluginInitialized, 10, "eventhooks")

local originalServerHookNetworkMessage
	
originalServerHookNetworkMessage = DAK:Class_ReplaceMethod("Server", "HookNetworkMessage", 
	function(message, func)
		local loc = DAK:ReplaceNetworkMessageFunction(message, func)
		originalServerHookNetworkMessage(message, function(...) return DAK:ExecuteNetworkMessageFunction(loc, ...) end)
	end
)

local originalScriptLoad

originalScriptLoad = DAK:Class_ReplaceMethod("Script", "Load", 
	function(file)
		if DAK.scriptoverrides[file] == nil then 
			originalScriptLoad(file)
		elseif DAK.scriptoverrides[file] ~= nil and DAK.scriptoverrides[file] ~= true and tostring(DAK.scriptoverrides[file]) ~= nil then
			originalScriptLoad(DAK.scriptoverrides[file])
		end
	end
)

local function DelayedEventHooks()

	if DAK.config.loader.GamerulesClassName == nil then DAK.config.loader.GamerulesClassName = "NS2Gamerules" end
		
	local originalNS2GRJoinTeam
	
	originalNS2GRJoinTeam = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "JoinTeam", 
		function(self, player, newTeamNumber, force)
		
			if not DAK:ExecuteEventHooks("OnTeamJoin", self, player, newTeamNumber, force) then
				return originalNS2GRJoinTeam(self, player, newTeamNumber, force)
			end
			return false, player
			
		end
	)
	
	local originalNS2GREndGame
	
	originalNS2GREndGame = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "EndGame", 
		function(self, winningTeam)
		
			DAK:ExecuteEventHooks("OnGameEnd", self, winningTeam)
			originalNS2GREndGame(self, winningTeam)
			
		end
	)
	
	local originalNS2GREntityKilled
	
	originalNS2GREntityKilled = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "OnEntityKilled", 
		function(self, targetEntity, attacker, doer, point, direction)
		
			if attacker and targetEntity and doer then
				DAK:ExecuteEventHooks("OnEntityKilled", self, targetEntity, attacker, doer, point, direction)
			end
			originalNS2GREntityKilled(self, targetEntity, attacker, doer, point, direction)
		
		end
	)
	
	local originalNS2GRUpdatePregame
	
	originalNS2GRUpdatePregame = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "UpdatePregame", 
		function(self, timePassed)

			if not DAK:ExecuteEventHooks("OnUpdatePregame", self, timePassed) then
				originalNS2GRUpdatePregame(self, timePassed)
			end
		
		end
	)
	
	local originalNS2GRCheckGameStart
	
	originalNS2GRCheckGameStart = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "CheckGameStart", 
		function(self)

			if not DAK:ExecuteEventHooks("CheckGameStart", self) then
				originalNS2GRCheckGameStart(self)
			end
		
		end
	)
	
	local originalNS2GRCastVoteByPlayer
		
	originalNS2GRCastVoteByPlayer = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "CastVoteByPlayer", 
		function(self, voteTechId, player)
		
			if not DAK:ExecuteEventHooks("OnCastVoteByPlayer", self, voteTechId, player) then
				originalNS2GRCastVoteByPlayer(self, voteTechId, player)
			end

		end
	)
	
	local originalNS2GRSetGameState
	
	originalNS2GRSetGameState = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "SetGameState", 
		function(self, state)

			local currentstate = self.gameState
			originalNS2GRSetGameState( self, state )
			DAK:ExecuteEventHooks("OnSetGameState", self, state, currentstate)
		
		end
	)
	
	local originalNS2GRGetFriendlyFire
	
	originalNS2GRGetFriendlyFire = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "GetFriendlyFire", 
		function(self)
		
			return DAK:GetFriendlyFire()
			//return originalNS2GRGetFriendlyFire( self )
		
		end
	)
	
	function GetFriendlyFire()
		return DAK:GetFriendlyFire()
	end
	
	local originalNS2GRGetCanPlayerHearPlayer
	
	originalNS2GRGetCanPlayerHearPlayer = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "GetCanPlayerHearPlayer", 
		function(self, listenerPlayer, speakerPlayer)

			local canHear = originalNS2GRGetCanPlayerHearPlayer( self, listenerPlayer, speakerPlayer )
			
			if DAK.settings and DAK.settings.AllTalk then
				canHear = true
			end
			
			local client = Server.GetOwner(speakerPlayer)
			
			if DAK:IsClientGagged(client) then
				canHear = false
			end
			
			return canHear
			
		end
	)
		
	local originalServerAddChatToHistory
	
	originalServerAddChatToHistory = DAK:Class_ReplaceMethod("Server", "AddChatToHistory", 
		function(message, playerName, steamId, teamNumber, teamOnly)

			if originalServerAddChatToHistory ~= nil then
				originalServerAddChatToHistory(message, playerName, steamId, teamNumber, teamOnly)
			end

			local client = DAK:GetClientMatchingSteamId(steamId)
			DAK:ExecuteChatCommands(client, message)
			//Leaving this for now as there are times when greater control is needed/useful.
			DAK:ExecuteEventHooks("OnClientChatMessage", message, playerName, steamId, teamNumber, teamOnly, client)

		end
	)
	
	function GetBannedPlayersList()
		local returnList = { }
		for bid, entry in pairs(DAK.bannedplayers) do
			table.insert(returnList, { name = entry.name, id = bid, reason = entry.reason, time = entry.time })  
		end
		return returnList
	end
		
	if DAK.config and DAK.config.loader and DAK.config.loader.AllowClientMenus then
		Server.RemoveFileHashes("EventTester.lua")
	end

	Script.Load("lua/base/mapcycle.lua")
	
end

if DAK.config and DAK.config.loader and DAK.config.loader.GamerulesExtensions then
	DAK:RegisterEventHook("OnPluginInitialized", DelayedEventHooks, 10, "eventhooks")
end
	
local function SetServerConfigOnClientConnected(client)
	if DAK.config and DAK.config and DAK.config.serverconfig then 
		if DAK.config.serverconfig.Interp ~= 100 then
			Shared.ConsoleCommand(string.format("interp %f", (DAK.config.serverconfig.Interp/1000)))
		end
		if DAK.config.serverconfig.UpdateRate ~= 20 then
			//Shared.ConsoleCommand(string.format("cr %f", DAK.config.serverconfig.UpdateRate))
		end
		if DAK.config.serverconfig.MoveRate ~= 30 then
			Shared.ConsoleCommand(string.format("mr %f", DAK.config.serverconfig.MoveRate))
		end
	end
end

DAK:RegisterEventHook("OnClientConnect", SetServerConfigOnClientConnected, 5, "eventhooks")

local function EnableClientMenus(client)
	if client ~= nil then
		local steamid = client:GetUserId()
		if steamid ~= nil and tonumber(steamid) ~= nil and DAK.config.loader.AllowClientMenus then
			DAK.activemoddedclients[tonumber(steamid)] = true
		end
	end
end

Event.Hook("Console_registerclientmenus", EnableClientMenus)

local function OnCommandMenuBaseSelection(client, selection)

	if selection ~= nil and tonumber(selection) ~= nil and client ~= nil then
		selection = tonumber(selection)
		local steamId = client:GetUserId()
		if steamId ~= nil and tonumber(steamId) ~= nil then
			for i = #DAK.runningmenus, 1, -1 do
				if DAK.runningmenus[i].clientSteamId == steamId then
					local menufunction = DAK.runningmenus[i].MenuFunction
					DAK.runningmenus[i].MenuBaseUpdateMessage.inputallowed = nil
					if selection == 10 and DAK.runningmenus[i].activepage > 0 then
						DAK.runningmenus[i].activepage = DAK.runningmenus[i].activepage - 1
					elseif selection == 10 then
						DAK.runningmenus[i].MenuUpdateFunction = nil
					elseif selection == 9 then
						DAK.runningmenus[i].activepage = DAK.runningmenus[i].activepage + 1
					elseif DAK.runningmenus[i].MenuFunction(client, selection, DAK.runningmenus[i].activepage) then
						if menufunction == DAK.runningmenus[i].MenuFunction then
							DAK.runningmenus[i] = nil
						end
					end
					break
				end
			end
		end
		//Shared.Message(string.format("Recieved selection %s", menuMessage.optionselected))
	end
	
end

Event.Hook("Console_menubaseselection", OnCommandMenuBaseSelection)

local function UpdateClientMenuHook(steamId, LastUpdateMessage, page)
	return DAK:UpdateClientMainMenu(steamId, LastUpdateMessage, page)
end

local function UpdateClientSelectMainMenuHook(client, selecteditem, page)
	return DAK:SelectMainMenuItem(client, selecteditem, page)
end

local function DisplayDAKMenu(client)
	if client ~= nil then
		local steamid = client:GetUserId()
		if steamid ~= nil and tonumber(steamid) ~= nil and DAK.config.loader.AllowClientMenus then
			DAK:CreateGUIMenuBase(steamid, UpdateClientSelectMainMenuHook, UpdateClientMenuHook, true)
		end
	end
end

Event.Hook("Console_dakmodmenu", DisplayDAKMenu)