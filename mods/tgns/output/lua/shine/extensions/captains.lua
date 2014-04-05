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
local timeAtWhichToForceRoundStart
local SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START = 300
local whenToAllowTeamJoins = 0
local votesAllowedUntil
local mayVoteYet
local automaticVoteAllowAction = function()
	mayVoteYet = true
end
local MAX_NON_CAPTAIN_PLAYERS = 14
local lastVoiceWarningTimes = {}

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
	TGNS.DoFor(captainClients, function(c)
		if Shine:IsValidClient(c) then
			TGNS.RemoveTempGroup(c, "captains_group")
		end
	end)
end

local function startGame()
	if timeAtWhichToForceRoundStart and timeAtWhichToForceRoundStart ~= 0 then
		timeAtWhichToForceRoundStart = 0
		TGNS.ScheduleAction(2, function()
			setOriginalConfig()
			TGNS.ForceGameStart()
			TGNS.ScheduleAction(kCountDownLength + 2, function()
				readyTeams["Marines"] = false
				readyTeams["Aliens"] = false
				if (captainsGamesFinished > 0) then
					Shine.Plugins.mapvote.Config.RoundLimit = 1
				end
			end)
		end)
	end
end

local function bothTeamsAreReady()
	local result = readyTeams["Marines"] == true and readyTeams["Aliens"] == true
	return result
end

local function warnOfPendingCaptainsGameStart()
	local now = TGNS.GetSecondsSinceMapLoaded()
	if timeAtWhichToForceRoundStart and timeAtWhichToForceRoundStart ~= 0 then
		if bothTeamsAreReady() then
			TGNS.ScheduleAction(1, warnOfPendingCaptainsGameStart)
		else
			local message
			local duration = 3
			local r = 0
			local g = 255
			local b = 0
			local secondsRemaining = timeAtWhichToForceRoundStart - now
			if secondsRemaining >= 1 then
				message = string.format("Game will force-start in %s.", string.DigitalTime(secondsRemaining))
				if secondsRemaining < 30 then
					r = 255
					g = 255
					b = 0
				end
				TGNS.ScheduleAction(1, warnOfPendingCaptainsGameStart)
			else
				--message = "Planning time expired. Game is force-starting now."
				message = "Planning time expired.\nGame is force-starting now."
				duration = 7
				startGame()
				r = 255
				g = 0
				b = 0
			end
			Shine:SendText(c, Shine.BuildScreenMessage(51, 0.5, 0.85, message, duration, r, g, b, 1, 1, 0))
		end
	end
end

local function setTimeAtWhichToForceRoundStart()
	timeAtWhichToForceRoundStart = TGNS.GetSecondsSinceMapLoaded() + SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START + 30 + (captainsGamesFinished == 0 and 60 or 0)
	TGNS.ScheduleAction(29, warnOfPendingCaptainsGameStart)
end

