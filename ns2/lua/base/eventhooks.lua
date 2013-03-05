//DAK Events

//******************************************************************************************************************
//Event Hooking
//******************************************************************************************************************
//Return Codes
// false - Continue Execution
// true - Skip remaining

local DelayedClientConnect = { }
local serverupdatetime = 0

local function DAKOnClientConnected(client)
	if client ~= nil then
		DAK:AddClientToGameIDs(client)
		DAK:ExecuteEventHooks("OnClientConnect", client)
		DAK:UpdateConnectionTimeTracker(client)
		if DAK.config and DAK.config.loader and DAK.config.loader.DelayedClientConnect then
			local CEntry = { Client = client, Time = Shared.GetTime() + DAK.config.loader.DelayedClientConnect }
			table.insert(DelayedClientConnect, CEntry)
		end
	end
end

Event.Hook("ClientConnect", DAKOnClientConnected)

local function DAKOnClientDisconnected(client)
	if client ~= nil and DAK:VerifyClient(client) ~= nil then
		DAK:RemoveConnectionTimeTracker(client)
		DAK:ExecuteEventHooks("OnClientDisconnect", client)
	end	
end

Event.Hook("ClientDisconnect", DAKOnClientDisconnected)

local function DAKUpdateServer(deltaTime)

	PROFILE("DAK:UpdateServer")
	
	if DAK.config and DAK.config.loader then
		serverupdatetime = serverupdatetime + deltaTime
		DAK:ExecuteEventHooks("OnServerUpdateEveryFrame", deltaTime)
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

DAK:RegisterEventHook("OnServerUpdateEveryFrame", DAKRunPluginInitialized, 10)

local originalServerHookNetworkMessage
	
originalServerHookNetworkMessage = Class_ReplaceMethod("Server", "HookNetworkMessage", 
	function(message, func)
		local loc = DAK:ReplaceNetworkMessageFunction(message, func)
		originalServerHookNetworkMessage(message, function(...) return DAK:ExecuteNetworkMessageFunction(loc, ...) end)
	end
)

local function DelayedEventHooks()

	if DAK.config.loader.GamerulesClassName == nil then DAK.config.loader.GamerulesClassName = "NS2Gamerules" end
		
	local originalNS2GRJoinTeam
	
	originalNS2GRJoinTeam = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "JoinTeam", 
		function(self, player, newTeamNumber, force)
		
			if not DAK:ExecuteEventHooks("OnTeamJoin", self, player, newTeamNumber, force) then
				return originalNS2GRJoinTeam(self, player, newTeamNumber, force)
			end
			return false, player
			
		end
	)
	
	local originalNS2GREndGame
	
	originalNS2GREndGame = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "EndGame", 
		function(self, winningTeam)
		
			DAK:ExecuteEventHooks("OnGameEnd", self, winningTeam)
			originalNS2GREndGame(self, winningTeam)
			
		end
	)
	
	local originalNS2GREntityKilled
	
	originalNS2GREntityKilled = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "OnEntityKilled", 
		function(self, targetEntity, attacker, doer, point, direction)
		
			if attacker and targetEntity and doer then
				DAK:ExecuteEventHooks("OnEntityKilled", self, targetEntity, attacker, doer, point, direction)
			end
			originalNS2GREntityKilled(self, targetEntity, attacker, doer, point, direction)
		
		end
	)
	
	local originalNS2GRUpdatePregame
	
	originalNS2GRUpdatePregame = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "UpdatePregame", 
		function(self, timePassed)

			if not DAK:ExecuteEventHooks("OnUpdatePregame", self, timePassed) then
				originalNS2GRUpdatePregame(self, timePassed)
			end
		
		end
	)
	
	local originalNS2GRCheckGameStart
	
	originalNS2GRCheckGameStart = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "CheckGameStart", 
		function(self)

			if not DAK:ExecuteEventHooks("CheckGameStart", self) then
				originalNS2GRCheckGameStart(self)
			end
		
		end
	)
	
	local originalNS2GRCastVoteByPlayer
		
	originalNS2GRCastVoteByPlayer = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "CastVoteByPlayer", 
		function(self, voteTechId, player)
		
			if not DAK:ExecuteEventHooks("OnCastVoteByPlayer", self, voteTechId, player) then
				originalNS2GRCastVoteByPlayer(self, voteTechId, player)
			end

		end
	)
	
	local originalNS2GRSetGameState
	
	originalNS2GRSetGameState = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "SetGameState", 
		function(self, state)

			local currentstate = self.gameState
			originalNS2GRSetGameState( self, state )
			DAK:ExecuteEventHooks("OnSetGameState", self, state, currentstate)
		
		end
	)
	
	local originalNS2GRGetFriendlyFire
	
	originalNS2GRGetFriendlyFire = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "GetFriendlyFire", 
		function(self)
		
			return DAK:GetFriendlyFire()
			//return originalNS2GRGetFriendlyFire( self )
		
		end
	)
	
	function GetFriendlyFire()
		return DAK:GetFriendlyFire()
	end
	
	local originalNS2GRGetCanPlayerHearPlayer
	
	originalNS2GRGetCanPlayerHearPlayer = Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "GetCanPlayerHearPlayer", 
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
	
	originalServerAddChatToHistory = Class_ReplaceMethod("Server", "AddChatToHistory", 
		function(message, playerName, steamId, teamNumber, teamOnly)

			originalServerAddChatToHistory(message, playerName, steamId, teamNumber, teamOnly)

			local client = DAK:GetClientMatchingSteamId(steamId)
			DAK:ExecuteChatCommands(client, message)
			//Leaving this for now as there are times when greater control is needed/useful.
			DAK:ExecuteEventHooks("OnClientChatMessage", message, playerName, steamId, teamNumber, teamOnly, client)

		end
	)

	Script.Load("lua/base/mapcycle.lua")
	
end

if DAK.config and DAK.config.loader and DAK.config.loader.GamerulesExtensions then
	DAK:RegisterEventHook("OnPluginInitialized", DelayedEventHooks, 10)
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

DAK:RegisterEventHook("OnClientConnect", SetServerConfigOnClientConnected, 5)