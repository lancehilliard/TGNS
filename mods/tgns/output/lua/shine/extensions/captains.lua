local md
local captainClients = {}
local captainsModeEnabled
local captainsGamesFinished = 0
local readyTeams = {}
local gamesFinished = 0
local captainTeamNumbers = {}
local originalForceEvenTeamsOnJoinSetting
local gameStarted
local readyPlayerClients
local readyCaptainClients

local function setCaptainsGameConfig()
	if not originalForceEvenTeamsOnJoinSetting then
		originalForceEvenTeamsOnJoinSetting = Server.GetConfigSetting("force_even_teams_on_join")
	end
	Server.SetConfigSetting("force_even_teams_on_join", false)
end

local function setOriginalConfig()
	if originalForceEvenTeamsOnJoinSetting then
		Server.SetConfigSetting("force_even_teams_on_join", originalForceEvenTeamsOnJoinSetting)
	end
end

function disableCaptainsMode()
	captainsModeEnabled = false
	TGNS.DoFor(captainClients, function(c) TGNS.RemoveTempGroup(c, "captains_group") end)
end

local function enableCaptainsMode(nameOfEnabler, captain1Client, captain2Client)
	local randomizedCaptainClients = TGNS.GetRandomizedElements({captain1Client,captain2Client})
	captainClients = { randomizedCaptainClients[1], randomizedCaptainClients[2] }
	captainTeamNumbers[captainClients[1]] = 1
	captainTeamNumbers[captainClients[2]] = 2
	captainsModeEnabled = true
	captainsGamesFinished = 0
	TGNS.DoFor(captainClients, function(c) TGNS.AddTempGroup(c, "captains_group") end)
	md:ToAllNotifyInfo(string.format("%s enabled Captains Game! Pick teams and play two rounds!", nameOfEnabler))
	TGNS.ScheduleAction(3, function()
		md:ToAllNotifyInfo(string.format("%s: %s! %s: %s! Who will pick first? Who will pick two?", TGNS.GetClientName(captainClients[1]), TGNS.GetTeamName(captainTeamNumbers[captainClients[1]]), TGNS.GetClientName(captainClients[2]), TGNS.GetTeamName(captainTeamNumbers[captainClients[2]])))
	end)
	Shine.Plugins.mapvote.Config.RoundLimit = gamesFinished + 2
	setCaptainsGameConfig()
	TGNS.ForcePlayersToReadyRoom(TGNS.GetPlayerList())
end

local function getDescriptionOfWhatElseIsNeededToPlayCaptains(headlineReadyClient, playingClients, numberOfPlayingReadyPlayerClients, numberOfPlayingReadyCaptainClients)
	local result = ""
	local percentageOfplayingReadyPlayerClients = numberOfPlayingReadyPlayerClients / #playingClients
	if percentageOfplayingReadyPlayerClients < .82 or numberOfPlayingReadyCaptainClients < 2 then
		local numberOfNeededReadyPlayerClients = TGNS.RoundPositiveNumber(.82 * #playingClients)
		result = string.format("%s is ready! Ready so far: Players: %s/%s - Captains %s/2.", TGNS.GetClientName(headlineReadyClient), numberOfPlayingReadyPlayerClients, numberOfNeededReadyPlayerClients, numberOfPlayingReadyCaptainClients)
	end
	return result
end

local function updateCaptainsReadyProgress(readyClient)
	local playingClients = TGNS.GetClientList()
	local playingReadyCaptainClients = TGNS.Where(playingClients, function(c) return TGNS.Has(readyCaptainClients, c) end)
	local playingReadyPlayerClients = TGNS.Where(playingClients, function(c) return TGNS.Has(readyPlayerClients, c) or TGNS.Has(playingReadyCaptainClients, c) end)
	local descriptionOfWhatElseIsNeededToPlayCaptains = getDescriptionOfWhatElseIsNeededToPlayCaptains(readyClient, playingClients, #playingReadyPlayerClients, #playingReadyCaptainClients)
	if TGNS.HasNonEmptyValue(descriptionOfWhatElseIsNeededToPlayCaptains) then
		local message = string.format("You're marked as ready to play%s a Captains Game.", TGNS.Has(playingReadyCaptainClients, readyClient) and " (and lead)" or "")
		md:ToPlayerNotifyInfo(TGNS.GetPlayer(readyClient), message)
		md:ToAllNotifyInfo(descriptionOfWhatElseIsNeededToPlayCaptains)
	else
		enableCaptainsMode(string.format("%s and %s", TGNS.GetClientName(playingReadyCaptainClients[1]), TGNS.GetClientName(playingReadyCaptainClients[2])), playingReadyCaptainClients[1], playingReadyCaptainClients[2])
	end
end

local function addReadyPlayerClient(client)
	readyPlayerClients = readyPlayerClients or {}
	if not TGNS.Has(readyPlayerClients, client) then
		table.insert(readyPlayerClients, client)
	end
	updateCaptainsReadyProgress(client)
end

local function addReadyCaptainClient(client)
	readyCaptainClients = readyCaptainClients or {}
	if not TGNS.Has(readyCaptainClients, client) then
		table.insert(readyCaptainClients, client)
	end
	updateCaptainsReadyProgress(client)
end

//function swapTeamsAfterDelay(delayInSeconds)
//	local originalPlayerTeamNumbers = {}
//	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
//		if TGNS.PlayerIsOnPlayingTeam(p) then
//			originalPlayerTeamNumbers[p] = TGNS.GetPlayerTeamNumber(p)
//		end
//	end)
//	TGNS.ScheduleAction(delayInSeconds, function()
//		TGNS.DoForPairs(originalPlayerTeamNumbers, function(player, teamNumber)
//			local otherTeamNumber = teamNumber == 1 and 2 or 1
//			TGNS.SendToTeam(player, otherTeamNumber, true)
//		end)
//		md:ToAllNotifyInfo("Teams have been swapped!")
//	end)
//end

local function bothCaptainsAreReady()
	local result = TGNS.All(captainClients, function(c)
		local clientTeamName = TGNS.PlayerAction(c, TGNS.GetPlayerTeamName)
		return readyTeams[clientTeamName]
	end)
	return result
end

local Plugin = {}

function Plugin:IsCaptainsModeEnabled()
	return captainsModeEnabled
end

function Plugin:CheckGameStart(gamerules)
	//local result = true
	if captainsModeEnabled and not bothCaptainsAreReady() then
		return false
	end
	//return result
end

function Plugin:UpdatePregame(gamerules)
	//local result = true
	if captainsModeEnabled and TGNS.IsGameInPreGame() then
		result = false
	end
	//return result
end

function Plugin:EndGame(gamerules, winningTeam)
	if captainsModeEnabled then
		gameStarted = false
		captainsGamesFinished = captainsGamesFinished + 1
		local message = "Time for Round 2! Everyone switch teams!"
		TGNS.DoForPairs(captainTeamNumbers, function(client, teamNumber)
			captainTeamNumbers[client] = captainTeamNumbers[client] == 1 and 2 or 1
		end)
		if captainsGamesFinished < 2 then
			setCaptainsGameConfig()
		else
			disableCaptainsMode()
			message = "Both rounds of Captains Game finished! Thanks for playing! -- TacticalGamer.com"
		end
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 2.5, function()
			//swapTeamsAfterDelay(3)
			md:ToAllNotifyInfo(message)
		end)
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 4, function()
			TGNS.DoFor(TGNS.GetPlayers(TGNS.GetStrangerClients(TGNS.GetPlayerList())), function(p)
				md:ToPlayerNotifyInfo(p, "If you enjoy playing here, be sure to bookmark this TacticalGamer.com server!")
			end)
		end)
	end
	gamesFinished = gamesFinished + 1
