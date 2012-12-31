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
				chatMessage = string.sub(string.format("Random teams have been enabled, the round will restart."), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				if Server then
					Shared.ConsoleCommand("sv_rrall")
					Shared.ConsoleCommand("sv_reset")
					ShuffleTeams(true)
				end
			else
				chatMessage = string.sub(string.format("Random teams have been enabled for the next %s Minutes", kDAKConfig.VoteRandom.kVoteRandomDuration), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				kDAKSettings.RandomEnabledTill = Shared.GetSystemTime() + (kDAKConfig.VoteRandom.kVoteRandomDuration * 60)
				SaveDAKSettings()
				kVoteRandomTeamsEnabled = true
			end
			
		elseif not silent then
		
			chatMessage = string.sub(string.format("%s voted for random teams. (%s votes, needed %s).", playername, totalvotes, math.ceil((playerRecords:GetSize() * (kDAKConfig.VoteRandom.kVoteRandomMinimumPercentage / 100)))), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			
		end
		return true
		
	end
	
	table.insert(kDAKOnClientDisconnect, function(client) return UpdateRandomVotes(true, "") end)

	local function VoteRandomClientConnect(client)

		if client ~= nil then
			local player = client:GetControllingPlayer()
		
			if player ~= nil and kVoteRandomTeamsEnabled then 
				chatMessage = string.sub(string.format("Random teams are enabled, you are being randomed to a team."), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				JoinRandomTeam(player)
			end
			return true
		end
		return false
	end
	
	table.insert(kDAKOnClientDelayedConnect, function(client) return VoteRandomClientConnect(client) end)
	
	local function VoteRandomJoinTeam(player, newTeamNumber, force)
		if RandomRoundRecentlyEnded ~= nil and RandomRoundRecentlyEnded + RandomNewRoundDelay > Shared.GetTime() and (newTeamNumber == 1 or newTeamNumber == 2) then
			chatMessage = string.sub(string.format("Random teams are enabled, you will be randomed to a team shortly."), 1, kMaxChatLength)
			Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			return false
		end
		return true
	end
	
	table.insert(kDAKOnTeamJoin, function(player, newTeamNumber, force) return VoteRandomJoinTeam(player, newTeamNumber, force) end)
	
	local function VoteRandomEndGame(winningTeam)
		if kVoteRandomTeamsEnabled then
			RandomRoundRecentlyEnded = Shared.GetTime()
		end
	end
	
	table.insert(kDAKOnGameEnd, function(winningTeam) return VoteRandomEndGame(winningTeam) end)

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
		return true
	end

	DAKRegisterEventHook(kDAKOnServerUpdate, function(deltatime) return RandomTeams() end, 5)

	local function OnCommandVoteRandom(client)

		if client ~= nil then
		
			local player = client:GetControllingPlayer()
			if player ~= nil then
				if kVoteRandomTeamsEnabled then
					chatMessage = string.sub(string.format("Random teams already enabled."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					return
				end
				if RandomVotes[client:GetUserId()] ~= nil then			
					chatMessage = string.sub(string.format("You already voted for random teams."), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				else
					local playerRecords = Shared.GetEntitiesWithClassname("Player")
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
	
	table.insert(kDAKOnClientChatMessage, function(message, playerName, steamId, teamNumber, teamOnly, client) return OnVoteRandomChatMessage(message, playerName, steamId, teamNumber, teamOnly, client) end)

	local function VoteRandomOff(client)

		if kVoteRandomTeamsEnabled then
		
			kVoteRandomTeamsEnabled = false
			kDAKSettings.RandomEnabledTill = 0
			SaveDAKSettings()
			chatMessage = string.sub(string.format("Random teams have been disabled."), 1, kMaxChatLength)
			Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
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
				chatMessage = string.sub(string.format("Random teams have been enabled, the round will restart."), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				if Server then
					Shared.ConsoleCommand("sv_rrall")
					Shared.ConsoleCommand("sv_reset")
					ShuffleTeams(true)
				end
			else
				chatMessage = string.sub(string.format("Random teams have been enabled for the next %s Minutes", kDAKConfig.VoteRandom.kVoteRandomDuration), 1, kMaxChatLength)
				Server.SendNetworkMessage("Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
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