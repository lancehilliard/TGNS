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
			Shared.Message("NOT winOrLoseChallengeIsInProgress")
		end

		if canAttack then
			Shared.Message("Can Attack")
		else
			Shared.Message("Can NOT Attack")
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
		if Shared.GetTime() - kTimeAtWhichWinOrLoseVoteSucceeded > DAK.config.winorlose.kWinOrLoseNoAttackDuration then
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, "WinOrLose! On to the next game!"), true)
			local commandStructures = GetEntitiesForTeam("CommandStructure", kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber() == kMarineTeamType and kAlienTeamType or kMarineTeamType)
			TGNS.DoFor(commandStructures, function(s) DestroyEntity(s) end)
			kTimeAtWhichWinOrLoseVoteSucceeded = 0
		else
			if (math.fmod(kCountdownTimeRemaining, DAK.config.winorlose.kWinOrLoseWarningInterval) == 0 or kCountdownTimeRemaining <= 5) then
				local teamDescription = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber() == kMarineTeamType and "Marine" or "Alien"
				chatMessage = string.sub(string.format("WinOrLose! %s units cannot attack. Game ends in %s seconds. Hurry!", teamDescription, kCountdownTimeRemaining), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			end
			kCountdownTimeRemaining = kCountdownTimeRemaining - 1
		end
	else
		for i = 1, kWinOrLoseTeamCount do

			if kWinOrLoseVoteArray[i].WinOrLoseRunning ~= 0 and gamerules ~= nil and gamerules:GetGameState() == kGameState.Started and kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime + DAK.config.winorlose.kWinOrLoseAlertDelay < Shared.GetTime() then
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
				if totalvotes >= math.ceil((#playerRecords * (DAK.config.winorlose.kWinOrLoseMinimumPercentage / 100))) then
					local teamDescription = i == kMarineTeamType and "Marine" or "Alien"
					chatMessage = string.sub(string.format("WinOrLose! %s player units can't attack! End it in %s seconds, or THEY WIN!", teamDescription, DAK.config.winorlose.kWinOrLoseNoAttackDuration), 1, kMaxChatLength)
					Server.SendNetworkMessage("Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					for i = 1, #playerRecords do
						if playerRecords[i] ~= nil then
							kTimeAtWhichWinOrLoseVoteSucceeded = Shared.GetTime()
							kTeamWhichWillWinIfWinLoseCountdownExpires = playerRecords[i]:GetTeam()
							kCountdownTimeRemaining = DAK.config.winorlose.kWinOrLoseNoAttackDuration
							break
						end
					end
					
					kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
					kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
					kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
				else
					local chatmessage
					if kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime == 0 then
						chatMessage = string.sub(string.format("Concede vote started. %s votes are needed.", 
						 math.ceil((#playerRecords * (DAK.config.winorlose.kWinOrLoseMinimumPercentage / 100))) ), 1, kMaxChatLength)
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = Shared.GetTime()
					elseif kWinOrLoseVoteArray[i].WinOrLoseRunning + DAK.config.winorlose.kWinOrLoseVotingTime < Shared.GetTime() then
						local abstainedNames = {}
						TGNS.DoFor(playerRecords, function(p)
							local playerSteamId = TGNS.ClientAction(p, TGNS.GetClientSteamId)
							if not TGNS.Has(kWinOrLoseVoteArray[i].WinOrLoseVotes, playerSteamId) then
								table.insert(abstainedNames, TGNS.GetPlayerName(p))
							end
						end)
						chatMessage = string.sub(string.format("Concede vote expired. Abstained: %s", TGNS.Join(abstainedNames, ", ")), 1, kMaxChatLength)
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
						kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
						kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
					else
						chatMessage = string.sub(string.format("%s votes to concede; %s needed; %s seconds left.", totalvotes, 
						 math.ceil((#playerRecords * (DAK.config.winorlose.kWinOrLoseMinimumPercentage / 100))), 
						 math.ceil((kWinOrLoseVoteArray[i].WinOrLoseRunning + DAK.config.winorlose.kWinOrLoseVotingTime) - Shared.GetTime()) ), 1, kMaxChatLength)
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = Shared.GetTime()
					end
					for k = 1, #playerRecords do
						local player = playerRecords[k]
						if player ~= nil then
							Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "Team - " .. DAK.config.language.MessageSender, -1, i, kNeutralTeamType, chatMessage), true)
						end
					end
				end
				
			end
			
		end
	end
end

TGNS.RegisterEventHook("OnServerUpdate", function(deltatime) return UpdateWinOrLoseVotes() end)

local function ClearWinOrLoseVotes()
	for i = 1, kWinOrLoseTeamCount do
		kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
		kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
		kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
	end
	kTimeAtWhichWinOrLoseVoteSucceeded = 0
end
TGNS.RegisterEventHook("OnGameEnd", ClearWinOrLoseVotes)

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
							chatMessage = string.sub(string.format("You already voted to concede."), 1, kMaxChatLength)
							Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
						else
							TGNS.SendTeamChat(TGNS.GetPlayerTeamNumber(player), string.format("%s voted to concede. Press X to Vote.", TGNS.GetPlayerName(player)))
							chatMessage = string.sub(string.format("You have voted to concede."), 1, kMaxChatLength)
							//Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
							table.insert(kWinOrLoseVoteArray[teamnumber].WinOrLoseVotes, clientID)
						end						
					else
						TGNS.SendTeamChat(TGNS.GetPlayerTeamNumber(player), string.format("%s started a concede vote. Press X to Vote.", TGNS.GetPlayerName(player)))
						chatMessage = string.sub(string.format("You have voted to concede."), 1, kMaxChatLength)
						//Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
						kWinOrLoseVoteArray[teamnumber].WinOrLoseRunning = Shared.GetTime()
						table.insert(kWinOrLoseVoteArray[teamnumber].WinOrLoseVotes, clientID)
					end
				end
			end
		else
			chatMessage = string.sub(string.format("You may concede only when you have a single command structure."), 1, kMaxChatLength)
			Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
		end
	end
	
end
Event.Hook("Console_winorlose", OnCommandWinOrLose)

local function WinOrLoseOnCastVoteByPlayer(self, voteTechId, player)
	local cancel = false
	if voteTechId == kTechId.VoteConcedeRound then
		cancel = true
		TGNS.ClientAction(player, function(c) OnCommandWinOrLose(c) end)
	end
	return cancel
end
TGNS.RegisterEventHook("OnCastVoteByPlayer", WinOrLoseOnCastVoteByPlayer)

local function onChatClient(client, networkMessage)
	local teamOnly = networkMessage.teamOnly
	local message = StringTrim(networkMessage.message)
	for c = 1, #DAK.config.winorlose.kWinOrLoseChatCommands do
		local chatcommand = DAK.config.winorlose.kWinOrLoseChatCommands[c]
		if message == chatcommand and not teamOnly then
			TGNS.PlayerAction(client, function(p)
					TGNS.SendChatMessage(p, "Use the Vote Concede menu (or team chat) to concede. No vote has been cast.")
				end
			)
			return true
		end
	end
end
TGNS.RegisterNetworkMessageHook("ChatClient", onChatClient, 5)