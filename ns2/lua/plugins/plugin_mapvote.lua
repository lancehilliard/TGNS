//NS2 End Round map vote.
//Replaces current automatic map switching on round-end.

if kDAKConfig and kDAKConfig.MapVote then

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
	local pregamenotify = 0
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

	end
	
	DAKRegisterEventHook(kDAKCheckMapChange, CheckMapVote, 5)
	
	local function StartCountdown(gamerules)
		if gamerules then
			gamerules:ResetGame() 
			//gamerules:ResetGame() - Dont think this is necessary anymore, and probably could potentially cause issues.  
			//Used this back when you could hear where the other team spawned to make it more difficult
			gamerules:SetGameState(kGameState.Countdown)      
			gamerules.countdownTime = kCountDownLength     
			gamerules.lastCountdownPlayed = nil 
		end
    end
	
	local function UpdateMapVoteCountDown()

		DAKDisplayMessageToAllClients("kVoteMapStarted", string.format(kDAKConfig.MapVote.kVoteMinimumPercentage))
		
		VotingMaps      = { }
		MapVotes        = { }
		PlayerVotes     = { }
		local validmaps = 1
		local recentlyplayed = false
		
		if #TiedMaps > 1 then
		
			for i = 1, #TiedMaps do
						
				VotingMaps[validmaps] = TiedMaps[i]
				MapVotes[validmaps] = 0
				DAKDisplayMessageToAllClients("kVoteMapMapListing", ToString(validmaps), TiedMaps[i])
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

				if mapName ~= tostring(Shared.GetMapName()) and not recentlyplayed and MapCycle_MeetsPlayerRequirements(mapName) then	
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

					if mapName ~= tostring(Shared.GetMapName()) and not recentlyplayed and MapCycle_MeetsPlayerRequirements(mapName) then	
						table.insert(tempMaps, mapName)
					end
					
				end
			end
			
			if #tempMaps < kDAKConfig.MapVote.kMapsToSelect then
			
				for i = 1, (kDAKConfig.MapVote.kMapsToSelect - #tempMaps) do
					if kDAKSettings.PreviousMaps[i] ~= tostring(Shared.GetMapName()) and VerifyMapInCycle(kDAKSettings.PreviousMaps[i]) and MapCycle_MeetsPlayerRequirements(kDAKSettings.PreviousMaps[i]) then
						table.insert(tempMaps, kDAKSettings.PreviousMaps[i])
					end
				end
			
			end
			
			//Add in Extend Vote
			if mapvoteextend < (kDAKConfig.MapVote.kExtendDuration * kDAKConfig.MapVote.kMaximumExtends) and MapCycle_MeetsPlayerRequirements(tostring(Shared.GetMapName())) then
				table.insert(tempMaps, string.format("extend %s", tostring(Shared.GetMapName())))
			end
			
			if #tempMaps > 0 then
				for i = 1, 100 do //After 100 tries just give up, you failed.
				
					local map = tempMaps[math.random(1, #tempMaps)]
					if tempMaps[map] ~= true then
					
						tempMaps[map] = true
						VotingMaps[validmaps] = map
						MapVotes[validmaps] = 0
						DAKDisplayMessageToAllClients("kVoteMapMapListing", ToString(validmaps), map)
						validmaps = validmaps + 1
						
					end
					
					if validmaps > kDAKConfig.MapVote.kMapsToSelect then
						break
					end
				
				end
			else
			
				DAKDisplayMessageToAllClients("kVoteMapInsufficientMaps", ToString(validmaps), map)
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
	
	local function OnCommandVote(client, mapnumber)

		local idNum = tonumber(mapnumber)
		if idNum ~= nil and mapvoterunning and client ~= nil then
			local player = client:GetControllingPlayer()
			if VotingMaps[idNum] ~= nil and player ~= nil then
				
				if PlayerVotes[client:GetUserId()] ~= nil then
					DAKDisplayMessageToClient(client, "kVoteMapAlreadyVoted", VotingMaps[PlayerVotes[client:GetUserId()]])
				else
					MapVotes[idNum] = MapVotes[idNum] + 1
					PlayerVotes[client:GetUserId()] = idNum
					Shared.Message(string.format("%s voted for %s", player:GetName(), VotingMaps[idNum]))
					EnhancedLog(string.format("%s voted for %s", player:GetName(), VotingMaps[idNum]))
					DAKDisplayMessageToClient(client, "kVoteMapCastVote", VotingMaps[idNum])
				end
			end
			
		end
		
	end

	Event.Hook("Console_vote",               OnCommandVote)
	
	local function OnCommandUpdateVote(cID, LastUpdateMessage)
		//OnVoteUpdateFunction
		if mapvoterunning then
			local client =  GetClientMatchingGameId(cID)
			//more crap
			//local kVoteBaseUpdateMessage = 
			//{
			//	header         		= string.format("string (%d)", kMaxVoteStringLength),
			//	option1         	= string.format("string (%d)", kMaxVoteStringLength),
			//	option1desc         = string.format("string (%d)", kMaxVoteStringLength),
			//	option2        		= string.format("string (%d)", kMaxVoteStringLength),
			//	option2desc         = string.format("string (%d)", kMaxVoteStringLength),
			//	option3        		= string.format("string (%d)", kMaxVoteStringLength),
			//	option3desc         = string.format("string (%d)", kMaxVoteStringLength),
			//	option4        		= string.format("string (%d)", kMaxVoteStringLength),
			//	option4desc         = string.format("string (%d)", kMaxVoteStringLength),
			//	option5         	= string.format("string (%d)", kMaxVoteStringLength),
			//	option5desc         = string.format("string (%d)", kMaxVoteStringLength),
			//	footer         		= string.format("string (%d)", kMaxVoteStringLength),
			//  inputallowed		= "boolean",
			//	votetime   	  		= "time"
			//}
			local kVoteUpdateMessage = { }
			kVoteUpdateMessage.header = string.format(DAKGetLanguageSpecificMessage("kVoteMapTimeLeft", DAKGetClientLanguageSetting(client)), mapvotedelay - Shared.GetTime())
			i = 1
			for map, votes in pairs(MapVotes) do
				local message = string.format(DAKGetLanguageSpecificMessage("kVoteMapCurrentMapVotes", DAKGetClientLanguageSetting(client)), votes, VotingMaps[map], i)
				if i == 1 then
					option1 = "1: = "
					option1desc = message
				elseif i == 2 then
					option2 = "2: = "
					option2desc = message
				elseif i == 3 then
					option3 = "3: = "
					option3desc = message
				elseif i == 4 then
					option4 = "4: = "
					option4desc = message
				elseif i == 5 then
					option5 = "5: = "
					option5desc = message
				end
				i = i + 1
			end
			kVoteUpdateMessage.footer = "Press a number key to vote for the corresponding map"
			kVoteUpdateMessage.inputallowed = false
			if client ~= nil then
				kVoteUpdateMessage.inputallowed = PlayerVotes[client:GetUserId()] == nil
			end
			kVoteUpdateMessage.votetime = Shared.GetTime()
			return kVoteUpdateMessage
		end
		return nil
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
		
			DAKDisplayMessageToAllClients("kVoteMapNoWinner")
			mapvotedelay = 0
			mapvotecomplete = true	
			
		elseif #TiedMaps > 1 then
		
			DAKDisplayMessageToAllClients("kVoteMapTie", kDAKConfig.MapVote.kVoteStartDelay)
			mapvoteintiated = true
			mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVoteStartDelay
			mapvotecomplete = false	
			mapvoterunning = false
				
		elseif totalvotes >= math.ceil(playerRecords:GetSize() * (kDAKConfig.MapVote.kVoteMinimumPercentage / 100)) then
		
			if mapname == string.format("extend %s", tostring(Shared.GetMapName())) then
				DAKDisplayMessageToAllClients("kVoteMapExtended", kDAKConfig.MapVote.kExtendDuration)
				mapvotedelay = 0
				nextmap = "extend"
			else
				DAKDisplayMessageToAllClients("kVoteMapWinner", mapname, ToString(totalvotes))
				nextmap = mapname
				mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVoteChangeDelay
			end
			
			votepassed = true
			mapvotecomplete = true
			
		elseif totalvotes < math.ceil(playerRecords:GetSize() * (kDAKConfig.MapVote.kVoteMinimumPercentage / 100)) then

			DAKDisplayMessageToAllClients("kVoteMapMinimumNotMet", mapname, ToString(totalvotes), ToString(math.ceil(playerRecords:GetSize() * (kDAKConfig.MapVote.kVoteMinimumPercentage / 100))))
			mapvotedelay = 0
			mapvotecomplete = true	
			
		end
		
		mapvotenotify = 0
		
		if mapvotecomplete then
			mapvoterunning = false
			mapvoteintiated = false
			if not votepassed then
				DAKDisplayMessageToAllClients("kVoteMapAutomaticChange")
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
					if nextmap == "extend" then
						DAKDeregisterEventHook(kDAKOnServerUpdate, UpdateMapVotes)
					else
						table.insert(kDAKSettings.PreviousMaps, nextmap)
						SaveDAKSettings()
						MapCycle_ChangeToMap(nextmap)
					end
				else
					MapCycle_ChangeToMap(GetMapName(MapCycle_GetNextMapInCycle()))
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
				
				local playerRecords = Shared.GetEntitiesWithClassname("Player")				
				for _, player in ientitylist(playerRecords) do
					DAKCreateGUIVoteBase(GetGameIdMatchingPlayer(player), OnCommandVote, OnCommandUpdateVote)
				end
				DAKDisplayMessageToAllClients("kVoteMapTimeLeft", mapvotedelay - Shared.GetTime())
				i = 1
				for map, votes in pairs(MapVotes) do
					DAKDisplayMessageToAllClients("kVoteMapCurrentMapVotes", votes, VotingMaps[map], i)	
					i = i + 1
				end
				mapvotenotify = Shared.GetTime() + kDAKConfig.MapVote.kVoteNotifyDelay
				
			end

		end

	end
	
	local function StartMapVote()

		if not mapvoterunning and not mapvoteintiated and not mapvotecomplete then
		
			mapvoteintiated = true
			mapvotedelay = Shared.GetTime() + kDAKConfig.MapVote.kVoteStartDelay
			DAKDisplayMessageToAllClients("kVoteMapBeginning", kDAKConfig.MapVote.kVoteStartDelay)
			DAKDisplayMessageToAllClients("kVoteMapHowToVote")
			DAKRegisterEventHook(kDAKOnServerUpdate, UpdateMapVotes, 5)
			
		end
		
		return true
	end
	
	DAKRegisterEventHook(kDAKOverrideMapChange, StartMapVote, 5)
	
	local function MapVoteUpdatePregame(self, timePassed)
	
		if self:GetGameState() == kGameState.PreGame then
		
            local preGameTime = kDAKConfig.MapVote.kPregameLength
            if self.timeSinceGameStateChanged > preGameTime then
                StartCountdown(self)
                if Shared.GetCheatsEnabled() then
                    self.countdownTime = 1
                end
			elseif pregamenotify + kDAKConfig.MapVote.kPregameNotifyDelay < Shared.GetTime() then
				DAKDisplayMessageToAllClients("kPregameNotification", (preGameTime - self.timeSinceGameStateChanged))
				pregamenotify = Shared.GetTime()
            end
			return true
			
		end

	end
	
	DAKRegisterEventHook(kDAKOnUpdatePregame, MapVoteUpdatePregame, 5)

	local function MapVoteSetGameState(self, state, currentstate)

		if MapCycle_TestCycleMap() then
			self.timeToCycleMap = Shared.GetTime() + kDAKConfig.MapVote.kRoundEndDelay
		end
		
	end
	
	DAKRegisterEventHook(kDAKOnSetGameState, MapVoteSetGameState, 5)

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
		
			DAKDisplayMessageToAllClients("kVoteMapRockTheVote", playername, totalvotes, math.ceil((playerRecords:GetSize() * (kDAKConfig.MapVote.kRTVMinimumPercentage / 100))))
			
		end

	end
	
	DAKRegisterEventHook(kDAKOnClientDisconnect, UpdateRTV, 5)

	local function OnCommandRTV(client)

		if client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				if mapvoterunning or mapvoteintiated or mapvotecomplete then
					DAKDisplayMessageToClient(client, "kVoteMapAlreadyRunning")
					return
				end
				if RTVVotes[client:GetUserId()] ~= nil then			
					DAKDisplayMessageToClient(client, "kVoteMapAlreadyRTVd")
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
			DAKDisplayMessageToClient(client, "kVoteMapTimeRemaining", math.max(0,((kDAKMapCycle.time * 60) - Shared.GetTime())/60))
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
	
	DAKRegisterEventHook(kDAKOnClientChatMessage, OnMapVoteChatMessage, 5)
	
	local function OnCommandStartMapVote(client)
	
		if mapvoterunning or mapvoteintiated or mapvotecomplete then
			if client ~= nil then
				DAKDisplayMessageToClient(client, "kVoteMapAlreadyRunning")
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
			
			DAKDisplayMessageToAllClients("kVoteMapCancelled")
			DAKDeregisterEventHook(kDAKOnServerUpdate, UpdateMapVotes)
			
		elseif client ~= nil then
			DAKDisplayMessageToClient(client, "kVoteMapNotRunning")
		end
		PrintToAllAdmins("sv_cancelmapvote", client)
		
	end

	DAKCreateServerAdminCommand("Console_sv_cancelmapvote", CancelMapVote, "Will cancel a map vote.")

end
	
Shared.Message("MapVote Loading Complete")