end

function Plugin:CreateCommands()
	local captainsCommand = self:BindCommand("sh_captains", "captains", function(client, captain1Predicate, captain2Predicate)
		local player = TGNS.GetPlayer(client)
		if captainsModeEnabled then
			md:ToPlayerNotifyError(player, "Captains Game is already active.")
		else
			if not TGNS.IsGameInProgress() then
				if Shine.Plugins.mapvote:VoteStarted() then
					md:ToPlayerNotifyError(player, "Captains Game cannot be activated during a map vote.")
				else
					local playerName = TGNS.GetPlayerName(player)
					if captain1Predicate == nil or captain1Predicate == "" then
						md:ToPlayerNotifyError(player, "You must specify a first Captain.")
					elseif captain2Predicate == nil or captain2Predicate == "" then
						md:ToPlayerNotifyError(player, "You must specify a second Captain.")
					else
						local captain1Player = TGNS.GetPlayerMatching(captain1Predicate, nil)
						local captain2Player = TGNS.GetPlayerMatching(captain2Predicate, nil)
						if captain1Player ~= nil then
							if captain2Player ~= nil then
								local captain1Client = TGNS.GetClient(captain1Player)
								local captain2Client = TGNS.GetClient(captain2Player)
								enableCaptainsMode(TGNS.GetClientName(client), captain1Client, captain2Client)
							else
								md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", captain2Predicate))
							end
						else
							md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", captain1Predicate))
						end
					end
				end
			else
				md:ToPlayerNotifyError(player, "Captains Game cannot be activated during a game.")
			end
		end
	end)
	captainsCommand:AddParam{ Type = "string", Optional = true }
	captainsCommand:AddParam{ Type = "string", Optional = true }
	captainsCommand:Help("<captain1player> <captain2player> Designate two captains and activate Captains Game.")

	local pickCommand = self:BindCommand( "sh_pick", "pick", function(client, playerPredicate)
		local player = TGNS.GetPlayer(client)
		local teamNumber = captainTeamNumbers[client]
		if TGNS.IsGameInProgress() then
			md:ToPlayerNotifyError(player, "Players cannot be picked during a game.")
		elseif not captainsModeEnabled then
			md:ToPlayerNotifyError(player, "Captains Game not enabled. Cannot pick a player.")
		elseif not TGNS.Has(captainClients, client) then
			md:ToPlayerNotifyError(player, "You must be a Captain to pick a player.")
		elseif not TGNS.IsGameplayTeamNumber(teamNumber) then
			md:ToPlayerNotifyError(player, "Oops. I see you're a Captain, but your team is unknown.")
		elseif playerPredicate == nil or playerPredicate == "" then
			md:ToPlayerNotifyError(player, "You must specify a player.")
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
			if targetPlayer then
				md:ToPlayerNotifyInfo(targetPlayer, string.format("%s chose you for %s!", TGNS.GetClientName(client), TGNS.GetTeamName(teamNumber)))
				TGNS.SendToTeam(targetPlayer, teamNumber, true)
			else
				md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
			end
		end
	end)
	pickCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
	pickCommand:Help( "<player> Pick the given player for your Captains Game team." )

	local willCaptainsCommand = self:BindCommand("sh_iwillcaptain", "iwillcaptain", function(client)
		local player = TGNS.GetPlayer(client)
		if captainsModeEnabled then
			md:ToPlayerNotifyError(player, "Captains Game is already active.")
		elseif Shine.Plugins.mapvote:VoteStarted() then
			md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
		else
			addReadyCaptainClient(client)
		end
	end, true)
	willCaptainsCommand:Help("Tell that you're willing to lead a team in a Captains Game.")

	local wantCaptainsCommand = self:BindCommand("sh_iwantcaptains", "iwantcaptains", function(client)
		local player = TGNS.GetPlayer(client)
		if captainsModeEnabled then
			md:ToPlayerNotifyError(player, "Captains Game is already active.")
		elseif Shine.Plugins.mapvote:VoteStarted() then
			md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
		else
			addReadyPlayerClient(client)
		end
	end, true)
	wantCaptainsCommand:Help("Tell that you want to play a Captains Game.")