local function showRoster(clients, renderClients, titleMessageId, column1MessageId, column2MessageId, titleY, titleText)
	local columnsY = titleY + 0.03
	TGNS.SortAscending(clients, TGNS.GetClientId)
	local names = TGNS.Select(clients, function(c) return TGNS.Truncate(TGNS.GetClientName(c), 16) end)
	local column1Names = {}
	local column2Names = {}
	TGNS.DoFor(names, function(n, index)
		if index % 2 ~= 0 then
			table.insert(column1Names, n)
		else
			table.insert(column2Names, n)
		end
	end)
	if #column1Names == 0 then
		table.insert(column1Names, "(None)")
	end
	TGNS.DoFor(renderClients, function(c)
		Shine:SendText(c, Shine.BuildScreenMessage( titleMessageId, 0.80, titleY, string.format("%s (%s)", titleText, #clients), 3, 0, 255, 0, 0, 2, 0 ) )
		local column1Message = TGNS.Join(column1Names, '\n')
		Shine:SendText(c, Shine.BuildScreenMessage( column1MessageId, 0.80, columnsY, column1Message, 3, 0, 255, 0, 0, 1, 0 ) )
		local column2Message = TGNS.Join(column2Names, '\n')
		Shine:SendText(c, Shine.BuildScreenMessage( column2MessageId, 0.90, columnsY, column2Message, 3, 0, 255, 0, 0, 1, 0 ) )
	end)
end

local function showPickables()
	if not TGNS.IsGameInProgress() then
		local optedInClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.ClientIsInGroup(c, "captainsgame_group") end)
		if captainsGamesFinished == 0 then
			local readyRoomClients = TGNS.GetReadyRoomClients()
			local notOptedInClients = TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.ClientIsInGroup(c, "captainsgame_group") and not TGNS.ClientIsInGroup(c, "captains_group") and TGNS.IsPlayerReadyRoom(TGNS.GetPlayer(c)) end)
			showRoster(optedInClients, readyRoomClients, 52, 53, 54, 0.17, "Opted In")
			showRoster(notOptedInClients, readyRoomClients, 55, 56, 57, 0.5, "Not Opted In")
			TGNS.ScheduleAction(1, showPickables)
		end
	end
end

local function enableCaptainsMode(nameOfEnabler, captain1Client, captain2Client)
	local randomizedCaptainClients = TGNS.GetRandomizedElements({captain1Client,captain2Client})
	captainClients = { randomizedCaptainClients[1], randomizedCaptainClients[2] }
	captainTeamNumbers[captainClients[1]] = 1
	captainTeamNumbers[captainClients[2]] = 2
	captainsModeEnabled = true
	setTimeAtWhichToForceRoundStart()
	captainsGamesFinished = 0
	TGNS.DoFor(captainClients, function(c)
		TGNS.AddTempGroup(c, "captains_group")
		TGNS.ScheduleAction(30, function() TGNS.PlayerAction(c, function(p) md:ToPlayerNotifyInfo(p, "Captains: Use sh_setteam if you need to force anyone to a team.") end) end)
	end)
	TGNS.ScheduleAction(0, function()
		md:ToAllNotifyInfo(string.format("%s enabled Captains Game! Pick teams and play two rounds!", nameOfEnabler))
	end)
	TGNS.ScheduleAction(3, function()
		md:ToAllNotifyInfo(string.format("%s: Player Choice! %s: Team Choice!", TGNS.GetClientName(captainClients[1]), TGNS.GetClientName(captainClients[2])))
	end)
	setCaptainsGameConfig()
	TGNS.ForcePlayersToReadyRoom(TGNS.Where(TGNS.GetPlayerList(), function(p) return not TGNS.IsPlayerSpectator(p) end))
	whenToAllowTeamJoins = TGNS.GetSecondsSinceMapLoaded() + 20
	votesAllowedUntil = nil
	Shine.Plugins.mapvote.Config.RoundLimit = gamesFinished + 2
	TGNS.ScheduleAction(2, showPickables)
	Shine.Plugins.afkkick.Config.KickTime = 20
end

local function getDescriptionOfWhatElseIsNeededToPlayCaptains(headlineReadyClient, playingClients, numberOfPlayingReadyPlayerClients, numberOfPlayingReadyCaptainClients, firstCaptainName, secondCaptainName)
	local result = ""
	local numberOfNeededReadyPlayerClients = TGNS.RoundPositiveNumberDown((.82 * #playingClients) - 2)
	numberOfNeededReadyPlayerClients = numberOfNeededReadyPlayerClients >= 0 and numberOfNeededReadyPlayerClients or 0
	local adjustedNumberOfNeededReadyPlayerClients = numberOfNeededReadyPlayerClients <= 14 and numberOfNeededReadyPlayerClients or 14
	local remaining = adjustedNumberOfNeededReadyPlayerClients - numberOfPlayingReadyPlayerClients
	if not captainsModeEnabled and numberOfPlayingReadyCaptainClients == 1 then
		result = string.format("%s will Captain! Who else will captain?", firstCaptainName)
	elseif remaining > 0 then
		result = string.format("%s wants Captains (%s & %s)! %s more needed!", TGNS.GetClientName(headlineReadyClient), firstCaptainName, secondCaptainName, remaining)
	end
	return result
end

local function updateCaptainsReadyProgress(readyClient)
	local playingClients = TGNS.GetClients(TGNS.Where(TGNS.GetPlayerList(), function(p) return not (TGNS.IsPlayerSpectator(p) or TGNS.IsPlayerAFK(p)) end))
	local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
	local firstCaptainName = #playingReadyCaptainClients > 0 and TGNS.GetClientName(playingReadyCaptainClients[1]) or "???"
	local secondCaptainName = #playingReadyCaptainClients > 1 and TGNS.GetClientName(playingReadyCaptainClients[2]) or "???"
	local playingReadyPlayerClients = TGNS.Where(playingClients, function(c) return TGNS.Has(readyPlayerClients, c) end)
	local descriptionOfWhatElseIsNeededToPlayCaptains = getDescriptionOfWhatElseIsNeededToPlayCaptains(readyClient, playingClients, #playingReadyPlayerClients, #playingReadyCaptainClients, firstCaptainName, secondCaptainName)
	if TGNS.HasNonEmptyValue(descriptionOfWhatElseIsNeededToPlayCaptains) then
		local message = string.format("You're marked as ready to play%s a Captains Game.", TGNS.Has(playingReadyCaptainClients, readyClient) and " (and lead)" or "")
		md:ToPlayerNotifyInfo(TGNS.GetPlayer(readyClient), message)
		md:ToAllNotifyInfo(descriptionOfWhatElseIsNeededToPlayCaptains)
	else
		if not captainsModeEnabled then
			enableCaptainsMode(string.format("%s and %s", TGNS.GetClientName(playingReadyCaptainClients[1]), TGNS.GetClientName(playingReadyCaptainClients[2])), playingReadyCaptainClients[1], playingReadyCaptainClients[2])
		end
	end
end

local function announceTimeRemaining()
	if not captainsModeEnabled then
		local secondsRemaining = votesAllowedUntil - TGNS.GetSecondsSinceMapLoaded()
		if secondsRemaining > 1 then
			local timeLeftAdvisory = votesAllowedUntil == math.huge and "" or string.format("%s left.", string.TimeToString(secondsRemaining))
			local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
			local firstCaptainName = #playingReadyCaptainClients > 0 and TGNS.GetClientName(playingReadyCaptainClients[1]) or "???"
			local secondCaptainName = #playingReadyCaptainClients > 1 and TGNS.GetClientName(playingReadyCaptainClients[2]) or "???"
			md:ToAllNotifyInfo(string.format("Press M > Captains if you want to play Captains (%s & %s). %s", firstCaptainName, secondCaptainName, timeLeftAdvisory))
			TGNS.ScheduleAction(10 > secondsRemaining and secondsRemaining or 10, announceTimeRemaining)
		else
			TGNS.ScheduleAction(1, function()
				if not captainsModeEnabled then
					md:ToAllNotifyInfo("Captains vote expired.")
				end
			end)
		end
	end
end

local function addReadyPlayerClient(client)
	if votesAllowedUntil == nil then
		votesAllowedUntil = TGNS.GetSecondsSinceMapLoaded() + 62
		TGNS.ScheduleAction(1, announceTimeRemaining)
	end
	readyPlayerClients = readyPlayerClients or {}
	if TGNS.Has(readyPlayerClients, client) then
		updateCaptainsReadyProgress(client)
	else
		local playingReadyPlayerClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyPlayerClients, c) end)
		if #playingReadyPlayerClients < MAX_NON_CAPTAIN_PLAYERS then
			table.insert(readyPlayerClients, client)
			TGNS.RemoveAllMatching(readyCaptainClients, client)
			updateCaptainsReadyProgress(client)
		else
			local player = TGNS.GetPlayer(client)
			md:ToPlayerNotifyError(player, "Too many people have already opted in to play.")
			local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
			if #playingReadyCaptainClients < 2 then
				md:ToPlayerNotifyError(player, "There's still room for another Captain!")
			end
		end
	end
	if captainsModeEnabled then
		if TGNS.Has(readyPlayerClients, client) then
			if not TGNS.IsGameInProgress() then
				if TGNS.PlayerAction(client, TGNS.IsPlayerReadyRoom) then
					TGNS.AddTempGroup(client, "captainsgame_group")
				end
				md:ToAllNotifyInfo(string.format("%s wants Captains, too!", TGNS.GetClientName(client)))
			end
		end
	end
	TGNS.UpdateAllScoreboards()
end

local function addReadyCaptainClient(client)
	readyCaptainClients = readyCaptainClients or {}
	if not TGNS.Has(readyCaptainClients, client) then
		table.insert(readyCaptainClients, client)
		TGNS.RemoveAllMatching(readyPlayerClients, client)
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

function getCaptainsGameStateDescription()
	local result = ""
	if captainsGamesFinished < 2 then
		result = string.format("It's a Captains Game! Round %s %s!", captainsGamesFinished + 1, TGNS.IsGameInProgress() and "in progress" or "starting soon")
	else
		result = "Round Two of a Captains Game just finished! Captains Game over!"
	end
	return result
end

local Plugin = {}

function Plugin:IsCaptainsModeEnabled()
	return captainsModeEnabled
end

function Plugin:IsClientCaptain(client)
	return Shine:IsInGroup(client, "captains_group")
end

function Plugin:CheckGameStart(gamerules)
	//local result = true
	if captainsModeEnabled and not bothTeamsAreReady() then
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
			setTimeAtWhichToForceRoundStart()
		else
			disableCaptainsMode()
			message = "Both rounds of Captains Game finished! Thanks for playing! -- TacticalGamer.com"
		end
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 2.5, function()
			//swapTeamsAfterDelay(3)
			md:ToAllNotifyInfo(message)
		end)
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 4, function()
			TGNS.DoFor(TGNS.GetPlayers(TGNS.GetStrangersClients(TGNS.GetPlayerList())), function(p)
				md:ToPlayerNotifyInfo(p, "If you enjoy playing here, be sure to bookmark this TacticalGamer.com server!")
			end)
		end)
	else
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 10, function()
			if Shine.Plugins.mapvote:VoteStarted() then
				md:ToAllNotifyInfo("Join us Friday nights for Captains Games! Passworded, scrim-style gameplay")
				md:ToAllNotifyInfo("from ~7PM 'til. Read more in our forums: TacticalGamer.com/natural-selection")
			end
		end)
	end
	gamesFinished = gamesFinished + 1

	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 1, function()
		clientFriendlyFireWarnings = {}
	end)
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

	local pickCommand = self:BindCommand( "sh_pick", "pick", function(client, playerPredicate, teamNumberCandidate)
		local player = TGNS.GetPlayer(client)
		if TGNS.IsGameInProgress() then
			md:ToPlayerNotifyError(player, "Players cannot be picked during a game.")
		elseif not captainsModeEnabled then
			md:ToPlayerNotifyError(player, "Captains Game not enabled. Cannot pick a player.")
		elseif not TGNS.Has(captainClients, client) then
			md:ToPlayerNotifyError(player, "You must be a Captain to pick a player.")
		elseif playerPredicate == nil or playerPredicate == "" then
			md:ToPlayerNotifyError(player, "You must specify a player.")
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
			if targetPlayer then
				local targetClient = TGNS.GetClient(targetPlayer)
				if TGNS.Has(captainClients, targetClient) then
					md:ToPlayerNotifyError(player, string.format("%s is a Captain and cannot be picked.", TGNS.GetClientName(targetClient)))
				elseif client == targetClient then
					md:ToPlayerNotifyError(player, "You can pick your friends, and you can pick")
					md:ToPlayerNotifyError(player, "your nose, but you can't pick yourself...")
				else
					setAsPickedIfSpace(targetPlayer, targetClient)
					if TGNS.Has(readyPlayerClients, targetClient) then
						local teamNumber = tonumber(teamNumberCandidate)
						if TGNS.IsNumberWithNonZeroPositiveValue(teamNumber) and TGNS.IsGameplayTeamNumber(teamNumber) then
							md:ToAllNotifyInfo(string.format("%s chose %s for %s.", TGNS.GetClientName(client), TGNS.GetPlayerName(targetPlayer), TGNS.GetTeamName(teamNumber)))
							TGNS.SendToTeam(targetPlayer, teamNumber, true)
						else
							md:ToPlayerNotifyError(player, string.format("'%s' is not recognizable as Marines or Aliens.", teamNumberCandidate))
						end
					else
						md:ToAllNotifyError(string.format("%s did not sh_iwantcaptains and cannot be picked.", TGNS.GetPlayerName(targetPlayer)))
					end
				end
			else
				md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
			end
		end
	end)
	pickCommand:AddParam{ Type = "string", Optional = true }
	pickCommand:AddParam{ Type = "string", Optional = true }
	pickCommand:Help( "<player> Pick the given player for your Captains Game team." )

	local willCaptainsCommand = self:BindCommand("sh_iwillcaptain", "iwillcaptain", function(client)
		local player = TGNS.GetPlayer(client)
		if captainsModeEnabled then
			md:ToPlayerNotifyError(player, "Captains Game is already active.")
		elseif mayVoteYet ~= true then
			md:ToPlayerNotifyError(player, "Captains voting is restricted at the moment.")
		elseif TGNS.IsPlayerSpectator(player) then
			md:ToPlayerNotifyError(player, "You may not use this command as a spectator.")
		elseif Shine.Plugins.mapvote:VoteStarted() then
			md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
		elseif votesAllowedUntil ~= nil and votesAllowedUntil < TGNS.GetSecondsSinceMapLoaded() then
			md:ToPlayerNotifyError(player, "This map's Captains vote failed to pass.")
		else
			local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
			if #playingReadyCaptainClients < 2 then
				addReadyCaptainClient(client)
			else
				md:ToPlayerNotifyError(player, "Too many people have already opted in to be Captain.")
				local playingReadyPlayerClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyPlayerClients, c) end)
				if #playingReadyPlayerClients < MAX_NON_CAPTAIN_PLAYERS then
					md:ToPlayerNotifyError(player, "Opting you in as non-Captain instead...")
					addReadyPlayerClient(client)
				end
			end
		end
	end)
	willCaptainsCommand:Help("Tell you're willing to lead a team in a Captains Game.")

	local wantCaptainsCommand = self:BindCommand("sh_iwantcaptains", "iwantcaptains", function(client)
		local player = TGNS.GetPlayer(client)
		if mayVoteYet ~= true and votesAllowedUntil ~= math.huge then
			md:ToPlayerNotifyError(player, "Captains voting is restricted at the moment.")
		elseif Shine.Plugins.mapvote:VoteStarted() then
			md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
		elseif TGNS.IsPlayerSpectator(player) then
			md:ToPlayerNotifyError(player, "You may not use this command as a spectator.")
		elseif not captainsModeEnabled and votesAllowedUntil ~= nil and votesAllowedUntil < TGNS.GetSecondsSinceMapLoaded() then
			md:ToPlayerNotifyError(player, "This map's Captains vote failed to pass.")
		else
			local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
			if TGNS.Has(playingReadyCaptainClients, client) then
				md:ToPlayerNotifyError(player, "You may not undo your opt-in to be a Captain.")
			else
				if not captainsModeEnabled and #playingReadyCaptainClients < 2 then
					md:ToPlayerNotifyError(player, string.format("Captains must opt-in before players. So far: %s", #playingReadyCaptainClients))
					if #playingReadyCaptainClients == 1 then
						md:ToPlayerNotifyError(player, string.format("%s has opted in to be a Captain. One more needed!", TGNS.GetClientName(playingReadyCaptainClients[1])))
					end
				else
					addReadyPlayerClient(client)
				end
			end
		end
	end, true)
	wantCaptainsCommand:Help("Tell you want to play a Captains Game.")

	local voteAllowCommand = self:BindCommand("sh_allowcaptainsvotes", nil, function(client)
		mayVoteYet = true
		votesAllowedUntil = math.huge
		local player = TGNS.GetPlayer(client)
		md:ToPlayerNotifyInfo(player, "Captains vote time restriction lifted for this map.")
	end)
	voteAllowCommand:Help("Lift time restriction on Captains votes.")

	local voteRestrictCommand = self:BindCommand("sh_roland", nil, function(client)
		mayVoteYet = false
		local player = TGNS.GetPlayer(client)
		md:ToPlayerNotifyInfo(player, "Captains votes disallowed until sh_allowcaptainsvotes.")
		automaticVoteAllowAction = function() end
	end)
	voteRestrictCommand:Help("Disallow Captains votes.")

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
				if TGNS.IsGameInProgress() then
					md:ToAllNotifyInfo("Captains may ready/unready only during the pregame.")
				else
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
							if gameStarted then
								shouldSuppressChatMessageDisplay = true
								md:ToPlayerNotifyError(player, "UN-ready not allowed. Game is starting.")
							else
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
					end
					if bothTeamsAreReady() then
						TGNS.ScheduleAction(5, function()
							if bothTeamsAreReady() and not gameStarted then
								gameStarted = true
								md:ToAllNotifyInfo(string.format("Both teams are ready! Round %s of 2 starts now!", captainsGamesFinished + 1))
								startGame()
							end
						end)
						if not gameStarted then
							md:ToAllNotifyInfo("Both teams are ready? Captains: \"unready\" or prepare to play!")
						end
					end
				end
			end
		end
	end
	if shouldSuppressChatMessageDisplay then
		return ""
	end
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local cancel = false
	if not (force or shineForce) then
		if captainsModeEnabled then
		    local client = TGNS.GetClient(player)
		    if TGNS.IsGameplayTeamNumber(newTeamNumber) then
		    	if TGNS.IsGameInProgress() then
					addReadyPlayerClient(client)
		    	end
		    	if TGNS.Has(readyPlayerClients, client) or TGNS.Has(readyCaptainClients, client) then
					if whenToAllowTeamJoins > TGNS.GetSecondsSinceMapLoaded() then
						md:ToPlayerNotifyError(player, "Captains Game! Stay in the Ready Room and listen for instruction.")
						cancel = true
					end
		    	else
		    		md:ToPlayerNotifyError(player, "Only opted-in players may join teams during Captains Games.")
		    		TGNS.RespawnPlayer(player)
		    		cancel = true
		    	end
		    end
		end
		if cancel then
			return false
		end
	end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
	TGNS.RemoveTempGroup(client, "captainsgame_group")
    if TGNS.IsPlayerReadyRoom(player) then
		if captainsModeEnabled and TGNS.Has(readyPlayerClients, client) then
			TGNS.AddTempGroup(client, "captainsgame_group")
		end
	elseif newTeamNumber == kSpectatorIndex then
		TGNS.RemoveAllMatching(readyPlayerClients, client)
		if captainsModeEnabled then
			md:ToPlayerNotifyInfo(player, getCaptainsGameStateDescription())
		end
    end
    TGNS.UpdateAllScoreboards()
end

function Plugin:ClientConfirmConnect(client)
	if captainsModeEnabled then
		TGNS.ScheduleAction(6, function()
			md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), getCaptainsGameStateDescription())
		end)
	end
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("CAPTAINS")
	self:CreateCommands()

	-- TGNS.RegisterEventHook("LookDownChanged", function(player, isLookingDown)
	-- 	if captainsModeEnabled and not TGNS.IsGameInProgress() then
	-- 		TGNS.UpdateAllScoreboards()
	-- 	end
	-- end)

	mayVoteYet = false
	TGNS.ScheduleAction(115, function() automaticVoteAllowAction() end)

	local originalGetCanPlayerHearPlayer
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result
		local shouldOverrideVoicecomm = captainsModeEnabled and captainsGamesFinished == 0 and TGNS.IsPlayerReadyRoom(speakerPlayer) and TGNS.IsPlayerReadyRoom(listenerPlayer)
		if shouldOverrideVoicecomm then
			local speakerClient = TGNS.GetClient(speakerPlayer)
			result = TGNS.IsClientAdmin(speakerClient) or TGNS.IsClientGuardian(speakerClient) or TGNS.ClientIsInGroup(speakerClient, "captains_group")
			if result ~= true then
				if lastVoiceWarningTimes[speakerClient] == nil or lastVoiceWarningTimes[speakerClient] < Shared.GetTime() - 2 then
					Shine:SendText(speakerClient, Shine.BuildScreenMessage(50, 0.2, 0.25, "You are muted.\nOnly Captains and Admins\nmay use voicecomms while\nteams are being selected.", 3, 0, 255, 0, 0, 4, 0 ) )
					lastVoiceWarningTimes[speakerClient] = Shared.GetTime()
				end
			end
		else
			result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		end
		return result
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("captains", Plugin )