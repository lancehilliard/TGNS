//DAK Events

//******************************************************************************************************************
//Event Hooking
//******************************************************************************************************************

local DelayedClientConnect = { }
local serverupdatetime = 0

local function DAKOnClientConnected(client)

	if kDAKConfig and kDAKConfig.DAKLoader then
		if client ~= nil and VerifyClient(client) ~= nil then
			table.insert(kDAKGameID, client)
			if #kDAKOnClientConnect > 0 then
				for i = 1, #kDAKOnClientConnect do
					if not kDAKOnClientConnect[i](client) then break end
				end
			end
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
			if #DelayedClientConnect > 0 then
				for i = 1, #DelayedClientConnect do
					local PEntry = DelayedClientConnect[i]
					if PEntry ~= nil and PEntry.Client ~= nil then
						if client == PEntry.Client then
							DelayedClientConnect[i] = nil
							break
						end
					end
				end		
			end
			if #kDAKOnClientDisconnect > 0 then
				for i = 1, #kDAKOnClientDisconnect do
					if not kDAKOnClientDisconnect[i](client) then break end
				end
			end
		end
	end
	
end

Event.Hook("ClientDisconnect", DAKOnClientDisconnected)

local function DAKUpdateServer(deltaTime)

	PROFILE("DAKLoader:DAKUpdateServer")
	
	if kDAKConfig and kDAKConfig.DAKLoader then
		serverupdatetime = serverupdatetime + deltaTime
		if kDAKConfig.DAKLoader.kDelayedServerUpdate and serverupdatetime > kDAKConfig.DAKLoader.kDelayedServerUpdate then
		
			if #kDAKOnServerUpdate > 0 then
				for i = #kDAKOnServerUpdate, 1, -1 do
					kDAKOnServerUpdate[i].func(deltaTime)
				end
			end
			
			if #DelayedClientConnect > 0 then
				for i = #DelayedClientConnect, 1, -1 do
					local CEntry = DelayedClientConnect[i]
					if CEntry ~= nil and CEntry.Client ~= nil and VerifyClient(CEntry.Client) ~= nil then
						if CEntry.Time < Shared.GetTime() then
							if #kDAKOnClientDelayedConnect > 0 then
								for i = 1, #kDAKOnClientDelayedConnect do
									if not kDAKOnClientDelayedConnect[i](CEntry.Client) then
										break 
									end
								end
							end
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
		
			local client = Server.GetOwner(player)
			if client ~= nil then
				if #kDAKOnTeamJoin > 0 then
					for i = 1, #kDAKOnTeamJoin do
						if not kDAKOnTeamJoin[i](player, newTeamNumber, force) then
							return false, player
						end
					end
				end
			end
			return originalNS2GRJoinTeam(self, player, newTeamNumber, force)

		end
	)
	
	local originalNS2GREndGame
	
	originalNS2GREndGame = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "EndGame", 
		function(self, winningTeam)
			if #kDAKOnGameEnd > 0 then
				for i = 1, #kDAKOnGameEnd do
					kDAKOnGameEnd[i](winningTeam)
				end
			end
			originalNS2GREndGame(self, winningTeam)
		end
	)
	
	local originalNS2GREntityKilled
	
	originalNS2GREntityKilled = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "OnEntityKilled", 
		function(self, targetEntity, attacker, doer, point, direction)
		
			if attacker and targetEntity and doer then
				if #kDAKOnEntityKilled > 0 then
					for i = 1, #kDAKOnEntityKilled do
						kDAKOnEntityKilled[i](targetEntity, attacker, doer, point, direction)
					end
				end
			end
			originalNS2GREntityKilled(self, targetEntity, attacker, doer, point, direction)
		
		end
	)
	
	local originalNS2GRUpdatePregame
	
	originalNS2GRUpdatePregame = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "UpdatePregame", 
		function(self, timePassed)

			if #kDAKOnUpdatePregame > 0 then
				for i = 1, #kDAKOnUpdatePregame do
					if not kDAKOnUpdatePregame[i](self, timePassed) then
						return
					end
				end
			end
			originalNS2GRUpdatePregame(self, timePassed)
		
		end
	)
	
	local originalNS2GRCastVoteByPlayer
		
	originalNS2GRCastVoteByPlayer = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "CastVoteByPlayer", 
		function(self, voteTechId, player)
		
			if #kDAKOnCastVoteByPlayer > 0 then
				for i = 1, #kDAKOnCastVoteByPlayer do
					if not kDAKOnCastVoteByPlayer[i](self, voteTechId, player) then
						return
					end
				end
			end
			originalNS2GRCastVoteByPlayer(self, voteTechId, player)

		end
	)
	
	local originalNS2GRSetGameState
	
	originalNS2GRSetGameState = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "SetGameState", 
		function(self, state)

			local currentstate = self.gameState
			originalNS2GRSetGameState( self, state )
			if #kDAKOnSetGameState > 0 then
				for i = 1, #kDAKOnSetGameState do
					kDAKOnSetGameState[i](self, state, currentstate)
				end
			end
		
		end
	)
	
	local originalNS2GRGetCanPlayerHearPlayer
	
	originalNS2GRGetCanPlayerHearPlayer = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "GetCanPlayerHearPlayer", 
		function(self, listenerPlayer, speakerPlayer)

			local canHear = false
			
			// Check if the listerner has the speaker muted.
			if listenerPlayer:GetClientMuted(speakerPlayer:GetClientIndex()) then
				return false
			end
			
			// If both players have the same team number, they can hear each other
			if(listenerPlayer:GetTeamNumber() == speakerPlayer:GetTeamNumber()) then
				canHear = true
			end
				
			// Or if cheats or dev mode is on, they can hear each other
			if(Shared.GetCheatsEnabled() or Shared.GetDevMode()) then
				canHear = true
			end
			
			if kDAKSettings and kDAKSettings.AllTalk then
				canHear = true
			end
			
			// If we're spectating a player, we can hear their team (but not in tournamentmode, once that's in)
			if self:GetIsPlayerFollowingTeamNumber(listenerPlayer, speakerPlayer:GetTeamNumber()) then
				canHear = true
			end
			
			return canHear
			
		end
	)
		
	// Recent chat messages are stored on the server.
	//Server.recentChatMessages = CreateRingBuffer(20)
	local chatMessageCount = 0

	function Server.AddChatToHistory(message, playerName, steamId, teamNumber, teamOnly)

		chatMessageCount = chatMessageCount + 1
		Server.recentChatMessages:Insert({ id = chatMessageCount, message = message, player = playerName,
										   steamId = steamId, team = teamNumber, teamOnly = teamOnly })

		local client = GetClientMatchingSteamId(steamId)
		if #kDAKOnClientChatMessage > 0 then
			for i = 1, #kDAKOnClientChatMessage do
				kDAKOnClientChatMessage[i](message, playerName, steamId, teamNumber, teamOnly, client)
			end
		end

	end
	
end
	
if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.OverrideInterp and kDAKConfig.DAKLoader.OverrideInterp.kEnabled then

	local function SetInterpOnClientConnected(client)
		if kDAKConfig.DAKLoader.OverrideInterp.kEnabled then
			Shared.ConsoleCommand(string.format("interp %f", (kDAKConfig.DAKLoader.OverrideInterp.kInterp/1000)))
		end
		return true
	end

	table.insert(kDAKOnClientConnect, function(client) return SetInterpOnClientConnected() end)
	
end