end

function Plugin:PlayerSay(client, networkMessage)
	local shouldSuppressChatMessageDisplay = false
	if captainsModeEnabled and not (TGNS.IsGameInProgress() or TGNS.IsGameInCountdown()) then
		local player = TGNS.GetPlayer(client)
		local playerTeamName = TGNS.GetPlayerTeamName(player)
		if TGNS.PlayerIsOnPlayingTeam(player) then
			local teamsAreSufficientlyBalanced = math.abs(#TGNS.GetMarineClients() - #TGNS.GetAlienClients()) <= 1
			local message = StringTrim(networkMessage.message)
			if TGNS.Has({"ready", "unready"}, message) then
				local nameOfOtherPersonOnTeamWhoIsCaptain = ""
				TGNS.DoFor(TGNS.GetTeamClients(TGNS.GetPlayerTeamNumber(player), TGNS.GetPlayerList()), function(c)
					if TGNS.Has(captainClients, c) and client ~= c then
						nameOfOtherPersonOnTeamWhoIsCaptain = TGNS.GetClientName(c)
					end
				end)
				if TGNS.HasNonEmptyValue(nameOfOtherPersonOnTeamWhoIsCaptain) then
					md:ToPlayerNotifyError(player, string.format("%s is Captain and should ready or unready.", nameOfOtherPersonOnTeamWhoIsCaptain))
					shouldSuppressChatMessageDisplay = true
				else
					if message == "ready" then
						shouldSuppressChatMessageDisplay = readyTeams[playerTeamName]
						if teamsAreSufficientlyBalanced then
							readyTeams[playerTeamName] = true
							md:ToAllNotifyInfo(string.format("%s has readied the %s!", TGNS.GetClientName(client), TGNS.GetPlayerTeamName(player)))
						else
							md:ToPlayerNotifyError(player, "Ready halted: Team counts must match (or be off by only one) to play.")
						end
					elseif message == "unready" then
						shouldSuppressChatMessageDisplay = not readyTeams[playerTeamName]
						if readyTeams[playerTeamName] then
							if TGNS.Has(captainClients, client) then
								readyTeams[playerTeamName] = false
								md:ToAllNotifyInfo(string.format("%s has UN-readied the %s!", TGNS.GetClientName(client), TGNS.GetPlayerTeamName(player)))
							else
								md:ToPlayerNotifyError(player, "Only captains may unready. Team remains ready.")
							end
						else
							md:ToPlayerNotifyInfo(player, "Team is not ready.")
						end
					end
				end
				if bothCaptainsAreReady() then
					TGNS.ScheduleAction(5, function()
						if bothCaptainsAreReady() and not gameStarted then
							gameStarted = true
							md:ToAllNotifyInfo(string.format("Both teams are ready! Round %s of 2 starts now!", captainsGamesFinished + 1))
							TGNS.ScheduleAction(1, function()
								setOriginalConfig()
								TGNS.ForceGameStart()
								TGNS.ScheduleAction(kCountDownLength + 2, function()
									TGNS.DoFor(captainClients, function(c)
										readyTeams[TGNS.PlayerAction(c, TGNS.GetPlayerTeamName)] = nil
									end)
								end)
							end)
						end
					end)
					md:ToAllNotifyInfo("Both teams are ready? Captains: \"unready\" or prepare to play!")
				end
			end
		end
	end
	if shouldSuppressChatMessageDisplay then
		return ""
	end
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("CAPTAINS")
	self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("captains", Plugin )