//NS2 Vote Random Teams

if kDAKConfig and kDAKConfig.VoteRandom then

	local kVoteRandomTeamsEnabled = false
	local RandomNewRoundDelay = 15
	local RandomVotes = { }
	local RandomDuration = 0
	local RandomRoundRecentlyEnded = nil

	local function LoadVoteRandom()

		if kDAKSettings.RandomEnabledTill ~= nil then
			if kDAKSettings.RandomEnabledTill > Shared.GetSystemTime() then
				kVoteRandomTeamsEnabled = not kDAKConfig.VoteRandom.kVoteRandomInstantly
				Shared.Message(string.format("RandomTeams set to %s", ToString(kVoteRandomTeamsEnabled)))
				EnhancedLog(string.format("RandomTeams set to %s", ToString(kVoteRandomTeamsEnabled)))
			else
				kVoteRandomTeamsEnabled = false
			end
		else
			kDAKSettings.RandomEnabledTill = 0
		end
	end

	LoadVoteRandom()
	
	local function ShuffleTeams(ShuffleAllPlayers)
		local playerList = ShufflePlayerList()
		
		for i = 1, (#playerList) do
			if ShuffleAllPlayers or playerList[i]:GetTeamNumber() == 0 then
				local teamnum = math.fmod(i,2) + 1
				local client = Server.GetOwner(playerList[i])
				if client ~= nil then
					//Trying just making team decision based on position in array.. two randoms seems to somehow result in similar teams..
					local gamerules = GetGamerules()
					if gamerules and not DAKGetClientCanRunCommand(client, "sv_dontrandom") then
						gamerules:JoinTeam(playerList[i], teamnum)
					end
				end
			end
		end
	end	

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
					ShuffleTeams(true)
				end
			else
				DAKDisplayMessageToAllClients("kVoteRandomEnabledDuration", kDAKConfig.VoteRandom.kVoteRandomDuration)
				kDAKSettings.RandomEnabledTill = Shared.GetSystemTime() + (kDAKConfig.VoteRandom.kVoteRandomDuration * 60)
				SaveDAKSettings()
				kVoteRandomTeamsEnabled = true
			end
			
		elseif not silent then
		
			DAKDisplayMessageToAllClients("kVoteRandomVoteCountAlert", playername, totalvotes, math.ceil((playerRecords:GetSize() * (kDAKConfig.VoteRandom.kVoteRandomMinimumPercentage / 100))))
			
		end
		
	end
	
	DAKRegisterEventHook(kDAKOnClientDisconnect, UpdateRandomVotes, 5)

	local function VoteRandomClientConnect(client)

		if client ~= nil and kVoteRandomTeamsEnabled then
			local player = client:GetControllingPlayer()
			if player ~= nil then
				DAKDisplayMessageToClient(client, "kVoteRandomConnectAlert")
				JoinRandomTeam(player)
			end
		end
		
	end
	
	DAKRegisterEventHook(kDAKOnClientDelayedConnect, VoteRandomClientConnect, 5)

	local function VoteRandomJoinTeam(self, player, newTeamNumber, force)
		if RandomRoundRecentlyEnded ~= nil and RandomRoundRecentlyEnded + RandomNewRoundDelay > Shared.GetTime() and (newTeamNumber == 1 or newTeamNumber == 2) then
			DAKDisplayMessageToClient(Server.GetOwner(player), "kVoteRandomTeamJoinBlock")
			return true
		end
	end
	
	DAKRegisterEventHook(kDAKOnTeamJoin, VoteRandomJoinTeam, 5)
	
	local function VoteRandomEndGame(self, winningTeam)
		if kVoteRandomTeamsEnabled then
			RandomRoundRecentlyEnded = Shared.GetTime()
		end
	end
	
	DAKRegisterEventHook(kDAKOnGameEnd, VoteRandomEndGame, 5)
	
	local function RandomTeams()

		PROFILE("VoteRandom:RandomTeams")
		
		if kVoteRandomTeamsEnabled then
		
			if kDAKSettings.RandomEnabledTill > Shared.GetSystemTime() then
				kVoteRandomTeamsEnabled = not kDAKConfig.VoteRandom.kVoteRandomInstantly
			else
				kVoteRandomTeamsEnabled = false
			end
			if RandomRoundRecentlyEnded ~= nil and RandomRoundRecentlyEnded + RandomNewRoundDelay < Shared.GetTime() then
				ShuffleTeams(false)
				RandomRoundRecentlyEnded = nil
			end
			
		end
		
	end

	DAKRegisterEventHook(kDAKOnServerUpdate, RandomTeams, 5)

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
				if message == chatcommand then
					OnCommandVoteRandom(client)
				end
			end
		end
	
	end
	
	DAKRegisterEventHook(kDAKOnClientChatMessage, OnVoteRandomChatMessage, 5)

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

		if kVoteRandomTeamsEnabled == false then
			
			if kDAKConfig.VoteRandom.kVoteRandomInstantly then
				DAKDisplayMessageToAllClients("kVoteRandomEnabled")
				if Server then
					Shared.ConsoleCommand("sv_rrall")
					Shared.ConsoleCommand("sv_reset")
					ShuffleTeams(true)
				end
			else
				DAKDisplayMessageToAllClients("kVoteRandomEnabledDuration", kDAKConfig.VoteRandom.kVoteRandomDuration)
				kDAKSettings.RandomEnabledTill = Shared.GetSystemTime() + (kDAKConfig.VoteRandom.kVoteRandomDuration * 60)
				SaveDAKSettings()
				kVoteRandomTeamsEnabled = true
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

end

Shared.Message("VoteRandom Loading Complete")