//NS2 Team Surrender Vote

if kDAKConfig and kDAKConfig.VoteSurrender then

	local kSurrenderVoteArray = { }
	local kSurrenderTeamCount = 2

	local function SetupSurrenderVars()
		for i = 1, kSurrenderTeamCount do
			local SurrenderVoteTeamArray = {VoteSurrenderRunning = 0, SurrenderVotes = { }, SurrenderVotesAlertTime = 0}
			table.insert(kSurrenderVoteArray, SurrenderVoteTeamArray)		
		end
	end
	
	SetupSurrenderVars()

	local function ValidateTeamNumber(teamnum)
		return teamnum == 1 or teamnum == 2
	end

	local function UpdateSurrenderVotes()
		local gamerules = GetGamerules()
		for i = 1, kSurrenderTeamCount do

			if kSurrenderVoteArray[i].VoteSurrenderRunning ~= 0 and gamerules ~= nil and gamerules:GetGameState() == kGameState.Started and kSurrenderVoteArray[i].SurrenderVotesAlertTime + kDAKConfig.VoteSurrender.kVoteSurrenderAlertDelay < Shared.GetTime() then
				local playerRecords =  GetEntitiesForTeam("Player", i)
				local totalvotes = 0
				for j = #kSurrenderVoteArray[i].SurrenderVotes, 1, -1 do
					local clientid = kSurrenderVoteArray[i].SurrenderVotes[j]
					local stillplaying = false
				
					for k = 1, #playerRecords do
						local player = playerRecords[k]
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
						table.remove(kSurrenderVoteArray[i].SurrenderVotes, j)
					end
				
				end
				if totalvotes >= math.ceil((#playerRecords * (kDAKConfig.VoteSurrender.kVoteSurrenderMinimumPercentage / 100))) then
			
					chatMessage = string.sub(string.format("Team %s has voted to surrender.", ToString(i)), 1, kMaxChatLength)
					Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					for i = 1, #playerRecords do
						if playerRecords[i] ~= nil then
							local gamerules = GetGamerules()
							if gamerules then
								gamerules:JoinTeam(playerRecords[i], kTeamReadyRoom)
							end
						end
					end
					
					kSurrenderVoteArray[i].SurrenderVotesAlertTime = 0
					kSurrenderVoteArray[i].VoteSurrenderRunning = 0
					kSurrenderVoteArray[i].SurrenderVotes = { }

				else
					local chatmessage
					if kSurrenderVoteArray[i].SurrenderVotesAlertTime == 0 then
						chatMessage = string.sub(string.format("A vote has started for your team to surrender. %s votes are needed.", 
						 math.ceil((#playerRecords * (kDAKConfig.VoteSurrender.kVoteSurrenderMinimumPercentage / 100))) ), 1, kMaxChatLength)
						kSurrenderVoteArray[i].SurrenderVotesAlertTime = Shared.GetTime()
					elseif kSurrenderVoteArray[i].VoteSurrenderRunning + kDAKConfig.VoteSurrender.kVoteSurrenderVotingTime < Shared.GetTime() then
						chatMessage = string.sub(string.format("The surrender vote for your team has expired."), 1, kMaxChatLength)
						kSurrenderVoteArray[i].SurrenderVotesAlertTime = 0
						kSurrenderVoteArray[i].VoteSurrenderRunning = 0
						kSurrenderVoteArray[i].SurrenderVotes = { }
					else
						chatMessage = string.sub(string.format("%s votes to surrender, %s needed, %s seconds left. type surrender to vote", totalvotes, 
						 math.ceil((#playerRecords * (kDAKConfig.VoteSurrender.kVoteSurrenderMinimumPercentage / 100))), 
						 math.ceil((kSurrenderVoteArray[i].VoteSurrenderRunning + kDAKConfig.VoteSurrender.kVoteSurrenderVotingTime) - Shared.GetTime()) ), 1, kMaxChatLength)
						kSurrenderVoteArray[i].SurrenderVotesAlertTime = Shared.GetTime()
					end
					for k = 1, #playerRecords do
						local player = playerRecords[k]
						if player ~= nil then
							Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "Team - " .. kDAKConfig.DAKLoader.MessageSender, -1, i, kNeutralTeamType, chatMessage), true)
						end
					end
				end
				
			end
			
		end
	end
	
	DAKRegisterEventHook(kDAKOnServerUpdate, function(deltatime) return UpdateSurrenderVotes() end, 5)
	
	local function ClearSurrenderVotes()
		for i = 1, kSurrenderTeamCount do
			kSurrenderVoteArray[i].SurrenderVotesAlertTime = 0
			kSurrenderVoteArray[i].VoteSurrenderRunning = 0
			kSurrenderVoteArray[i].SurrenderVotes = { }
		end
	end
		
	table.insert(kDAKOnGameEnd, function(winningTeam) return ClearSurrenderVotes() end)

	local function OnCommandVoteSurrender(client)
	
		if client ~= nil then
			local player = client:GetControllingPlayer()
			local gamerules = GetGamerules()
			local clientID = client:GetUserId()
			if player ~= nil and clientID ~= nil and gamerules ~= nil and gamerules:GetGameState() == kGameState.Started then
				local teamnumber = player:GetTeamNumber()
				if teamnumber and ValidateTeamNumber(teamnumber) then
					if kSurrenderVoteArray[teamnumber].VoteSurrenderRunning ~= 0 then
						local alreadyvoted = false
						for i = #kSurrenderVoteArray[teamnumber].SurrenderVotes, 1, -1 do
							if kSurrenderVoteArray[teamnumber].SurrenderVotes[i] == clientID then
								alreadyvoted = true
								break
							end
						end
						if alreadyvoted then
							chatMessage = string.sub(string.format("You already voted for to surrender."), 1, kMaxChatLength)
							Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
						else
							chatMessage = string.sub(string.format("You have voted to surrender."), 1, kMaxChatLength)
							Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
							table.insert(kSurrenderVoteArray[teamnumber].SurrenderVotes, clientID)
						end						
					else
						chatMessage = string.sub(string.format("You have voted to surrender."), 1, kMaxChatLength)
						Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
						kSurrenderVoteArray[teamnumber].VoteSurrenderRunning = Shared.GetTime()
						table.insert(kSurrenderVoteArray[teamnumber].SurrenderVotes, clientID)
					end
				end
			end
		end
		
	end

	Event.Hook("Console_surrender",               OnCommandVoteSurrender)
	
	local function OnVoteSurrenderChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
	
		if client and steamId and steamId ~= 0 then
			for c = 1, #kDAKConfig.VoteSurrender.kSurrenderChatCommands do
				local chatcommand = kDAKConfig.VoteSurrender.kSurrenderChatCommands[c]
				if message == chatcommand then
					OnCommandVoteSurrender(client)
				end
			end
		end
	
	end
	
	table.insert(kDAKOnClientChatMessage, function(message, playerName, steamId, teamNumber, teamOnly, client) return OnVoteSurrenderChatMessage(message, playerName, steamId, teamNumber, teamOnly, client) end)

	local function VoteSurrenderOff(client, teamnum)
		local tmNum = tonumber(teamnum)
		if tmNum ~= nil and ValidateTeamNumber(tmNum) and kVoteSurrenderRunning[tmNum] ~= 0 then
			kSurrenderVoteArray[tmNum].SurrenderVotesAlertTime = 0
			kSurrenderVoteArray[tmNum].VoteSurrenderRunning = 0
			kSurrenderVoteArray[tmNum].SurrenderVotes = { }
			chatMessage = string.sub(string.format("Surrender vote for team %s has been cancelled.", tmNum), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, tmNum, kNeutralTeamType, chatMessage), true)
			if client ~= nil then 
				ServerAdminPrint(client, string.format("Surrender vote cancelled for team %s.", ToString(tmNum)))
				local player = client:GetControllingPlayer()
				if player ~= nil then
					PrintToAllAdmins("sv_cancelsurrendervote", client, teamnum)
				end
			end
		end

	end

	DAKCreateServerAdminCommand("Console_sv_cancelsurrendervote", VoteSurrenderOff, "<teamnumber> Cancelles a currently running surrender vote for the provided team.")

	local function VoteSurrenderOn(client, teamnum)
		local tmNum = tonumber(teamnum)
		if tmNum ~= nil and ValidateTeamNumber(tmNum) and kVoteSurrenderRunning[tmNum] == 0 then
			kSurrenderVoteArray[tmNum].VoteSurrenderRunning = Shared.GetTime()
			if client ~= nil then
				ServerAdminPrint(client, string.format("Surrender vote started for team %s.", ToString(tmNum)))
				local player = client:GetControllingPlayer()
				if player ~= nil then
					PrintToAllAdmins("sv_surrendervote", client, teamnum)
				end			
			end
		end

	end

	DAKCreateServerAdminCommand("Console_sv_surrendervote", VoteSurrenderOn, "<teamnumber> Will start a surrender vote for that team.")

end

Shared.Message("VoteSurrender Loading Complete")