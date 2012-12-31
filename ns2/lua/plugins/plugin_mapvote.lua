//NS2 End Round map vote.
//Replaces current automatic map switching on round-end.

if kDAKConfig and kDAKConfig.MapVote then

	local kMaxMapVoteChatLength = 74
	local TiedMaps = { }
	local VotingMaps = { }
	local MapVotes = { }
	local PlayerVotes = { }
	local RTVVotes = { }

	local mapvoteintiated = false
	local mapvoterunning = false
	local mapvotecomplete = false
	local mapvotenotify = 0
	local mapvotedelay = 0
	local mapvoteextend = 0
	local nextmap

	if kDAKSettings.PreviousMaps == nil then
		kDAKSettings.PreviousMaps = { }
	end
	
	local function GetMapName(map)
		if type(map) == "table" and map.map ~= nil then
			return map.map
		end
		return map
	end
	
	local function VerifyMapInCycle(mapName)
	
		if kDAKMapCycle and kDAKMapCycle.maps and mapName then
			for i = 1, #kDAKMapCycle.maps do
				if GetMapName(kDAKMapCycle.maps[i]):upper() == mapName:upper() then
					return true
				end
			end
		end
		if kDAKMapCycle and kDAKMapCycle.votemaps and mapName then
			for i = 1, #kDAKMapCycle.votemaps do
				if GetMapName(kDAKMapCycle.votemaps[i]):upper() == mapName:upper() then
					return true
				end
			end
		end
		return false
	end
	
	local function CheckMapVote()
	
		if mapvoterunning or mapvoteintiated or mapvotecomplete then
			return true
		end
		if Shared.GetTime() < ((kDAKMapCycle.time * 60) + (mapvoteextend * 60)) then
			// We haven't been on the current map for long enough.
			return true
		end
		return false
		
	end
	
	local function StartCountdown(gamerules)
		if gamerules then
			gamerules:ResetGame() 
			gamerules:ResetGame()
			gamerules:SetGameState(kGameState.Countdown)      
			gamerules.countdownTime = kCountDownLength     
			gamerules.lastCountdownPlayed = nil 
		end
    end
	
	table.insert(kDAKCheckMapChange, function() return CheckMapVote() end)

	local function UpdateMapVoteCountDown()

		chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapStarted, string.format(kDAKConfig.MapVote.kVoteMinimumPercentage)), 1, kMaxChatLength)
		Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		
		VotingMaps      = { }
		MapVotes        = { }
		PlayerVotes     = { }
		local validmaps = 1
		local recentlyplayed = false
		
		if #TiedMaps > 1 then
		
			for i = 1, #TiedMaps do
						
				VotingMaps[validmaps] = TiedMaps[i]
				MapVotes[validmaps] = 0
				chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapMapListing, ToString(validmaps), TiedMaps[i]), 1, kMaxMapVoteChatLength) .. "******"
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				validmaps = validmaps + 1
				
			end
			
		else
			local tempMaps = { }
			
			if #kDAKSettings.PreviousMaps > kDAKConfig.MapVote.kDontRepeatFor then
				for i = 1, #kDAKSettings.PreviousMaps - kDAKConfig.MapVote.kDontRepeatFor do
					table.remove(kDAKSettings.PreviousMaps, i)
				end
			end
			
			for i = 1, #kDAKMapCycle.maps do
			
				recentlyplayed = false
				local mapName = GetMapName(kDAKMapCycle.maps[i])
				for j = 1, #kDAKSettings.PreviousMaps do
				
					if mapName == kDAKSettings.PreviousMaps[j] then
						recentlyplayed = true
					end
					
				end

				if mapName ~= tostring(Shared.GetMapName()) and not recentlyplayed then	
					table.insert(tempMaps, mapName)
				end
				
			end
			
			if kDAKMapCycle.votemaps ~= nil and #kDAKMapCycle.votemaps > 0 then
				for i = 1, #kDAKMapCycle.votemaps do
				
					recentlyplayed = false
					local mapName = GetMapName(kDAKMapCycle.votemaps[i])
					for j = 1, #kDAKSettings.PreviousMaps do
					
						if mapName == kDAKSettings.PreviousMaps[j] then
							recentlyplayed = true
						end
						
					end

					if mapName ~= tostring(Shared.GetMapName()) and not recentlyplayed then	
						table.insert(tempMaps, mapName)
					end
					
				end
			end
			
			if #tempMaps < kDAKConfig.MapVote.kMapsToSelect then
			
				for i = 1, (kDAKConfig.MapVote.kMapsToSelect - #tempMaps) do
					if kDAKSettings.PreviousMaps[i] ~= tostring(Shared.GetMapName()) and VerifyMapInCycle(kDAKSettings.PreviousMaps[i]) then
						table.insert(tempMaps, kDAKSettings.PreviousMaps[i])
					end
				end
			
			end
			
			//Add in Extend Vote
			if mapvoteextend < (kDAKConfig.MapVote.kExtendDuration * kDAKConfig.MapVote.kMaximumExtends) then
				table.insert(tempMaps, string.format("Extend %s", tostring(Shared.GetMapName())))
			end
			
			if #tempMaps > 0 then
				for i = 1, 100 do //After 100 tries just give up, you failed.
				
					local map = tempMaps[math.random(1, #tempMaps)]
					if tempMaps[map] ~= true then
					
						tempMaps[map] = true
						VotingMaps[validmaps] = map
						MapVotes[validmaps] = 0
						chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapMapListing, ToString(validmaps), map), 1, kMaxMapVoteChatLength) .. "******"
						Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
						validmaps = validmaps + 1
						
					end
					
					if validmaps > kDAKConfig.MapVote.kMapsToSelect then
						break
					end
				
				end
			else
			
				chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapInsufficientMaps, ToString(validmaps), map), 1, kMaxMapVoteChatLength) .. "******"
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				mapvoteintiated = false
				return
				
			end
			
		end
		
		TiedMaps = { }
		mapvoterunning = true
		mapvoteintiated = false
		mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVotingDuration
		mapvotenotify = Shared.GetTime() + kDAKConfig.MapVote.kVoteNotifyDelay

	end

	local function ProcessandSelectMap()

		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		local mapname
		local votepassed = false
		local totalvotes = 0
		
		// This is cleared so that only valid players votes still in the game will count.
		MapVotes = { }
		
		for _, player in ientitylist(playerRecords) do
			
			local client = Server.GetOwner(player)
			if client ~= nil then
				if PlayerVotes[client:GetUserId()] ~= nil then
					if MapVotes[PlayerVotes[client:GetUserId()]] ~= nil then
						MapVotes[PlayerVotes[client:GetUserId()]] = MapVotes[PlayerVotes[client:GetUserId()]] + 1
					else
						MapVotes[PlayerVotes[client:GetUserId()]] = 1
					end
				end					
			end
		
		end
		
		for map, votes in pairs(MapVotes) do
			
			if votes == totalvotes then
			
				table.insert(TiedMaps, VotingMaps[map])
				
			elseif votes > totalvotes then
			
				totalvotes = votes
				mapname = VotingMaps[map]
				TiedMaps = { }
				table.insert(TiedMaps, VotingMaps[map])
				
			end

		end

		if mapname == nil then
		
			chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapNoWinner), 1, kMaxMapVoteChatLength) .. "******"
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			mapvotedelay = 0
			mapvotecomplete = true	
			
		elseif #TiedMaps > 1 then
		
			chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapTie, kDAKConfig.MapVote.kVoteStartDelay), 1, kMaxChatLength) 
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			mapvoteintiated = true
			mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVoteStartDelay
			mapvotecomplete = false	
			mapvoterunning = false
				
		elseif totalvotes >= math.ceil(playerRecords:GetSize() * (kDAKConfig.MapVote.kVoteMinimumPercentage / 100)) then
		
			if mapname == string.format("Extend %s", tostring(Shared.GetMapName())) then
				chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapExtended, kDAKConfig.MapVote.kExtendDuration), 1, kMaxMapVoteChatLength) .. "******"
				mapvotedelay = 0
			else
				chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapWinner, mapname, ToString(totalvotes)), 1, kMaxMapVoteChatLength) .. "******"
				nextmap = mapname
				mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVoteChangeDelay
			end
			
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			votepassed = true
			mapvotecomplete = true	
					
		elseif totalvotes < math.ceil(playerRecords:GetSize() * (kDAKConfig.MapVote.kVoteMinimumPercentage / 100)) then

			chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapMinimumNotMet, mapname, ToString(totalvotes), ToString(math.ceil(playerRecords:GetSize() * (kDAKConfig.MapVote.kVoteMinimumPercentage / 100)))), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			mapvotedelay = 0
			mapvotecomplete = true	
			
		end
		
		mapvotenotify = 0
		
		if mapvotecomplete then
			mapvoterunning = false
			mapvoteintiated = false
			if not votepassed then
				chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapAutomaticChange), 1, kMaxMapVoteChatLength) .. "******"
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				nextmap = nil
				mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVoteChangeDelay
			end
		end

	end

	local function UpdateMapVotes(deltaTime)

		PROFILE("MapVote:UpdateMapVotes")
		
		if mapvotecomplete then
			
			if Shared.GetTime() > mapvotedelay then
			
				if nextmap ~= nil then
					table.insert(kDAKSettings.PreviousMaps, nextmap)
					SaveDAKSettings()
					MapCycle_ChangeToMap(nextmap)
				else
					MapCycle_CycleMap()
				end
				nextmap = nil
				mapvotecomplete = false
				
			end
			
		end
		
		if mapvoteintiated then
		
			if Shared.GetTime() > mapvotedelay then
				UpdateMapVoteCountDown()
			end
			
		end
		
		if mapvoterunning then
		
			if Shared.GetTime() > mapvotedelay then
				ProcessandSelectMap()	
			elseif Shared.GetTime() > mapvotenotify then
				chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapTimeLeft, mapvotedelay - Shared.GetTime()), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				i = 1
				for map, votes in pairs(MapVotes) do
					chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapCurrentMapVotes, votes, VotingMaps[map], i), 1, kMaxMapVoteChatLength) .. "******"
					Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)			
					i = i + 1
				end
				mapvotenotify = Shared.GetTime() + kDAKConfig.MapVote.kVoteNotifyDelay
				
			end

		end
		return true
	end
	
	local function StartMapVote()

		if mapvoterunning or mapvoteintiated or mapvotecomplete then
			return false
		else		
			mapvoteintiated = true
			mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVoteStartDelay
			
			chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapBeginning, kDAKConfig.MapVote.kVoteStartDelay), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
			chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapHowToVote, kDAKConfig.MapVote.kVoteStartDelay), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		end
		
		DAKRegisterEventHook(kDAKOnServerUpdate, UpdateMapVotes, 5)
		return true
		
	end
	
	table.insert(kDAKOverrideMapChange, function() return StartMapVote() end)
	
	local function MapVoteUpdatePregame(self, timePassed)
	
		if self:GetGameState() == kGameState.PreGame then
		
            local preGameTime = kDAKConfig.MapVote.kPregameLength
            if self.timeSinceGameStateChanged > preGameTime then
                StartCountdown(self)
                if Shared.GetCheatsEnabled() then
                    self.countdownTime = 1
                end
            end
			return false
			
		end
		
		return true
		
	end
		
	table.insert(kDAKOnUpdatePregame, function(self, timePassed) return MapVoteUpdatePregame(self, timePassed) end)
	
	local function MapVoteSetGameState(self, state, currentstate)

		if MapCycle_TestCycleMap() then
			self.timeToCycleMap = Shared.GetTime() + kDAKConfig.MapVote.kRoundEndDelay
		end
		
	end
			
	table.insert(kDAKOnSetGameState, function(self, state, currentstate) return MapVoteSetGameState(self, state, currentstate) end)

	local function UpdateRTV(silent, playername)

		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		local totalvotes = 0
		
		for i = #RTVVotes, 1, -1 do
			local clientid = RTVVotes[i]
			local stillplaying = false
			
			for _, player in ientitylist(playerRecords) do
				if player ~= nil then
					local client = Server.GetOwner(player)
					if client ~= nil then
						if clientid == client:GetUserId() then
							stillplaying = true
							totalvotes = totalvotes + 1
							break
						end
					end					
				end
			end
			
			if not stillplaying then
				table.remove(RTVVotes, i)
			end
		
		end
		
		if totalvotes >= math.ceil((playerRecords:GetSize() * (kDAKConfig.MapVote.kRTVMinimumPercentage / 100))) then
		
			StartMapVote()
			RTVVotes = { }
			
		elseif not silent then
		
			chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapRockTheVote, playername, totalvotes, math.ceil((playerRecords:GetSize() * (kDAKConfig.MapVote.kRTVMinimumPercentage / 100)))), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
		end
		return true

	end

	table.insert(kDAKOnClientDisconnect, function(client) return UpdateRTV(true, "") end)

	local function OnCommandVote(client, mapnumber)

		local idNum = tonumber(mapnumber)
		if idNum ~= nil and mapvoterunning and client ~= nil then
			local player = client:GetControllingPlayer()
			if VotingMaps[idNum] ~= nil and player ~= nil then
				
				if PlayerVotes[client:GetUserId()] ~= nil then			
					chatMessage = string.sub(string.format("You already voted for %s.", VotingMaps[PlayerVotes[client:GetUserId()]]), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				else
					MapVotes[idNum] = MapVotes[idNum] + 1
					PlayerVotes[client:GetUserId()] = idNum
					Shared.Message(string.format("%s voted for %s", player:GetName(), VotingMaps[idNum]))
					EnhancedLog(string.format("%s voted for %s", player:GetName(), VotingMaps[idNum]))
					chatMessage = string.sub(string.format("Vote cast for %s.", VotingMaps[idNum]), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
			end
			
		end
		
	end

	Event.Hook("Console_vote",               OnCommandVote)

	local function OnCommandRTV(client)

		if client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				if mapvoterunning or mapvoteintiated or mapvotecomplete then
					chatMessage = string.sub(string.format("Map vote already running."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					return
				end
				if RTVVotes[client:GetUserId()] ~= nil then			
					chatMessage = string.sub(string.format("You already voted for a mapvote."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				else
					table.insert(RTVVotes,client:GetUserId())
					RTVVotes[client:GetUserId()] = true
					Shared.Message(string.format("%s rock'd the vote.", client:GetUserId()))
					EnhancedLog(string.format("%s rock'd the vote.", client:GetUserId()))
					UpdateRTV(false, player:GetName())
				end
			end
			
		end
		
	end

	Event.Hook("Console_rtv",               OnCommandRTV)
	Event.Hook("Console_rockthevote",               OnCommandRTV)
	
	local function OnCommandTimeleft(client)

		if client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				chatMessage = string.sub(string.format("%.1f Minutes Remaining.", math.max(0,((kDAKMapCycle.time * 60) - Shared.GetTime())/60)), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			end
			
		end
		
	end

	Event.Hook("Console_timeleft",               OnCommandTimeleft)
	
	local function OnMapVoteChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
	
		if client and steamId and steamId ~= 0 then
			for c = 1, #kDAKConfig.MapVote.kTimeleftChatCommands do
				local chatcommand = kDAKConfig.MapVote.kTimeleftChatCommands[c]
				if message == chatcommand then
					OnCommandTimeleft(client)
					return true
				end
			end
			for c = 1, #kDAKConfig.MapVote.kRockTheVoteChatCommands do
				local chatcommand = kDAKConfig.MapVote.kRockTheVoteChatCommands[c]
				if message == chatcommand then
					OnCommandRTV(client)
					return true
				end
			end
			for c = 1, #kDAKConfig.MapVote.kVoteChatCommands do
				local chatcommand = kDAKConfig.MapVote.kVoteChatCommands[c]
				if string.sub(message,1,string.len(chatcommand)) == chatcommand then
					OnCommandVote(client, string.sub(message,-1))
					return true
				end
			end
		end
	
	end
	
	table.insert(kDAKOnClientChatMessage, function(message, playerName, steamId, teamNumber, teamOnly, client) return OnMapVoteChatMessage(message, playerName, steamId, teamNumber, teamOnly, client) end)

	local function OnCommandStartMapVote(client)
	
		if mapvoterunning or mapvoteintiated or mapvotecomplete then
			if client ~= nil then
				local player = client:GetControllingPlayer()
				if player ~= nil then
					chatMessage = string.sub(string.format("Map vote already running."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
			else
				Shared.Message("Map vote already running")
			end
		
		else
		
			StartMapVote()
			
		end

		PrintToAllAdmins("sv_votemap", client)

	end

	DAKCreateServerAdminCommand("Console_sv_votemap", OnCommandStartMapVote, "Will start a map vote.")

	local function CancelMapVote(client)
	
		if mapvoterunning or mapvoteintiated or mapvotecomplete then
		
			mapvotenotify = 0
			mapvotecomplete = false
			mapvoterunning = false
			mapvoteintiated = false
			mapvotedelay = 0
			VotingMaps = { }
			MapVotes = { }
			PlayerVotes= { }
			
			chatMessage = string.sub(string.format(kDAKConfig.MapVote.kVoteMapCancelled, kDAKConfig.MapVote.kVoteStartDelay), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			DAKDeregisterEventHook(kDAKOnServerUpdate, UpdateMapVotes)
			
		elseif client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				chatMessage = string.sub(string.format("Map vote not running."), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			end
			
		end
		PrintToAllAdmins("sv_cancelmapvote", client)
		
	end

	DAKCreateServerAdminCommand("Console_sv_cancelmapvote", CancelMapVote, "Will cancel a map vote.")

end
	
Shared.Message("MapVote Loading Complete")