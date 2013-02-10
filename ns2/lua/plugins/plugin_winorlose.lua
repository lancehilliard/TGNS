//Win Or Lose (mostly copied from VoteSurrender)

if kDAKConfig and kDAKConfig.WinOrLose then
	Script.Load("lua/TGNSCommon.lua")

	local kWinOrLoseVoteArray = { }
	local kWinOrLoseTeamCount = 2
	local kTimeAtWhichWinOrLoseVoteSucceeded = 0
	local kTeamWhichWillWinIfWinLoseCountdownExpires = nil
	local kCountdownTimeRemaining = 0

	local originalGetCanAttack
	
	originalGetCanAttack = Class_ReplaceMethod("Player", "GetCanAttack",
		function(self)
			local winOrLoseChallengeIsInProgressByMyTeam = kTimeAtWhichWinOrLoseVoteSucceeded > 0 and self:GetTeam() == kTeamWhichWillWinIfWinLoseCountdownExpires
			local canAttack = originalGetCanAttack(self) and not winOrLoseChallengeIsInProgressByMyTeam
			
			/*
			if winOrLoseChallengeIsInProgress then
				Shared.Message("winOrLoseChallengeIsInProgress")
			else
				Shared.Message("NOT winOrLoseChallengeIsInProgress");
			end

			if canAttack then
				Shared.Message("Can Attack")
			else
				Shared.Message("Can NOT Attack");
			end
			*/
			
			return canAttack
		end
	)
	
	local function SetupWinOrLoseVars()
		for i = 1, kWinOrLoseTeamCount do
			local WinOrLoseVoteTeamArray = {WinOrLoseRunning = 0, WinOrLoseVotes = { }, WinOrLoseVotesAlertTime = 0}
			table.insert(kWinOrLoseVoteArray, WinOrLoseVoteTeamArray)		
		end
	end
	
	SetupWinOrLoseVars()

	local function ValidateTeamNumber(teamnum)
		return teamnum == 1 or teamnum == 2
	end

	local function UpdateWinOrLoseVotes()
		local gamerules = GetGamerules()
		if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
			if Shared.GetTime() - kTimeAtWhichWinOrLoseVoteSucceeded > kDAKConfig.WinOrLose.kWinOrLoseNoAttackDuration then
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, "WinOrLose! On to the next game!"), true)
				local commandStructures = GetEntitiesForTeam("CommandStructure", kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber() == kMarineTeamType and kAlienTeamType or kMarineTeamType)
				TGNS.DoFor(commandStructures, function(s) DestroyEntity(s) end)
				kTimeAtWhichWinOrLoseVoteSucceeded = 0
			else
				if (math.fmod(kCountdownTimeRemaining, kDAKConfig.WinOrLose.kWinOrLoseWarningInterval) == 0 or kCountdownTimeRemaining <= 5) then
					local teamDescription = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber() == kMarineTeamType and "Marine" or "Alien"
					chatMessage = string.sub(string.format("WinOrLose! The %s team is %s seconds away from winning by default!", teamDescription, kCountdownTimeRemaining), 1, kMaxChatLength)
					Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
				kCountdownTimeRemaining = kCountdownTimeRemaining - 1
			end
		else
			for i = 1, kWinOrLoseTeamCount do

				if kWinOrLoseVoteArray[i].WinOrLoseRunning ~= 0 and gamerules ~= nil and gamerules:GetGameState() == kGameState.Started and kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime + kDAKConfig.WinOrLose.kWinOrLoseAlertDelay < Shared.GetTime() then
					local playerRecords = TGNS.GetPlayers(TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return p:GetTeamNumber() == i end)) // GetEntitiesForTeam("Player", i)
					local totalvotes = 0
					for j = #kWinOrLoseVoteArray[i].WinOrLoseVotes, 1, -1 do
						local clientid = kWinOrLoseVoteArray[i].WinOrLoseVotes[j]
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
							table.remove(kWinOrLoseVoteArray[i].WinOrLoseVotes, j)
						end
					
					end
					if totalvotes >= math.ceil((#playerRecords * (kDAKConfig.WinOrLose.kWinOrLoseMinimumPercentage / 100))) then
						local teamDescription = i == kMarineTeamType and "Marine" or "Alien"
						chatMessage = string.sub(string.format("WinOrLose! %s player units can't attack! End it in %s seconds, or THEY WIN!", teamDescription, kDAKConfig.WinOrLose.kWinOrLoseNoAttackDuration), 1, kMaxChatLength)
						Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
						for i = 1, #playerRecords do
							if playerRecords[i] ~= nil then
								kTimeAtWhichWinOrLoseVoteSucceeded = Shared.GetTime()
								kTeamWhichWillWinIfWinLoseCountdownExpires = playerRecords[i]:GetTeam()
								kCountdownTimeRemaining = kDAKConfig.WinOrLose.kWinOrLoseNoAttackDuration
								break
							end
						end
						
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
						kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
						kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
					else
						local chatmessage
						if kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime == 0 then
							chatMessage = string.sub(string.format("WinOrLose vote started. %s votes are needed.", 
							 math.ceil((#playerRecords * (kDAKConfig.WinOrLose.kWinOrLoseMinimumPercentage / 100))) ), 1, kMaxChatLength)
							kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = Shared.GetTime()
						elseif kWinOrLoseVoteArray[i].WinOrLoseRunning + kDAKConfig.WinOrLose.kWinOrLoseVotingTime < Shared.GetTime() then
							local abstainedNames = {}
							TGNS.DoFor(playerRecords, function(p)
								local playerSteamId = TGNS.ClientAction(p, TGNS.GetClientSteamId)
								if not TGNS.Has(kWinOrLoseVoteArray[i].WinOrLoseVotes, playerSteamId) then
									table.insert(abstainedNames, TGNS.GetPlayerName(p))
								end
							end)
							chatMessage = string.sub(string.format("WinOrLose vote expired. Abstained: %s", TGNS.Join(abstainedNames, ", ")), 1, kMaxChatLength)
							kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
							kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
							kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
						else
							chatMessage = string.sub(string.format("%s votes to call WinOrLose, %s needed, %s seconds left.", totalvotes, 
							 math.ceil((#playerRecords * (kDAKConfig.WinOrLose.kWinOrLoseMinimumPercentage / 100))), 
							 math.ceil((kWinOrLoseVoteArray[i].WinOrLoseRunning + kDAKConfig.WinOrLose.kWinOrLoseVotingTime) - Shared.GetTime()) ), 1, kMaxChatLength)
							kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = Shared.GetTime()
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
	end
	
	DAKRegisterEventHook("kDAKOnServerUpdate", function(deltatime) return UpdateWinOrLoseVotes() end, 5)
	
	local function ClearWinOrLoseVotes()
		for i = 1, kWinOrLoseTeamCount do
			kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
			kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
			kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
		end
		kTimeAtWhichWinOrLoseVoteSucceeded = 0
	end
	DAKRegisterEventHook("kDAKOnGameEnd", ClearWinOrLoseVotes, 5)

	local function OnCommandWinOrLose(client)
	
		local gamerules = GetGamerules()
		if gamerules ~= nil and client ~= nil and gamerules:GetGameState() == kGameState.Started then
			local player = client:GetControllingPlayer()
			if player:GetTeam():GetNumCommandStructures() == 1 then
				local clientID = client:GetUserId()
				if player ~= nil and clientID ~= nil then
					local teamnumber = player:GetTeamNumber()
					if teamnumber and ValidateTeamNumber(teamnumber) then
						if kWinOrLoseVoteArray[teamnumber].WinOrLoseRunning ~= 0 then
							local alreadyvoted = false
							for i = #kWinOrLoseVoteArray[teamnumber].WinOrLoseVotes, 1, -1 do
								if kWinOrLoseVoteArray[teamnumber].WinOrLoseVotes[i] == clientID then
									alreadyvoted = true
									break
								end
							end
							if alreadyvoted then
								chatMessage = string.sub(string.format("You already voted to call WinOrLose."), 1, kMaxChatLength)
								Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
							else
								chatMessage = string.sub(string.format("You have voted to call WinOrLose."), 1, kMaxChatLength)
								//Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
								table.insert(kWinOrLoseVoteArray[teamnumber].WinOrLoseVotes, clientID)
							end						
						else
							chatMessage = string.sub(string.format("You have voted to call WinOrLose."), 1, kMaxChatLength)
							//Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
							kWinOrLoseVoteArray[teamnumber].WinOrLoseRunning = Shared.GetTime()
							table.insert(kWinOrLoseVoteArray[teamnumber].WinOrLoseVotes, clientID)
						end
					end
				end
			else
				chatMessage = string.sub(string.format("You may call WinOrLose only when you have a single command structure."), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			end
		end
		
	end
	Event.Hook("Console_winorlose", OnCommandWinOrLose)

	local function WinOrLoseOnCastVoteByPlayer(self, voteTechId, player)
		local cancel = false
		if voteTechId == kTechId.VoteConcedeRound then
			cancel = true
			TGNS.SendTeamChat(TGNS.GetPlayerTeamNumber(player), string.format("%s voted for WinOrLose using the Vote Concede menu.", TGNS.GetPlayerName(player)))
			TGNS.ClientAction(player, function(c) OnCommandWinOrLose(c) end)
		end
		return cancel
	end
	DAKRegisterEventHook("kDAKOnCastVoteByPlayer", WinOrLoseOnCastVoteByPlayer, 5)

	local function onChatClient(client, networkMessage)
		local teamOnly = networkMessage.teamOnly
		local message = StringTrim(networkMessage.message)
		for c = 1, #kDAKConfig.WinOrLose.kWinOrLoseChatCommands do
			local chatcommand = kDAKConfig.WinOrLose.kWinOrLoseChatCommands[c]
			if message == chatcommand and not teamOnly then
				TGNS.PlayerAction(client, function(p)
						TGNS.SendChatMessage(p, "WinOrLose must be used via team chat. No vote has been cast.")
					end
				)
				return true
			end
		end
	end

	TGNS.RegisterNetworkMessageHook("ChatClient", onChatClient, 5)

	//local function WinOrLoseOff(client, teamnum)
	//	local tmNum = tonumber(teamnum)
	//	if tmNum ~= nil and ValidateTeamNumber(tmNum) and kWinOrLoseRunning[tmNum] ~= 0 then
	//		kSurrenderVoteArray[tmNum].SurrenderVotesAlertTime = 0
	//		kSurrenderVoteArray[tmNum].WinOrLoseRunning = 0
	//		kSurrenderVoteArray[tmNum].SurrenderVotes = { }
	//		chatMessage = string.sub(string.format("Surrender vote for team %s has been cancelled.", tmNum), 1, kMaxChatLength)
	//		Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, tmNum, kNeutralTeamType, chatMessage), true)
	//		if client ~= nil then 
	//			ServerAdminPrint(client, string.format("Surrender vote cancelled for team %s.", ToString(tmNum)))
	//			local player = client:GetControllingPlayer()
	//			if player ~= nil then
	//				PrintToAllAdmins("sv_cancelsurrendervote", client, teamnum)
	//			end
	//		end
	//	end
    //
	//end
    //
	//DAKCreateServerAdminCommand("Console_sv_cancelsurrendervote", WinOrLoseOff, "<teamnumber> Cancelles a currently running surrender vote for the provided team.")

	local function WinOrLoseOn(client)
		local player = client:GetControllingPlayer()
		local tmNum = player:GetTeam()
		if tmNum ~= nil and ValidateTeamNumber(tmNum) and kWinOrLoseRunning[tmNum] == 0 then
			kWinOrLoseVoteArray[tmNum].WinOrLoseRunning = Shared.GetTime()
			if client ~= nil then
				ServerAdminPrint(client, string.format("WinOrLose vote started for team %s.", ToString(tmNum)))
				if player ~= nil then
					PrintToAllAdmins("sv_winorlose", client, teamnum)
				end			
			end
		end

	end

	DAKCreateServerAdminCommand("Console_sv_winorlose", WinOrLoseOn, "Begins a vote to call WinOrLose on the other team.")
end

Shared.Message("WinOrLose Loading Complete")