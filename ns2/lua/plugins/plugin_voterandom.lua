//NS2 Vote Random Teams

local kVoteRandomTeamsEnabled = false
local RandomNewRoundDelay = 15
local RandomVotes = { }
local RandomDuration = 0
local RandomRoundRecentlyEnded = 0

local function LoadVoteRandom()

	if kDAKSettings.RandomEnabledTill == nil then
		kDAKSettings.RandomEnabledTill = 0
	end
	if kDAKSettings.RandomEnabledTill > Shared.GetSystemTime() or kDAKConfig.VoteRandom.kVoteRandomAlwaysEnabled then
		kVoteRandomTeamsEnabled = not kDAKConfig.VoteRandom.kVoteRandomInstantly or kDAKConfig.VoteRandom.kVoteRandomAlwaysEnabled
		Shared.Message(string.format("RandomTeams set to %s", ToString(kVoteRandomTeamsEnabled)))
		EnhancedLog(string.format("RandomTeams set to %s", ToString(kVoteRandomTeamsEnabled)))
	else
		kVoteRandomTeamsEnabled = false
	end
	
end

LoadVoteRandom()

local function ShuffleTeams()
	local playerList = ShufflePlayerList()
	
	for i = 1, (#playerList) do
		local teamnum = math.fmod(i,2) + 1
		local client = Server.GetOwner(playerList[i])
		if client ~= nil then
			//Trying just making team decision based on position in array.. two randoms seems to somehow result in similar teams..
			local gamerules = GetGamerules()
			if gamerules and not DAKGetClientCanRunCommand(client, "sv_dontrandom") then
				if not gamerules:GetCanJoinTeamNumber(teamnum) and gamerules:GetCanJoinTeamNumber(math.fmod(teamnum,2) + 1) then
					teamnum = math.fmod(teamnum,2) + 1						
				end
				gamerules:JoinTeam(playerList[i], teamnum)
			end
		end
	end
end

local function RandomTeams()

	if kVoteRandomTeamsEnabled then
	
		if kDAKSettings.RandomEnabledTill > Shared.GetSystemTime() or kDAKConfig.VoteRandom.kVoteRandomAlwaysEnabled then
			kVoteRandomTeamsEnabled = not kDAKConfig.VoteRandom.kVoteRandomInstantly or kDAKConfig.VoteRandom.kVoteRandomAlwaysEnabled 
		else
			kVoteRandomTeamsEnabled = false
		end
		if RandomRoundRecentlyEnded + RandomNewRoundDelay < Shared.GetTime() and not kDAKConfig.VoteRandom.kVoteRandomOnGameStart then
			ShuffleTeams()
			RandomRoundRecentlyEnded = 0
		end
		
	end
	
	if not kVoteRandomTeamsEnabled then
		DAKDeregisterEventHook("kDAKOnServerUpdate", RandomTeams)
	end
	
end

DAKRegisterEventHook("kDAKOnServerUpdate", RandomTeams, 5)

local function VoteRandomSetGameState(self, state, currentstate)

	if state ~= currentstate and state == kGameState.Started and kDAKConfig.VoteRandom.kVoteRandomOnGameStart then
		ShuffleTeams()
	end
	
end

DAKRegisterEventHook("kDAKOnSetGameState", VoteRandomSetGameState, 5)

local function UpdateRandomVotes(silent, playername)

	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	local totalvotes = 0
	
	for i = #RandomVotes, 1, -1 do
		local clientid = RandomVotes[i]
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
			table.remove(RandomVotes, i)
		end
	
	end
	
	if totalvotes >= math.ceil((playerRecords:GetSize() * (kDAKConfig.VoteRandom.kVoteRandomMinimumPercentage / 100))) then
	
		RandomVotes = { }
		
		if kDAKConfig.VoteRandom.kVoteRandomInstantly then
			DAKDisplayMessageToAllClients("kVoteRandomEnabled")
			if Server then
				Shared.ConsoleCommand("sv_rrall")
				Shared.ConsoleCommand("sv_reset")
				ShuffleTeams()
			end
		else
			DAKDisplayMessageToAllClients("kVoteRandomEnabledDuration", kDAKConfig.VoteRandom.kVoteRandomDuration)
			kDAKSettings.RandomEnabledTill = Shared.GetSystemTime() + (kDAKConfig.VoteRandom.kVoteRandomDuration * 60)
			SaveDAKSettings()
			kVoteRandomTeamsEnabled = true
			DAKRegisterEventHook("kDAKOnServerUpdate", RandomTeams, 5)
		end
		
	elseif not silent then
	
		DAKDisplayMessageToAllClients("kVoteRandomVoteCountAlert", playername, totalvotes, math.ceil((playerRecords:GetSize() * (kDAKConfig.VoteRandom.kVoteRandomMinimumPercentage / 100))))
		
	end
	
end

DAKRegisterEventHook("kDAKOnClientDisconnect", UpdateRandomVotes, 5)

local function VoteRandomClientConnect(client)

	if client ~= nil and kVoteRandomTeamsEnabled then
		local player = client:GetControllingPlayer()
		if player ~= nil then
			DAKDisplayMessageToClient(client, "kVoteRandomConnectAlert")
			JoinRandomTeam(player)
		end
	end
	
end

DAKRegisterEventHook("kDAKOnClientDelayedConnect", VoteRandomClientConnect, 5)

local function VoteRandomJoinTeam(self, player, newTeamNumber, force)
	if RandomRoundRecentlyEnded + RandomNewRoundDelay > Shared.GetTime() and (newTeamNumber == 1 or newTeamNumber == 2) and not kDAKConfig.VoteRandom.kVoteRandomOnGameStart then
		DAKDisplayMessageToClient(Server.GetOwner(player), "kVoteRandomTeamJoinBlock")
		return true
	end
end

DAKRegisterEventHook("kDAKOnTeamJoin", VoteRandomJoinTeam, 5)

local function VoteRandomEndGame(self, winningTeam)
	if kVoteRandomTeamsEnabled then
		RandomRoundRecentlyEnded = Shared.GetTime()
	end
end

DAKRegisterEventHook("kDAKOnGameEnd", VoteRandomEndGame, 5)

local function OnCommandVoteRandom(client)

	if client ~= nil then
	
		local player = client:GetControllingPlayer()
		if player ~= nil then
			if kVoteRandomTeamsEnabled then
				DAKDisplayMessageToClient(client, "kVoteRandomAlreadyEnabled")
				return
			end
			if RandomVotes[client:GetUserId()] ~= nil then			
				DAKDisplayMessageToClient(client, "kVoteRandomAlreadyVoted")
			else
				table.insert(RandomVotes,client:GetUserId())
				RandomVotes[client:GetUserId()] = true
				Shared.Message(string.format("%s voted for random teams.", client:GetUserId()))
				EnhancedLog(string.format("%s voted for random teams.", client:GetUserId()))
				UpdateRandomVotes(false, player:GetName())
			end
		end
		
	end
	
end

Event.Hook("Console_voterandom",               OnCommandVoteRandom)
Event.Hook("Console_random",               OnCommandVoteRandom)

local function OnVoteRandomChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)

	if client and steamId and steamId ~= 0 then
		for c = 1, #kDAKConfig.VoteRandom.kVoteRandomChatCommands do
			local chatcommand = kDAKConfig.VoteRandom.kVoteRandomChatCommands[c]
			if string.upper(message) == string.upper(chatcommand) then
				OnCommandVoteRandom(client)
			end
		end
	end

