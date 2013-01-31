//NS2 Team Surrender Vote

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
	local SVRunning = false
	for i = 1, kSurrenderTeamCount do

		if kSurrenderVoteArray[i].VoteSurrenderRunning ~= 0 and gamerules ~= nil and gamerules:GetGameState() == kGameState.Started and kSurrenderVoteArray[i].SurrenderVotesAlertTime + kDAKConfig.VoteSurrender.kVoteSurrenderAlertDelay < Shared.GetTime() then
			local playerRecords =  GetEntitiesForTeam("Player", i)
			local playerCount = #playerRecords
			SVRunning = true
			local totalvotes = 0
			for j = #kSurrenderVoteArray[i].SurrenderVotes, 1, -1 do
				local clientid = kSurrenderVoteArray[i].SurrenderVotes[j]
				local stillplaying = false
			
				for k = 1, playerCount do
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
			if totalvotes >= math.ceil((playerCount * (kDAKConfig.VoteSurrender.kVoteSurrenderMinimumPercentage / 100))) then
				
				DAKDisplayMessageToAllClients("kSurrenderTeamQuit", ToString(i))
				for l = 1, playerCount do
					if playerRecords[l] ~= nil then
						local gamerules = GetGamerules()
						if gamerules then
							gamerules:JoinTeam(playerRecords[l], kTeamReadyRoom)
						end
					end
				end
				
				kSurrenderVoteArray[i].SurrenderVotesAlertTime = 0
				kSurrenderVoteArray[i].VoteSurrenderRunning = 0
				kSurrenderVoteArray[i].SurrenderVotes = { }

			else
				if kSurrenderVoteArray[i].SurrenderVotesAlertTime == 0 then
					DAKDisplayMessageToTeam(i, "kSurrenderVoteStarted", math.ceil((playerCount * (kDAKConfig.VoteSurrender.kVoteSurrenderMinimumPercentage / 100))))
					kSurrenderVoteArray[i].SurrenderVotesAlertTime = Shared.GetTime()
				elseif kSurrenderVoteArray[i].VoteSurrenderRunning + kDAKConfig.VoteSurrender.kVoteSurrenderVotingTime < Shared.GetTime() then
					DAKDisplayMessageToTeam(i, "kSurrenderVoteExpired")
					kSurrenderVoteArray[i].SurrenderVotesAlertTime = 0
					kSurrenderVoteArray[i].VoteSurrenderRunning = 0
					kSurrenderVoteArray[i].SurrenderVotes = { }
				else
					DAKDisplayMessageToTeam(i, "kSurrenderVoteUpdate", totalvotes, math.ceil((playerCount * (kDAKConfig.VoteSurrender.kVoteSurrenderMinimumPercentage / 100))), 
					 math.ceil((kSurrenderVoteArray[i].VoteSurrenderRunning + kDAKConfig.VoteSurrender.kVoteSurrenderVotingTime) - Shared.GetTime()))
					kSurrenderVoteArray[i].SurrenderVotesAlertTime = Shared.GetTime()
				end
			end
			
		end
		
	end
	if not SVRunning then
		DAKDeregisterEventHook("kDAKOnServerUpdate", UpdateSurrenderVotes)
	end
end

DAKRegisterEventHook("kDAKOnServerUpdate", UpdateSurrenderVotes, 5)

local function ClearSurrenderVotes()
	for i = 1, kSurrenderTeamCount do
		kSurrenderVoteArray[i].SurrenderVotesAlertTime = 0
		kSurrenderVoteArray[i].VoteSurrenderRunning = 0
		kSurrenderVoteArray[i].SurrenderVotes = { }
	end
end

DAKRegisterEventHook("kDAKOnGameEnd", ClearSurrenderVotes, 5)

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
						DAKDisplayMessageToClient(client, "kSurrenderVoteAlreadyVoted")
					else
						table.insert(kSurrenderVoteArray[teamnumber].SurrenderVotes, clientID)
						DAKDisplayMessageToClient(client, "kSurrenderVoteToSurrender")
					end						
				else
					kSurrenderVoteArray[teamnumber].VoteSurrenderRunning = Shared.GetTime()
					table.insert(kSurrenderVoteArray[teamnumber].SurrenderVotes, clientID)
					DAKDisplayMessageToClient(client, "kSurrenderVoteToSurrender")
				end
				//Going to just start this, at worst it causes a single event
				DAKRegisterEventHook("kDAKOnServerUpdate", UpdateSurrenderVotes, 5)
			end
		end
	end
	
end

Event.Hook("Console_surrender",               OnCommandVoteSurrender)

local function OnVoteSurrenderChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)

	if client and steamId and steamId ~= 0 then
		for c = 1, #kDAKConfig.VoteSurrender.kSurrenderChatCommands do
			local chatcommand = kDAKConfig.VoteSurrender.kSurrenderChatCommands[c]
			if string.upper(message) == string.upper(chatcommand) then
				OnCommandVoteSurrender(client)
			end
		end
	end

end

DAKRegisterEventHook("kDAKOnClientChatMessage", OnVoteSurrenderChatMessage, 5)

local function VoteSurrenderOff(client, teamnum)
	local tmNum = tonumber(teamnum)
	if tmNum ~= nil and ValidateTeamNumber(tmNum) and kVoteSurrenderRunning[tmNum] ~= 0 then
		kSurrenderVoteArray[tmNum].SurrenderVotesAlertTime = 0
		kSurrenderVoteArray[tmNum].VoteSurrenderRunning = 0
		kSurrenderVoteArray[tmNum].SurrenderVotes = { }
		DAKDisplayMessageToTeam(tmNum, "kSurrenderVoteCancelled", tmNum)
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
		DAKRegisterEventHook("kDAKOnServerUpdate", UpdateSurrenderVotes, 5)
	end

end

DAKCreateServerAdminCommand("Console_sv_surrendervote", VoteSurrenderOn, "<teamnumber> Will start a surrender vote for that team.")