//NS2 End Round map vote.
//Replaces current automatic map switching on round-end.

local TiedMaps = { }
local VotingMaps = { }
local MapVotes = { }
local PlayerVotes = { }
local RTVVotes = { }

local mapvoteintiated = false
local mapvoterunning = false
local mapvotecomplete = false
local mapvoterocked = false
local mapvotenotify = 0
local mapvotedelay = 0
local mapvoteextend = 0
local pregamenotify = 0
local tievotes = 0
local nextmap

if DAK.settings.PreviousMaps == nil then
	DAK.settings.PreviousMaps = { }
end

local function GetMapName(map)
	if type(map) == "table" and map.map ~= nil then
		return map.map
	end
	return map
end

local function CheckMapVote()

	if mapvoterunning or mapvoteintiated or mapvotecomplete then
		return true
	end
	if Shared.GetTime() < ((MapCycle_GetMapCycleTime() * 60) + (mapvoteextend * 60)) then
		// We haven't been on the current map for long enough.
		return true
	end

end

DAK:RegisterEventHook("CheckMapChange", CheckMapVote, 5)

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

	DAK:DisplayMessageToAllClients("VoteMapStarted", string.format(DAK.config.mapvote.kVoteMinimumPercentage))
	
	VotingMaps      = { }
	MapVotes        = { }
	PlayerVotes     = { }
	local validmaps = 1
	local recentlyplayed = false
	
	if #TiedMaps > 1 then
	
		for i = 1, #TiedMaps do
					
			VotingMaps[validmaps] = TiedMaps[i]
			MapVotes[validmaps] = 0
			DAK:DisplayMessageToAllClients("VoteMapMapListing", ToString(validmaps), TiedMaps[i])
			validmaps = validmaps + 1
			
		end
		
	else
		local tempMaps = { }
		
		if #DAK.settings.PreviousMaps > DAK.config.mapvote.kDontRepeatFor then
			for i = 1, #DAK.settings.PreviousMaps - DAK.config.mapvote.kDontRepeatFor do
				table.remove(DAK.settings.PreviousMaps, i)
			end
		end
		
		local MapsArray = MapCycle_GetMapCycleArray()
		if MapsArray ~= nil and #MapsArray > 0 then
			for i = 1, #MapsArray do
			
				recentlyplayed = false
				local mapName = GetMapName(MapsArray[i])
				for j = 1, #DAK.settings.PreviousMaps do
				
					if mapName == DAK.settings.PreviousMaps[j] then
						recentlyplayed = true
					end
					
				end

				if mapName ~= tostring(Shared.GetMapName()) and not recentlyplayed and MapCycle_GetMapMeetsPlayerRequirements(mapName) then	
					table.insert(tempMaps, mapName)
				end
				
			end
		end
		local VoteMapsArray = MapCycle_GetVoteMapCycleArray()
		if VoteMapsArray ~= nil and #VoteMapsArray > 0 then
			for i = 1, #VoteMapsArray do
			
				recentlyplayed = false
				local mapName = GetMapName(VoteMapsArray[i])
				for j = 1, #DAK.settings.PreviousMaps do
				
					if mapName == DAK.settings.PreviousMaps[j] then
						recentlyplayed = true
					end
					
				end

				if mapName ~= tostring(Shared.GetMapName()) and not recentlyplayed and MapCycle_GetMapMeetsPlayerRequirements(mapName) then	
					table.insert(tempMaps, mapName)
				end
				
			end
		end
		
		if #tempMaps < DAK.config.mapvote.kMapsToSelect then
		
			for i = 1, (DAK.config.mapvote.kMapsToSelect - #tempMaps) do
				if DAK.settings.PreviousMaps[i] ~= tostring(Shared.GetMapName()) and MapCycle_VerifyMapInCycle(DAK.settings.PreviousMaps[i]) and MapCycle_GetMapMeetsPlayerRequirements(DAK.settings.PreviousMaps[i]) then
					table.insert(tempMaps, DAK.settings.PreviousMaps[i])
				end
			end
		
		end
		
		//Add in Extend Vote
		if mapvoteextend < (DAK.config.mapvote.kExtendDuration * DAK.config.mapvote.kMaximumExtends) and MapCycle_GetMapMeetsPlayerRequirements(tostring(Shared.GetMapName())) then
			table.insert(tempMaps, string.format("extend %s", tostring(Shared.GetMapName())))
		end
		
		if #tempMaps > 0 then
			for i = 1, 100 do //After 100 tries just give up, you failed.
			
				local map = tempMaps[math.random(1, #tempMaps)]
				if tempMaps[map] ~= true then
				
					tempMaps[map] = true
					VotingMaps[validmaps] = map
					MapVotes[validmaps] = 0
					DAK:DisplayMessageToAllClients("VoteMapMapListing", ToString(validmaps), map)
					validmaps = validmaps + 1
					
				end
				
				if validmaps > DAK.config.mapvote.kMapsToSelect then
					break
				end
			
			end
		else
		
			DAK:DisplayMessageToAllClients("VoteMapInsufficientMaps", ToString(validmaps), map)
			mapvoteintiated = false
			return
			
		end
		
	end
	
	TiedMaps = { }
	mapvoterunning = true
	mapvoteintiated = false
	mapvotedelay = Shared.GetTime() + DAK.config.mapvote.kVotingDuration
	mapvotenotify = Shared.GetTime() + DAK.config.mapvote.kVoteNotifyDelay

end

local function OnCommandVote(client, mapnumber)

	local idNum = tonumber(mapnumber)
	if idNum ~= nil and mapvoterunning and client ~= nil then
		local player = client:GetControllingPlayer()
		if VotingMaps[idNum] ~= nil and player ~= nil then
			
			if PlayerVotes[client:GetUserId()] ~= nil then
				DAK:DisplayMessageToClient(client, "VoteMapAlreadyVoted", VotingMaps[PlayerVotes[client:GetUserId()]])
			else
				MapVotes[idNum] = MapVotes[idNum] + 1
				PlayerVotes[client:GetUserId()] = idNum
				Shared.Message(string.format("%s voted for %s", DAK:GetClientUIDString(client), VotingMaps[idNum]))
				DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, string.format("%s voted for %s", DAK:GetClientUIDString(client), VotingMaps[idNum]))
				DAK:DisplayMessageToClient(client, "VoteMapCastVote", VotingMaps[idNum])
			end
		end
		
	end
	
end

Event.Hook("Console_vote",               OnCommandVote)

local function OnCommandUpdateVote(cID, LastUpdateMessage)
	//OnVoteUpdateFunction
	local kVoteUpdateMessage = DAK:ExecutePluginGlobalFunction("guimenubase", CreateMenuBaseNetworkMessage)
	if kVoteUpdateMessage == nil then
		kVoteUpdateMessage = { }
	end
	if mapvoterunning then
		local client =  DAK:GetClientMatchingGameId(cID)
		kVoteUpdateMessage.header = string.format(DAK:GetLanguageSpecificMessage("VoteMapTimeLeft", DAK:GetClientLanguageSetting(client)), mapvotedelay - Shared.GetTime())
		i = 1
		for map, votes in pairs(MapVotes) do
			local message = string.format(DAK:GetLanguageSpecificMessage("VoteMapCurrentMapVotes", DAK:GetClientLanguageSetting(client)), votes, VotingMaps[map], i)
			if i == 1 then
				kVoteUpdateMessage.option1 = "1: = "
				kVoteUpdateMessage.option1desc = message
			elseif i == 2 then
				kVoteUpdateMessage.option2 = "2: = "
				kVoteUpdateMessage.option2desc = message
			elseif i == 3 then
				kVoteUpdateMessage.option3 = "3: = "
				kVoteUpdateMessage.option3desc = message
			elseif i == 4 then
				kVoteUpdateMessage.option4 = "4: = "
				kVoteUpdateMessage.option4desc = message
			elseif i == 5 then
				kVoteUpdateMessage.option5 = "5: = "
				kVoteUpdateMessage.option5desc = message
			end
			i = i + 1
		end
		kVoteUpdateMessage.footer = "Press a number key to vote for the corresponding map"
		kVoteUpdateMessage.inputallowed = false
		if client ~= nil then
			kVoteUpdateMessage.inputallowed = PlayerVotes[client:GetUserId()] == nil
		end
	end
	return kVoteUpdateMessage
end

local function ProcessandSelectMap()

	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	local mapname
	local votepassed = false
	local totalvotes = 0
	
	// This is cleared so that only valid players still in the game votes will count.
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
	
		DAK:DisplayMessageToAllClients("VoteMapNoWinner")
		mapvotedelay = 0
		mapvotecomplete = true	
		
	elseif #TiedMaps > 1 then
	
		if tievotes < DAK.config.mapvote.kMaximumTies then
			DAK:DisplayMessageToAllClients("VoteMapTie", DAK.config.mapvote.kVoteStartDelay)
			mapvoteintiated = true
			mapvotedelay = Shared.GetTime() + DAK.config.mapvote.kVoteStartDelay
			mapvotecomplete = false	
			mapvoterunning = false
			tievotes = tievotes + 1
		else
			local TiedMap = TiedMaps[math.random(1, #TiedMaps)]
			DAK:DisplayMessageToAllClients("VoteMapTieBreaker", TiedMap)
			nextmap = TiedMap
			mapvotedelay = Shared.GetTime() + DAK.config.mapvote.kVoteChangeDelay
			votepassed = true
			mapvotecomplete = true
		end
			
	elseif totalvotes >= math.ceil(playerRecords:GetSize() * (DAK.config.mapvote.kVoteMinimumPercentage / 100)) then
	
		if mapname == string.format("extend %s", tostring(Shared.GetMapName())) then
			DAK:DisplayMessageToAllClients("VoteMapExtended", DAK.config.mapvote.kExtendDuration)
			mapvotedelay = 0
			nextmap = "extend"
		else
			DAK:DisplayMessageToAllClients("VoteMapWinner", mapname, ToString(totalvotes))
			nextmap = mapname
			mapvotedelay = Shared.GetTime() + DAK.config.mapvote.kVoteChangeDelay
		end
		
		votepassed = true
		mapvotecomplete = true
		
	elseif totalvotes < math.ceil(playerRecords:GetSize() * (DAK.config.mapvote.kVoteMinimumPercentage / 100)) then

		DAK:DisplayMessageToAllClients("VoteMapMinimumNotMet", mapname, ToString(totalvotes), ToString(math.ceil(playerRecords:GetSize() * (DAK.config.mapvote.kVoteMinimumPercentage / 100))))
		mapvotedelay = 0
		mapvotecomplete = true	
		
	end
	
	mapvotenotify = 0
	
	if mapvotecomplete then
		mapvoterunning = false
		mapvoteintiated = false
		if not votepassed and not mapvoterocked then
			DAK:DisplayMessageToAllClients("VoteMapAutomaticChange")
			nextmap = nil
			mapvotedelay = Shared.GetTime() + DAK.config.mapvote.kVoteChangeDelay
		end
	end

end

local function UpdateMapVotes(deltaTime)
	
	if mapvotecomplete then
		
		if Shared.GetTime() > mapvotedelay then

			if nextmap ~= nil then
				if nextmap ~= "extend" then
					table.insert(DAK.settings.PreviousMaps, nextmap)
					DAK:SaveSettings()
					MapCycle_ChangeToMap(nextmap)
				end
			elseif not mapvoterocked then
				MapCycle_ChangeToMap(GetMapName(MapCycle_GetNextMapInCycle()))
			end
			DAK:DeregisterEventHook("OnServerUpdate", UpdateMapVotes)
			mapvoterocked = false
			nextmap = nil
			mapvotecomplete = false
			tievotes = 0
			
		end
		
	end
	
	if mapvoteintiated then

		if Shared.GetTime() > mapvotedelay then
		
			UpdateMapVoteCountDown()
			
			//local playerRecords = Shared.GetEntitiesWithClassname("Player")				
			//for _, player in ientitylist(playerRecords) do
				//DAK:ExecutePluginGlobalFunction("guimenubase", CreateGUIMenuBase, DAK:GetGameIdMatchingPlayer(player), OnCommandVote, OnCommandUpdateVote)
			//end
			
		end
		
	end
	
	if mapvoterunning then

		if Shared.GetTime() > mapvotedelay then
			ProcessandSelectMap()
		elseif Shared.GetTime() > mapvotenotify then
		
			DAK:DisplayMessageToAllClients("VoteMapTimeLeft", mapvotedelay - Shared.GetTime())
			i = 1
			for map, votes in pairs(MapVotes) do
				DAK:DisplayMessageToAllClients("VoteMapCurrentMapVotes", votes, VotingMaps[map], i)	
				i = i + 1
			end
			mapvotenotify = Shared.GetTime() + DAK.config.mapvote.kVoteNotifyDelay
			
		end

	end

end

local function StartMapVote()

	if not mapvoterunning and not mapvoteintiated and not mapvotecomplete then
	
		mapvoteintiated = true
		mapvotedelay = Shared.GetTime() + DAK.config.mapvote.kVoteStartDelay
		DAK:DisplayMessageToAllClients("VoteMapBeginning", DAK.config.mapvote.kVoteStartDelay)
		DAK:DisplayMessageToAllClients("VoteMapHowToVote")
		DAK:RegisterEventHook("OnServerUpdate", UpdateMapVotes, 5)
		
	end
	
	return true
end

DAK:RegisterEventHook("OverrideMapChange", StartMapVote, 5)

local function MapVoteUpdatePregame(self, timePassed)

	if not DAK:GetTournamentMode() and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() and self:GetGameState() == kGameState.PreGame then
	
		local preGameTime = DAK.config.mapvote.kPregameLength
		if self.timeSinceGameStateChanged > preGameTime then
			StartCountdown(self)
			if Shared.GetCheatsEnabled() then
				self.countdownTime = 1
			end
		elseif pregamenotify + DAK.config.mapvote.kPregameNotifyDelay < Shared.GetTime() then
			DAK:DisplayMessageToAllClients("PregameNotification", (preGameTime - self.timeSinceGameStateChanged))
			pregamenotify = Shared.GetTime()
		end
		return true
		
	end

end

DAK:RegisterEventHook("OnUpdatePregame", MapVoteUpdatePregame, 5)

local function MapVoteSetGameState(self, state, currentstate)

	if state ~= currentstate and (state == kGameState.Team1Won or state == kGameState.Team2Won) then
		if MapCycle_TestCycleMap() then
			self.timeToCycleMap = Shared.GetTime() + DAK.config.mapvote.kRoundEndDelay
		end
	end
	
end

DAK:RegisterEventHook("OnSetGameState", MapVoteSetGameState, 5)

local function MapVoteCheckGameStart(self)

	if self:GetGameState() == kGameState.NotStarted or self:GetGameState() == kGameState.PreGame then
		if DAK.config.mapvote.kMaxGameNotStartedTime ~= 0 and self.gamenotstartedtime ~= nil and self.gamenotstartedtime + DAK.config.mapvote.kMaxGameNotStartedTime < Shared.GetTime() then
	
			local team1Players = self.team1:GetNumPlayers()
			local team2Players = self.team2:GetNumPlayers()
			
			if (team1Players > 0 and team2Players > 0) or (Shared.GetCheatsEnabled() and (team1Players > 0 or team2Players > 0)) then
			
				if self:GetGameState() == kGameState.NotStarted then
					self:SetGameState(kGameState.PreGame)
				end
				
			elseif self:GetGameState() == kGameState.PreGame then
				self:SetGameState(kGameState.NotStarted)
			end
			
			return true
		elseif self.gamenotstartedtime == nil then
			self.gamenotstartedtime = Shared.GetTime()
		end
	
	elseif self.gamenotstartedtime ~= nil then
		self.gamenotstartedtime = nil
	end
	
end

DAK:RegisterEventHook("CheckGameStart", MapVoteCheckGameStart, 5)

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
	
	if totalvotes >= math.ceil((playerRecords:GetSize() * (DAK.config.mapvote.kRTVMinimumPercentage / 100))) then
	
		StartMapVote()
		mapvoterocked = true
		RTVVotes = { }
		
	elseif not silent then
	
		DAK:DisplayMessageToAllClients("VoteMapRockTheVote", playername, totalvotes, math.ceil((playerRecords:GetSize() * (DAK.config.mapvote.kRTVMinimumPercentage / 100))))
		
	end

end

DAK:RegisterEventHook("OnClientDisconnect", UpdateRTV, 5)

local function OnCommandRTV(client)

	if client ~= nil then
	
		local player = client:GetControllingPlayer()
		if player ~= nil then
			if mapvoterunning or mapvoteintiated or mapvotecomplete then
				DAK:DisplayMessageToClient(client, "VoteMapAlreadyRunning")
				return
			end
			if RTVVotes[client:GetUserId()] ~= nil then			
				DAK:DisplayMessageToClient(client, "VoteMapAlreadyRTVd")
			else
				table.insert(RTVVotes,client:GetUserId())
				RTVVotes[client:GetUserId()] = true
				Shared.Message(string.format("%s rock'd the vote.", DAK:GetClientUIDString(client)))
				DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, string.format("%s rock'd the vote.", DAK:GetClientUIDString(client)))
				UpdateRTV(false, player:GetName())
			end
		end
		
	end
	
end

Event.Hook("Console_rtv",               OnCommandRTV)
Event.Hook("Console_rockthevote",               OnCommandRTV)

local function OnCommandTimeleft(client)

	if client ~= nil then
		DAK:DisplayMessageToClient(client, "VoteMapTimeRemaining", math.max(0,((MapCycle_GetMapCycleTime() * 60) - Shared.GetTime())/60))
	end
	
end

Event.Hook("Console_timeleft",               OnCommandTimeleft)

DAK:RegisterChatCommand(DAK.config.mapvote.kTimeleftChatCommands, OnCommandTimeleft, false)
DAK:RegisterChatCommand(DAK.config.mapvote.kRockTheVoteChatCommands, OnCommandRTV, false)
DAK:RegisterChatCommand(DAK.config.mapvote.kVoteChatCommands, OnCommandVote, true)

local function OnCommandStartMapVote(client)

	if mapvoterunning or mapvoteintiated or mapvotecomplete then
		if client ~= nil then
			DAK:DisplayMessageToClient(client, "VoteMapAlreadyRunning")
		else
			Shared.Message("Map vote already running")
		end
	
	else
	
		StartMapVote()
		DAK:PrintToAllAdmins("sv_votemap", client)
		
	end

end

DAK:CreateServerAdminCommand("Console_sv_votemap", OnCommandStartMapVote, "Will start a map vote.")

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
		
		DAK:DisplayMessageToAllClients("VoteMapCancelled")
		DAK:DeregisterEventHook("OnServerUpdate", UpdateMapVotes)
		DAK:PrintToAllAdmins("sv_cancelmapvote", client)
		
	elseif client ~= nil then
		DAK:DisplayMessageToClient(client, "VoteMapNotRunning")
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_cancelmapvote", CancelMapVote, "Will cancel a map vote.")