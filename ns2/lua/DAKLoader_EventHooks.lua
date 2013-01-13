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

	if kDAKConfig and kDAKConfig.DAKLoader then
		if client ~= nil and VerifyClient(client) ~= nil then
			table.insert(kDAKGameID, client)
			DAKExecuteEventHooks(kDAKOnClientConnect, client)
			if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.kDelayedClientConnect then
				local CEntry = { Client = client, Time = Shared.GetTime() + kDAKConfig.DAKLoader.kDelayedClientConnect }
				table.insert(DelayedClientConnect, CEntry)
			end
		end
	end
end

Event.Hook("ClientConnect", DAKOnClientConnected)

local function DAKOnClientDisconnected(client)

	if kDAKConfig and kDAKConfig.DAKLoader then
		if client ~= nil and VerifyClient(client) ~= nil then
			DAKExecuteEventHooks(kDAKOnClientDisconnect, client)
		end
	end
	
end

Event.Hook("ClientDisconnect", DAKOnClientDisconnected)

local function DAKUpdateServer(deltaTime)

	PROFILE("DAKLoader:DAKUpdateServer")
	
	if kDAKConfig and kDAKConfig.DAKLoader then
		serverupdatetime = serverupdatetime + deltaTime
		if kDAKConfig.DAKLoader.kDelayedServerUpdate and serverupdatetime > kDAKConfig.DAKLoader.kDelayedServerUpdate then
		
			DAKExecuteEventHooks(kDAKOnServerUpdate, deltaTime)
			
			if #DelayedClientConnect > 0 then
				for i = #DelayedClientConnect, 1, -1 do
					local CEntry = DelayedClientConnect[i]
					if CEntry ~= nil and CEntry.Client ~= nil and VerifyClient(CEntry.Client) ~= nil then
						if CEntry.Time < Shared.GetTime() then
							DAKExecuteEventHooks(kDAKOnClientDelayedConnect, CEntry.Client)
							DelayedClientConnect[i] = nil
						end
					else
						DelayedClientConnect[i] = nil
					end
				end
			end
			
			//Print(string.format("%.5f Accuracy", (100 - math.abs(100 - ((serverupdatetime/1) * 100)))))
			serverupdatetime = serverupdatetime - kDAKConfig.DAKLoader.kDelayedServerUpdate
			
		end
		
	end
	
end	

Event.Hook("UpdateServer", DAKUpdateServer)

if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.GamerulesExtensions then

	if kDAKConfig.DAKLoader.GamerulesClassName == nil then kDAKConfig.DAKLoader.GamerulesClassName = "NS2Gamerules" end
		
	local originalNS2GRJoinTeam
	
	originalNS2GRJoinTeam = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "JoinTeam", 
		function(self, player, newTeamNumber, force)
		
			if not DAKExecuteEventHooks(kDAKOnTeamJoin, self, player, newTeamNumber, force) then
				return originalNS2GRJoinTeam(self, player, newTeamNumber, force)
			end
			return false, player
			
		end
	)
	
	local originalNS2GREndGame
	
	originalNS2GREndGame = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "EndGame", 
		function(self, winningTeam)
		
			DAKExecuteEventHooks(kDAKOnGameEnd, self, winningTeam)
			originalNS2GREndGame(self, winningTeam)
			
		end
	)
	
	local originalNS2GREntityKilled
	
	originalNS2GREntityKilled = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "OnEntityKilled", 
		function(self, targetEntity, attacker, doer, point, direction)
		
			if attacker and targetEntity and doer then
				DAKExecuteEventHooks(kDAKOnEntityKilled, self, targetEntity, attacker, doer, point, direction)
			end
			originalNS2GREntityKilled(self, targetEntity, attacker, doer, point, direction)
		
		end
	)
	
	local originalNS2GRUpdatePregame
	
	originalNS2GRUpdatePregame = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "UpdatePregame", 
		function(self, timePassed)

			if not DAKExecuteEventHooks(kDAKOnUpdatePregame, self, timePassed) then
				originalNS2GRUpdatePregame(self, timePassed)
			end
		
		end
	)
	
	local originalNS2GRCastVoteByPlayer
		
	originalNS2GRCastVoteByPlayer = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "CastVoteByPlayer", 
		function(self, voteTechId, player)
		
			if not DAKExecuteEventHooks(kDAKOnCastVoteByPlayer, self, voteTechId, player) then
				originalNS2GRCastVoteByPlayer(self, voteTechId, player)
			end

		end
	)
	
	local originalNS2GRSetGameState
	
	originalNS2GRSetGameState = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "SetGameState", 
		function(self, state)

			local currentstate = self.gameState
			originalNS2GRSetGameState( self, state )
			DAKExecuteEventHooks(kDAKOnSetGameState, self, state, currentstate)
		
		end
	)
	
	local originalNS2GRGetCanPlayerHearPlayer
	
	originalNS2GRGetCanPlayerHearPlayer = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "GetCanPlayerHearPlayer", 
		function(self, listenerPlayer, speakerPlayer)

			local canHear = originalNS2GRGetCanPlayerHearPlayer( self, listenerPlayer, speakerPlayer )
			
			if kDAKSettings and kDAKSettings.AllTalk then
				canHear = true
			end
			
			return canHear
			
		end
	)
		
	local function DelayedEventOverride()
		
		local originalServerAddChatToHistory
		
		originalServerAddChatToHistory = Class_ReplaceMethod("Server", "AddChatToHistory", 
			function(message, playerName, steamId, teamNumber, teamOnly)

				originalServerAddChatToHistory(message, playerName, steamId, teamNumber, teamOnly)

				local client = GetClientMatchingSteamId(steamId)
				DAKExecuteEventHooks(kDAKOnClientChatMessage, message, playerName, steamId, teamNumber, teamOnly, client)

			end
		)

		Script.Load("lua/DAKLoader_MapCycle.lua")
		DAKDeregisterEventHook(kDAKOnServerUpdate, DelayedEventOverride)
	end

	DAKRegisterEventHook(kDAKOnServerUpdate, DelayedEventOverride, 5)
	
end
	
if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.OverrideInterp and kDAKConfig.DAKLoader.OverrideInterp.kEnabled then

	local function SetInterpOnClientConnected(client)
		if kDAKConfig.DAKLoader.OverrideInterp.kEnabled then
			Shared.ConsoleCommand(string.format("interp %f", (kDAKConfig.DAKLoader.OverrideInterp.kInterp/1000)))
		end
	end

	DAKRegisterEventHook(kDAKOnClientConnect, SetInterpOnClientConnected, 5)
	
end