end

DAKRegisterEventHook("kDAKOnClientChatMessage", OnVoteRandomChatMessage, 5)

local function VoteRandomOff(client)

	if kVoteRandomTeamsEnabled then
	
		kVoteRandomTeamsEnabled = false
		kDAKSettings.RandomEnabledTill = 0
		SaveDAKSettings()
		DAKDisplayMessageToAllClients("kVoteRandomDisabled")
		if client ~= nil then 
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_randomoff", client)
			end
		end
	end

end

DAKCreateServerAdminCommand("Console_sv_randomoff", VoteRandomOff, "Turns off any currently active random teams vote.")

local function VoteRandomOn(client)

	if not kVoteRandomTeamsEnabled then
		
		if kDAKConfig.VoteRandom.kVoteRandomInstantly then
			DAKDisplayMessageToAllClients("kVoteRandomEnabled")
			if Server then
				Shared.ConsoleCommand("sv_rrall")
				Shared.ConsoleCommand("sv_reset")
				ShuffleTeams()
			end
		else
			DAKDisplayMessageToAllClients("kVoteRandomEnabledDuration", kDAKConfig.VoteRandom.kVoteRandomDuration)
			kDAKSettings.RandomEnabledTill = Shared.GetSystemTime() + (kDAKConfig.VoteRandom.kVoteRandomDuration * 60)
			SaveDAKSettings()
			kVoteRandomTeamsEnabled = true
			DAKRegisterEventHook("kDAKOnServerUpdate", RandomTeams, 5)
		end
		if client ~= nil then 
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_randomon", client)
			end
		end
	end

end

DAKCreateServerAdminCommand("Console_sv_randomon", VoteRandomOn, "Will enable random teams.")