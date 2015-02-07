local md
local captainClients = {}
local captainsModeEnabled
local captainsGamesFinished = 0
local readyTeams = {}
local captainTeamNumbers = {}
local gameStarted
local readyPlayerClients
local readyCaptainClients
local timeAtWhichToForceRoundStart
local SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START = 270
local whenToAllowTeamJoins = 0
local votesAllowedUntil
local mayVoteYet
local automaticVoteAllowAction = function()
	mayVoteYet = true
end
local MAX_NON_CAPTAIN_PLAYERS = 14
local lastVoiceWarningTimes = {}
local plans = {}
local highVolumeMessagesLastShownTime
local bannerDisplayed
local showRemainingTimer
local lastOptInAttemptWhen = {}
local OPT_IN_THROTTLE_IN_SECONDS = 3
local allPlayersWereArtificiallyForcedToReadyRoom
local setSpawnsSummaryText
local confirmedConnectedClients = {}
local captainsGamesWon = {}
local recentCaptainPlayerIds = {}
local oneRemainingDebugHasBeenPrinted = false

local function disableCaptainsMode()
	captainsModeEnabled = false
	TGNS.DoFor(captainClients, function(c)
		if Shine:IsValidClient(c) then
			TGNS.RemoveTempGroup(c, "captains_group")
			TGNS.RemoveTempGroup(c, "teamchoicecaptain_group")
		end
	end)
end

local function getTeamChoiceCaptainClient(clients)
	return clients[1]
end

local function getPlayerChoiceCaptainClient(clients)
	return clients[2]
end

local function startGame()
	if timeAtWhichToForceRoundStart and timeAtWhichToForceRoundStart ~= 0 then
		timeAtWhichToForceRoundStart = 0
		TGNS.ScheduleAction(2, function()
			TGNS.ForceGameStart()
			TGNS.ScheduleAction(kCountDownLength + 2, function()
				readyTeams["Marines"] = false
				readyTeams["Aliens"] = false
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
				message = string.format("Game will force-start in %s.\nType in team chat: !plan", string.DigitalTime(secondsRemaining))
				if secondsRemaining < 30 then
					r = 255
					g = 255
					b = 0
				end
				TGNS.ScheduleAction(1, warnOfPendingCaptainsGameStart)
			else
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

local function remindTeam(teamName, teamNumber)
	if captainsModeEnabled and not (TGNS.IsGameInProgress() or readyTeams[teamName]) then
		local otherTeamName = TGNS.GetOtherPlayingTeamName(teamName)
		md:ToTeamNotifyInfo(teamNumber, string.format("Play will begin when %s 'ready' in chat.", readyTeams[otherTeamName] and "your team types" or "both teams type"))
		TGNS.ScheduleAction(readyTeams[otherTeamName] and 20 or 40, function() remindTeam(teamName, teamNumber) end)
	end
end

local function remindTeams()
	remindTeam("Marines", kMarineTeamType)
	remindTeam("Aliens", kAlienTeamType)
end

local function setTimeAtWhichToForceRoundStart()
	timeAtWhichToForceRoundStart = TGNS.GetSecondsSinceMapLoaded() + SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START + 30 + (captainsGamesFinished == 0 and 60 or 0)
	TGNS.ScheduleAction(29, warnOfPendingCaptainsGameStart)
	TGNS.ScheduleAction(30, remindTeams)
end

local function showRoster(clients, renderClients, titleMessageId, column1MessageId, column2MessageId, titleY, titleText)
	local columnsY = titleY + 0.05
	local clientNameGetter = function(c)
		local nameToDisplay = string.format("%s%s%s", TGNS.IsPlayerAFK(TGNS.GetPlayer(c)) and "!" or "", TGNS.GetClientName(c), TGNS.PlayerAction(c, TGNS.IsPlayerSpectator) and " (Spec)" or "")
		return TGNS.Truncate(nameToDisplay, 16)
	end
	local names = TGNS.Select(clients, clientNameGetter)
	TGNS.ShowPanel(names, renderClients, titleMessageId, column1MessageId, column2MessageId, titleY, titleText, #names, 3, "(None)")
end

local function showPickables()
	if not TGNS.IsGameInProgress() then
		if captainsGamesFinished == 0 then
			local allClients = TGNS.GetClientList()
			local readyRoomClients = TGNS.GetReadyRoomClients()
			local teamChoiceCaptainClient = (#captainClients > 0 and Shine:IsValidClient(getTeamChoiceCaptainClient(captainClients))) and getTeamChoiceCaptainClient(captainClients) or nil
			local playerChoiceCaptainClient = (#captainClients > 1 and Shine:IsValidClient(getPlayerChoiceCaptainClient(captainClients))) and getPlayerChoiceCaptainClient(captainClients) or nil
			if teamChoiceCaptainClient and playerChoiceCaptainClient then
				local teamChoiceCaptainName = TGNS.GetClientName(teamChoiceCaptainClient)
				local playerChoiceCaptainName = TGNS.GetClientName(playerChoiceCaptainClient)
				TGNS.DoFor(readyRoomClients, function(c)
					Shine:SendText(c, Shine.BuildScreenMessage(58, 0.75, 0.1, string.format("%s: Team/Spawns Choice\n%s: Player Choice", teamChoiceCaptainName, playerChoiceCaptainName), 3, 0, 255, 0, 0, 2, 0))
				end)
				if teamChoiceCaptainClient and TGNS.ClientIsOnPlayingTeam(teamChoiceCaptainClient) then
					local teamChoiceCaptainTeamNumber = TGNS.GetClientTeamNumber(teamChoiceCaptainClient)
					local teamChoiceCaptainTeammateClients = TGNS.GetTeamClients(teamChoiceCaptainTeamNumber, TGNS.GetPlayerList())
					TGNS.DoFor(teamChoiceCaptainTeammateClients, function(c)
						local truncatedTeamChoiceCaptainName = TGNS.Truncate(teamChoiceCaptainName, 16)
						local message = setSpawnsSummaryText and string.format("%s has selected\nthe game's spawn locations!", truncatedTeamChoiceCaptainName) or string.format("%s: Select Spawns!\nM > Captains > sh_setspawns", truncatedTeamChoiceCaptainName)
						Shine:SendText(c, Shine.BuildScreenMessage(58, 0.75, 0.1, message, 3, 0, 255, 0, 0, 2, 0))
					end)
				end
			end
			local optedInClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.ClientIsInGroup(c, "captainsgame_group") end)
			local notOptedInClients = TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.ClientIsInGroup(c, "captainsgame_group") and not TGNS.ClientIsInGroup(c, "captains_group") and not TGNS.ClientIsOnPlayingTeam(c) end)

			local renderCaptainClients = TGNS.Where(allClients, function(c) return TGNS.Has(captainClients, c) end)
			local renderOtherClients = TGNS.Where(allClients, function(c) return not TGNS.Has(renderCaptainClients, c) end)

			TGNS.SortDescending(optedInClients, TGNS.GetClientHiveSkillRank)
			showRoster(optedInClients, renderCaptainClients, 52, 53, 54, 0.25, "Opted In")

			TGNS.SortAscending(optedInClients, TGNS.GetClientId)
			showRoster(optedInClients, renderOtherClients, 52, 53, 54, 0.25, "Opted In")

			showRoster(notOptedInClients, allClients, 55, 56, 57, 0.55, "Not Opted In")

			TGNS.DoFor(readyRoomClients, function(c)
				local message
				if TGNS.Has(captainClients, c) then
					message = "Captains: Your 'Opted In' list is sorted by Hive Skill rank.\nTop row is highest (left, right), then next row, etc, etc.\nDon't put too much stock in this ranking."
					message = "Captains:\n\nThe game has sorted your 'Opted In' player list\nby skill level. The top row is highest (left, right),\nand then the next row (left, right), and so on...\n\nThis sort isn't perfect. Choose as you like."
				else
					message = #notOptedInClients > 0 and "To opt-in:\nPress M (to show menu)\nChoose 'Captains'\nChoose 'sh_iwantcaptains'" or " "
				end
				Shine:SendText(c, Shine.BuildScreenMessage(59, 0.75, 0.70, message, 3, 0, 255, 0, 0, 1, 0 ) )
			end)

			TGNS.ScheduleAction(1, showPickables)
		end
	end
end

local function swapCaptains()
	local newCaptainClients = {}
	table.insert(newCaptainClients, getPlayerChoiceCaptainClient(captainClients))
	table.insert(newCaptainClients, getTeamChoiceCaptainClient(captainClients))
	captainClients = newCaptainClients
end

local function enableCaptainsMode(nameOfEnabler, captain1Client, captain2Client)
	local randomizedCaptainClients = TGNS.GetRandomizedElements({captain1Client,captain2Client})
	captainClients = { randomizedCaptainClients[1], randomizedCaptainClients[2] }
	if Balance and Balance.GetClientWeight then
		if Balance.GetClientWeight(getPlayerChoiceCaptainClient(captainClients)) > Balance.GetClientWeight(getTeamChoiceCaptainClient(captainClients)) then
			swapCaptains()
		end
	end
	TGNS.AddTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
	captainTeamNumbers[getTeamChoiceCaptainClient(captainClients)] = 1
	captainTeamNumbers[getPlayerChoiceCaptainClient(captainClients)] = 2
	captainsModeEnabled = true
	setTimeAtWhichToForceRoundStart()
	captainsGamesFinished = 0
	TGNS.DoFor(captainClients, function(c)
		TGNS.AddTempGroup(c, "captains_group")
		-- TGNS.ScheduleAction(30, function() TGNS.PlayerAction(c, function(p) md:ToPlayerNotifyInfo(p, "Captains: Use sh_setteam if you need to force anyone to a team.") end) end)
	end)
	TGNS.ScheduleAction(0, function()
		md:ToAllNotifyInfo(string.format("%s enabled Captains Game! Pick teams and play two rounds!", nameOfEnabler))
	end)
	allPlayersWereArtificiallyForcedToReadyRoom = true
	Shine.Plugins.mapvote.EndGame = function(mapVotePlugin) end
	TGNS.ForcePlayersToReadyRoom(TGNS.Where(TGNS.GetPlayerList(), function(p) return not TGNS.IsPlayerSpectator(p) end))
	whenToAllowTeamJoins = TGNS.GetSecondsSinceMapLoaded() + 20
	votesAllowedUntil = nil
	TGNS.ScheduleAction(2, showPickables)
	Shine.Plugins.afkkick.Config.KickTime = 20
	TGNS.DoFor(TGNS.GetClientList(), function(c)
		Shine:SendText(c, Shine.BuildScreenMessage(93, 0.5, 0.90, " ", 5, 0, 255, 0, 1, 1, 0))
		Shine:SendText(c, Shine.BuildScreenMessage(94, 0.5, 0.80, " ", 5, 0, 255, 0, 1, 1, 0))
	end)
	TGNS.ScheduleAction(2, function()
		allPlayersWereArtificiallyForcedToReadyRoom = false
	end)
	Shine.Plugins.push:Push("tgns-captains", "TGNS Captains Game Starting", string.format("%s on %s\\n\\nServer Info: http://rr.tacticalgamer.com/ServerInfo", TGNS.GetCurrentMapName(), TGNS.GetSimpleServerName()))
	TGNS.DoFor(TGNS.GetPlayerList(), TGNS.AlertApplicationIconForPlayer)
end

local function showBanner(headline)
	TGNS.DoFor(TGNS.GetClientList(), function(c)
		Shine:SendText(c, Shine.BuildScreenMessage(41, 0.5, 0.2, string.format("Captains?%s", headline), 5, 0, 255, 0, 1, 3, 0 ) )
	end)
	bannerDisplayed = true
end

local function getAdjustedNumberOfNeededReadyPlayerClients(playingClients)
	local numberOfNeededReadyPlayerClients = TGNS.RoundPositiveNumberDown((.82 * #playingClients) - 2)
	numberOfNeededReadyPlayerClients = numberOfNeededReadyPlayerClients >= 0 and numberOfNeededReadyPlayerClients or 0
	local result = numberOfNeededReadyPlayerClients <= 14 and numberOfNeededReadyPlayerClients or 14
	return result
end

local function getCaptainCallText(captainName)
	local result = string.format("%s will Captain! Who else will Captain?", captainName)
	return result
end

local function getDescriptionOfWhatElseIsNeededToPlayCaptains(headlineReadyClient, playingClients, playingReadyPlayerClients, numberOfPlayingReadyCaptainClients, firstCaptainName, secondCaptainName)
	local result = ""
	if not captainsModeEnabled then
		local adjustedNumberOfNeededReadyPlayerClients = getAdjustedNumberOfNeededReadyPlayerClients(playingClients)
		local remaining = adjustedNumberOfNeededReadyPlayerClients - #playingReadyPlayerClients
		if not captainsModeEnabled and numberOfPlayingReadyCaptainClients == 1 then
			result = getCaptainCallText(firstCaptainName)
			--md:ToAllNotifyInfo(result)
		elseif remaining > 0 then
			local headline = string.format(" (%s vs %s)", firstCaptainName, secondCaptainName)
			if not bannerDisplayed then
				showBanner(headline)
			end
			local howManyNeededMessage = votesAllowedUntil and string.format("%s more needed!", remaining) or ""
			result = string.format("%s wants Captains%s! %s", TGNS.GetClientName(headlineReadyClient), headline, howManyNeededMessage)

			if remaining == 1 and not oneRemainingDebugHasBeenPrinted then
				TGNS.PrintTable(playingReadyPlayerClients, "playingReadyPlayerClients", TGNS.DebugPrint)
				oneRemainingDebugHasBeenPrinted = true
			end

		end
	end
	return result
end

local function updateCaptainsReadyProgress(readyClient)
	local playingClients = TGNS.GetClients(TGNS.Where(TGNS.GetPlayerList(), function(p) return not (TGNS.IsPlayerSpectator(p) or TGNS.IsPlayerAFK(p)) end))
	local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
	local twoCaptainsReady = #playingReadyCaptainClients > 1
	local firstCaptainName = #playingReadyCaptainClients > 0 and TGNS.GetClientName(playingReadyCaptainClients[1]) or "???"
	local secondCaptainName = twoCaptainsReady and TGNS.GetClientName(playingReadyCaptainClients[2]) or "???"
	local playingReadyPlayerClients = TGNS.Where(playingClients, function(c) return TGNS.Has(readyPlayerClients, c) end)
	local descriptionOfWhatElseIsNeededToPlayCaptains = getDescriptionOfWhatElseIsNeededToPlayCaptains(readyClient, playingClients, playingReadyPlayerClients, #playingReadyCaptainClients, firstCaptainName, secondCaptainName)
	if TGNS.HasNonEmptyValue(descriptionOfWhatElseIsNeededToPlayCaptains) then
		local readyClientIsCaptain = TGNS.Has(playingReadyCaptainClients, readyClient)
		local message = string.format("You're marked as ready to play%s a Captains Game.", readyClientIsCaptain and " (and pick your team for)" or "")
		md:ToPlayerNotifyInfo(TGNS.GetPlayer(readyClient), message)
		-- if highVolumeMessagesLastShownTime == nil or highVolumeMessagesLastShownTime < Shared.GetTime() - 5 or readyClientIsCaptain then
			-- md:ToAllNotifyInfo(descriptionOfWhatElseIsNeededToPlayCaptains)
			-- highVolumeMessagesLastShownTime = Shared.GetTime()
		-- end
		TGNS.DoFor(TGNS.GetClientList(), function(c)
			Shine:SendText(TGNS.GetClient(player), Shine.BuildScreenMessage(93, 0.5, 0.75, descriptionOfWhatElseIsNeededToPlayCaptains, votesAllowedUntil and 120 or 10, 0, 255, 0, 1, 2, 0))
			local secondLineMessage = "Captains play two rounds after picking a team and Commander."
			if (votesAllowedUntil == math.huge and twoCaptainsReady) or (votesAllowedUntil ~= math.huge and twoCaptainsReady and #playingReadyPlayerClients == 0) then
				secondLineMessage = "Press 'M > Captains > sh_iwantcaptains' if you want to play Captains."
			end
			Shine:SendText(TGNS.GetClient(player), Shine.BuildScreenMessage(94, 0.5, 0.80, secondLineMessage, votesAllowedUntil and 120 or 10, 0, 255, 0, 1, 1, 0))
		end)
	else
		if not captainsModeEnabled then
			enableCaptainsMode(string.format("%s and %s", TGNS.GetClientName(playingReadyCaptainClients[1]), TGNS.GetClientName(playingReadyCaptainClients[2])), playingReadyCaptainClients[1], playingReadyCaptainClients[2])
		end
	end
end

local function getVoteSecondsRemaining()
	local result = votesAllowedUntil - TGNS.GetSecondsSinceMapLoaded()
	return result
end

local function announceTimeRemaining()
	if not captainsModeEnabled then
		local secondsRemaining = getVoteSecondsRemaining()
		if secondsRemaining > 1 then
			local timeLeftAdvisory = votesAllowedUntil == math.huge and "" or string.format("%s left.", string.TimeToString(secondsRemaining))
			local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
			local firstCaptainName = #playingReadyCaptainClients > 0 and TGNS.GetClientName(playingReadyCaptainClients[1]) or "???"
			local secondCaptainName = #playingReadyCaptainClients > 1 and TGNS.GetClientName(playingReadyCaptainClients[2]) or "???"
			-- md:ToAllNotifyInfo(string.format("Press M > Captains if you want to play Captains (%s & %s). %s", firstCaptainName, secondCaptainName, timeLeftAdvisory))
			TGNS.DoFor(TGNS.GetClientList(), function(c)
				Shine:SendText(c, Shine.BuildScreenMessage(92, 0.5, 0.85, string.format("Press 'M > Captains > sh_iwantcaptains' if you want to play Captains (%s vs %s). %s", firstCaptainName, secondCaptainName, timeLeftAdvisory), 10, 0, 255, 0, 1, 1, 0))
			end)
			TGNS.ScheduleAction(1, announceTimeRemaining)
		else
			TGNS.ScheduleAction(1, function()
				if not captainsModeEnabled then
					TGNS.DoFor(TGNS.GetClientList(), function(c)
						Shine:SendText(c, Shine.BuildScreenMessage(92, 0.5, 0.85, "Captains vote expired.", 5, 255, 0, 0, 1, 1, 0))
					end)
					Shine:SendText(c, Shine.BuildScreenMessage(93, 0.5, 0.90, " ", 5, 0, 255, 0, 1, 1, 0))
					Shine:SendText(c, Shine.BuildScreenMessage(94, 0.5, 0.80, " ", 5, 0, 255, 0, 1, 1, 0))
					-- md:ToAllNotifyInfo("Captains vote expired.")
				end
			end)
		end
	end
end

local function addReadyPlayerClient(client)
	if votesAllowedUntil == nil then
		votesAllowedUntil = TGNS.GetSecondsSinceMapLoaded() + 62
		TGNS.DoFor(readyPlayerClients, function(c)
			if Shine:IsValidClient(c) then
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), "You are now opted-in to play a Captains game.")
			end
		end)
		TGNS.ScheduleAction(1, announceTimeRemaining)
	end
	readyPlayerClients = readyPlayerClients or {}
	if TGNS.Has(readyPlayerClients, client) then
		updateCaptainsReadyProgress(client)
	else
		local playingReadyPlayerClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyPlayerClients, c) end)
		if #playingReadyPlayerClients < MAX_NON_CAPTAIN_PLAYERS then
			table.insertunique(readyPlayerClients, client)
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
				if TGNS.PlayerAction(client, TGNS.IsPlayerReadyRoom) and not TGNS.ClientIsInGroup(client, "captainsgame_group") then
					TGNS.AddTempGroup(client, "captainsgame_group")
					md:ToAllNotifyInfo(string.format("%s wants Captains, too!", TGNS.GetClientName(client)))
					-- TGNS.DoFor(TGNS.GetClientList(), function(c)
					-- 	Shine:SendText(c, Shine.BuildScreenMessage(93, 0.5, 0.90, string.format("%s wants Captains, too!", TGNS.GetClientName(client)), 5, 0, 255, 0, 1, 1, 0))
					-- end)
				end
			end
		end
	end
end

local function addReadyCaptainClient(client)
	readyCaptainClients = readyCaptainClients or {}
	if not TGNS.Has(readyCaptainClients, client) then
		table.insertunique(readyCaptainClients, client)
		TGNS.RemoveAllMatching(readyPlayerClients, client)
		if #readyCaptainClients == 2 then
			md:ToAllConsole("Two captains are opted-in. You may now opt-in to play.")
		end
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
	if not allPlayersWereArtificiallyForcedToReadyRoom then
		if captainsModeEnabled then
			if winningTeam == nil then
				TGNS.DoFor(captainClients, function(c)
					captainsGamesWon[c] = captainsGamesWon[c] or 0
					captainsGamesWon[c] = captainsGamesWon[c] + 1
					Shine.Plugins.scoreboard:SetTeamScoresData(c, captainsGamesWon[c])
				end)
			else
				local winningCaptainClient = TGNS.SingleOrNil(TGNS.GetTeamClients(winningTeam:GetTeamNumber()), function(c) return TGNS.Has(captainClients, c) end)
				if winningCaptainClient ~= nil then
					captainsGamesWon[winningCaptainClient] = captainsGamesWon[winningCaptainClient] or 0
					captainsGamesWon[winningCaptainClient] = captainsGamesWon[winningCaptainClient] + 1
					Shine.Plugins.scoreboard:SetTeamScoresData(winningCaptainClient, captainsGamesWon[winningCaptainClient])
				end
			end
			gameStarted = false
			captainsGamesFinished = captainsGamesFinished + 1
			local message = "Time for Round 2! Everyone switch teams!"
			TGNS.DoForPairs(captainTeamNumbers, function(client, teamNumber)
				captainTeamNumbers[client] = captainTeamNumbers[client] == 1 and 2 or 1
			end)
			if captainsGamesFinished < 2 then
				setTimeAtWhichToForceRoundStart()
			else
				disableCaptainsMode()
				TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
					Shine.Plugins.mapvote:StartVote(true)
				end)
				message = "Both rounds of Captains Game finished! Thanks for playing! -- TacticalGamer.com"
			end
			TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
				//swapTeamsAfterDelay(3)
				md:ToAllNotifyInfo(message)
			end)
			TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 4, function()
				TGNS.DoFor(TGNS.GetPlayers(TGNS.GetStrangersClients(TGNS.GetPlayerList())), function(p)
					md:ToPlayerNotifyInfo(p, "If you enjoy playing here, be sure to bookmark this TacticalGamer.com server!")
				end)
			end)
		else
			TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 65, function()
				if Shine.Plugins.mapvote:VoteStarted() then
					md:ToAllNotifyInfo("Join us Friday nights for Captains Games! Passworded, scrim-style gameplay")
					md:ToAllNotifyInfo("from ~7PM 'til. Read more in the TGNS Forums: http://rr.tacticalgamer.com/Community")
				end
			end)
			readyCaptainClients = {}
			readyPlayerClients = {}
		end
	end
end

local function displayPlansToAll()
	TGNS.DoFor(TGNS.GetPlayerList(), function(targetPlayer)
		local targetPlayerIsReadyRoom = TGNS.IsPlayerReadyRoom(targetPlayer)
		local targetPlayerIsSpectator = TGNS.IsPlayerSpectator(targetPlayer)
		--Shared.Message(string.format("%s: %s %s", TGNS.GetPlayerName(targetPlayer), targetPlayerIsReadyRoom, targetPlayerIsSpectator))
		TGNS.DoFor(TGNS.GetPlayerList(), function(sourcePlayer)
			local planToSend = ""
			local sourceClient = TGNS.GetClient(sourcePlayer)
			local playersAreTeammates = TGNS.PlayersAreTeammates(targetPlayer, sourcePlayer)
			if sourceClient and (playersAreTeammates or targetPlayerIsSpectator) and not targetPlayerIsReadyRoom then
				planToSend = plans[sourceClient] or ""
			end
			--Shared.Message(string.format("-- %s: '%s'", TGNS.GetPlayerName(sourcePlayer), planToSend))
			TGNS.SendNetworkMessageToPlayer(targetPlayer, Shine.Plugins.scoreboard.PLAYER_NOTE, {c=sourcePlayer:GetClientIndex(), n=TGNS.Truncate(planToSend, 8)})
		end)
	end)
end

function Plugin:CreateCommands()

	local resetTimerCommand = self:BindCommand("sh_resetcaptainstimer", nil, function(client)
		if timeAtWhichToForceRoundStart and timeAtWhichToForceRoundStart > 0 then
			timeAtWhichToForceRoundStart = TGNS.GetSecondsSinceMapLoaded() + SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START + 30 + (captainsGamesFinished == 0 and 60 or 0)
			md:ToClientConsole(client, "Captains Timer reset.")
		else
			md:ToClientConsole(client, "ERROR: No timer to reset.")
		end
	end)
	resetTimerCommand:Help("Reset the Captains pre-game countdown timer.")

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

	local planCommand = self:BindCommand("sh_plan", "plan", function(client, plan)
		local player = TGNS.GetPlayer(client)
		-- if captainsModeEnabled and captainsGamesFinished < 2 then
			if TGNS.PlayerIsOnPlayingTeam(player) then
				if not TGNS.IsGameInProgress() then
					if TGNS.HasNonEmptyValue(plan) then
						plans[client] = plan
						displayPlansToAll()
					else
						md:ToPlayerNotifyInfo(player, "When !plan-ing, describe your plan (gorge, comm, lerk, etc).")
						md:ToPlayerNotifyInfo(player, "For example, put 'gorge' on your scoreboard row: !plan gorge")
					end
				else
					md:ToPlayerNotifyError(player, "Planning notes are not displayed during gameplay.")
				end
			else
				md:ToPlayerNotifyError(player, "You must be on a team to plan.")
			end
		-- else
		--	md:ToPlayerNotifyError(player, "No Captains Game is being planned or played now.")
		-- end
	end, true)
	planCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
	planCommand:Help("<plan> Announce your Captains Game plan.")

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
		-- elseif TGNS.IsGameInProgress() and not TGNS.ClientIsOnPlayingTeam(client) then
		-- 	md:ToPlayerNotifyError(player, "You must be on a team to opt-in during gameplay.")
		elseif mayVoteYet ~= true and not TGNS.IsGameInProgress() then
			md:ToPlayerNotifyError(player, "Captains voting is restricted at the moment.")
		elseif TGNS.IsPlayerSpectator(player) then
			md:ToPlayerNotifyError(player, "You may not use this command as a spectator.")
		elseif Shine.Plugins.mapvote:VoteStarted() then
			md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
		elseif votesAllowedUntil ~= nil and votesAllowedUntil < TGNS.GetSecondsSinceMapLoaded() then
			md:ToPlayerNotifyError(player, "This map's Captains vote failed to pass.")
		elseif TGNS.IsGameInProgress() and TGNS.GetCurrentGameDurationInSeconds() > 15 and votesAllowedUntil ~= math.huge then
			md:ToPlayerNotifyError(player, "Game duration > 0:15. It's too late this game to opt-in as a Captain.")
		else
			local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
			if #playingReadyCaptainClients < 2 or TGNS.Has(readyCaptainClients, client) then
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
		local addIfSupportingMember = function(optingInClient)
			if TGNS.IsClientSM(optingInClient) and not TGNS.Has(readyPlayerClients, optingInClient) then
				readyPlayerClients = readyPlayerClients or {}
				table.insertunique(readyPlayerClients, optingInClient)
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(optingInClient), "You will be automatically opted-in when votes are allowed. Thank you for being a Supporting Member!")
			end
		end
		local addIfRecentCaptain = function(optingInClient)
			if TGNS.Has(recentCaptainPlayerIds, TGNS.GetClientSteamId(optingInClient)) and not TGNS.Has(readyPlayerClients, optingInClient) then
				readyPlayerClients = readyPlayerClients or {}
				table.insertunique(readyPlayerClients, optingInClient)
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(optingInClient), "You will be automatically opted-in when votes are allowed. Thank you for recently being a Captain!")
			end
		end
		if TGNS.GetSecondsSinceMapLoaded() - (lastOptInAttemptWhen[client] or 0) < OPT_IN_THROTTLE_IN_SECONDS then
			md:ToPlayerNotifyError(player, string.format("Every opt-in attempt (including this one) resets a %s-second cooldown.", OPT_IN_THROTTLE_IN_SECONDS))
		-- elseif TGNS.IsGameInProgress() and not TGNS.ClientIsOnPlayingTeam(client) then
		--  	md:ToPlayerNotifyError(player, "You must be on a team to opt-in during gameplay.")
		elseif mayVoteYet ~= true and votesAllowedUntil ~= math.huge and not TGNS.IsGameInProgress() then
			md:ToPlayerNotifyError(player, "Captains voting is restricted at the moment.")
			addIfRecentCaptain(client)
			addIfSupportingMember(client)
		elseif Shine.Plugins.mapvote:VoteStarted() then
			md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
		elseif TGNS.IsPlayerSpectator(player) then
			md:ToPlayerNotifyError(player, "You may not use this command as a spectator.")
		elseif not captainsModeEnabled and votesAllowedUntil ~= nil and votesAllowedUntil < TGNS.GetSecondsSinceMapLoaded() then
			md:ToPlayerNotifyError(player, "This map's Captains vote failed to pass.")
		elseif TGNS.IsGameInProgress() and TGNS.GetCurrentGameDurationInSeconds() > 30 and (readyPlayerClients == nil or #readyPlayerClients == 0) and votesAllowedUntil ~= math.huge then
			md:ToPlayerNotifyError(player, "Game duration > 0:30. It's too late to start opting in players.")
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
					addIfRecentCaptain(client)
					addIfSupportingMember(client)
				else
					addReadyPlayerClient(client)
				end
			end
		end
		lastOptInAttemptWhen[client] = TGNS.GetSecondsSinceMapLoaded()
	end, true)
	wantCaptainsCommand:Help(string.format("Tell the server you want to play a Captains Game (cooldown: %s seconds).", OPT_IN_THROTTLE_IN_SECONDS))

	local swapCaptainsCommand = self:BindCommand( "sh_swapcaptains", nil, function(client)
		local errorMessage
		if captainClients and #captainClients == 2 then
			local matchingCaptainClients = TGNS.GetClientList(function(c) return c == getPlayerChoiceCaptainClient(captainClients) or c == getTeamChoiceCaptainClient(captainClients) end)
			if #matchingCaptainClients == 2 then
				TGNS.RemoveTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
				swapCaptains()
				TGNS.AddTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
				md:ToClientConsole(client, string.format("Clients swapped. %s is now Player Choice. %s is now Team Choice.", TGNS.GetClientName(getPlayerChoiceCaptainClient(captainClients)), TGNS.GetClientName(getTeamChoiceCaptainClient(captainClients))))
			else
				errorMessage = "Unable to find two Captain clients among connected clients."
			end
		else
			errorMessage = "There are fewer than two Captains presently designated."
		end
		if errorMessage then
			md:ToClientConsole(client, string.format("ERROR: %s", errorMessage))
		end
	end)
	swapCaptainsCommand:Help( "Swap roles between the two Captains (Player Choice <-> Team Choice)." )

	local setSpawnsCommand = self:BindCommand("sh_setspawns", nil, function(client, spawnSelectionIndex)
		spawnSelectionIndex = tonumber(spawnSelectionIndex)
		local player = TGNS.GetPlayer(client)
		local ssoData = Shine.Plugins.spawnselectionoverrides:GetCurrentMapSpawnSelectionOverridesData()
		local errorMessage
		if (captainsModeEnabled and captainsGamesFinished == 0 and not TGNS.IsGameInProgress()) or TGNS.IsClientAdmin(client) then
			if spawnSelectionIndex then
				if spawnSelectionIndex >= 1 and spawnSelectionIndex <= #ssoData then
					local spawnSelectionOverride = {}
					table.insert(spawnSelectionOverride, ssoData[spawnSelectionIndex].spawnSelectionOverride)
					Shine.Plugins.spawnselectionoverrides:ForceOverrides(spawnSelectionOverride)
					setSpawnsSummaryText = ssoData[spawnSelectionIndex].summaryTextLineDelimited
					local clientIsCaptain = (#captainClients > 0 and getPlayerChoiceCaptainClient(captainClients) == client) or (#captainClients > 1 and getTeamChoiceCaptainClient(captainClients) == client)
					if clientIsCaptain and TGNS.ClientIsOnPlayingTeam(client) then
						local clientTeamNumber = TGNS.GetClientTeamNumber(client)
						md:ToTeamNotifyInfo(clientTeamNumber, string.format("%s (Captain) has set first-round spawns: %s", TGNS.GetClientName(client), ssoData[spawnSelectionIndex].summaryText))
					else
						md:ToPlayerNotifyInfo(player, string.format("Spawn set: %s", ssoData[spawnSelectionIndex].summaryText))
					end
				else
					errorMessage = string.format("'%s' is not a valid spawn selection override index number.", spawnSelectionIndex)
				end
			else
				errorMessage = "You must specify a spawn selection override index number."
			end
		else
			errorMessage = "You may manually set map spawns only before the first Captains round."
		end
		if errorMessage then
			-- print errorMessage
			md:ToClientConsole(client, string.format("ERROR: %s", errorMessage))
			md:ToClientConsole(client, "usage: sh_setspawns <spawn selection override index number>")
			md:ToClientConsole(client, " e.g.: sh_setspawns 1")
			if #ssoData > 0 then
				md:ToClientConsole(client, "Available spawn pair options:")
				TGNS.DoFor(ssoData, function(d)
					md:ToClientConsole(client, string.format("%s. %s", d.spawnSelectionIndex, d.summaryText))
				end)
			else
				md:ToPlayerNotifyError(player, "There are no spawn selection overrides configured for this map.")
			end
		end
	end)
	setSpawnsCommand:AddParam{ Type = "string", Optional = true }
	setSpawnsCommand:Help("Set spawns for the next game. Execute without parameters for more help.")

	local voteAllowCommand = self:BindCommand("sh_allowcaptainsvotes", nil, function(client)
		mayVoteYet = true
		votesAllowedUntil = math.huge
		local player = TGNS.GetPlayer(client)
		md:ToPlayerNotifyInfo(player, "Captains vote time restriction lifted for this map.")
	end)
	voteAllowCommand:Help("Lift time restriction on Captains votes.")

	local voteRestrictCommand = self:BindCommand("sh_roland", nil, function(client)
		mayVoteYet = false
		votesAllowedUntil = nil
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
							md:ToAllNotifyInfo("Are both teams ready? Captains: \"unready\" or prepare to play!")
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
		    local serverIsUpdatingToReadyRoom = Shine.Plugins.updatetoreadyroomhelper and Shine.Plugins.updatetoreadyroomhelper:IsServerUpdatingToReadyRoom()
			if TGNS.IsPlayerSpectator(player) and captainsGamesFinished == 1 and serverIsUpdatingToReadyRoom then
		    	cancel = true
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
		if TGNS.Has(readyPlayerClients, client) then
			md:ToPlayerNotifyInfo(player, "Joining Spectator has removed your Captains opt-in.")
			TGNS.RemoveAllMatching(readyPlayerClients, client)
		end
		if captainsModeEnabled then
			md:ToPlayerNotifyInfo(player, getCaptainsGameStateDescription())
			Shine.Plugins.scoreboard:SendTeamScoresDatas()
		end
	elseif TGNS.IsGameplayTeamNumber(newTeamNumber) and captainsModeEnabled and TGNS.Has(captainClients, client) then
		Shine.Plugins.scoreboard:SetTeamScoresData(client, captainsGamesWon[client])
    end
    if captainsModeEnabled and not TGNS.IsGameInProgress() then
    	plans[client] = nil
	    displayPlansToAll()
    end
end

function Plugin:ClientConfirmConnect(client)
	TGNS.ScheduleAction(6, function()
		if Shine:IsValidClient(client) then
			local message
			if captainsModeEnabled then
				message = getCaptainsGameStateDescription()
			elseif TGNS.Has(recentCaptainPlayerIds, TGNS.GetClientSteamId(client)) and votesAllowedUntil == nil then
				message = "Thanks for being a Captain recently! Opt-in anytime with sh_iwantcaptains, if you like."
			end
			if TGNS.HasNonEmptyValue(message) then
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), message)
			end
		end
	end)
	table.insert(confirmedConnectedClients, client)
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("CAPTAINS")
	self:CreateCommands()

	mayVoteYet = false
	local whenPlayersWereLastStillConnecting
	local mayVoteYetChecker
	mayVoteYetChecker = function()
		if not mayVoteYet then
			if TGNS.GetSecondsSinceMapLoaded() < 115 and Server.GetNumPlayersTotal() > #TGNS.GetClientList(function(c) return TGNS.Has(confirmedConnectedClients, c) end) then
				whenPlayersWereLastStillConnecting = TGNS.GetSecondsSinceMapLoaded()
			end
			if whenPlayersWereLastStillConnecting == nil or TGNS.GetSecondsSinceMapLoaded() - whenPlayersWereLastStillConnecting > 5 then
				automaticVoteAllowAction()
			end
			TGNS.ScheduleAction(2, mayVoteYetChecker)
		end
	end
	TGNS.ScheduleAction(10, mayVoteYetChecker)

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

	TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
		if captainsModeEnabled then
			local chairLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kMarineTeamType)):GetLocationName()
			local hiveLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kAlienTeamType)):GetLocationName()
			local spawnSelectionOverrides = {}
			local spawnSelectionOverride = {chairLocationName, hiveLocationName}
			table.insert(spawnSelectionOverrides, spawnSelectionOverride)
			Shine.Plugins.spawnselectionoverrides:ForceOverrides(spawnSelectionOverrides)
			TGNS.RemoveTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
		end
		plans = {}
		displayPlansToAll()
	end)

	local originalGetCanJoinTeamNumber
	originalGetCanJoinTeamNumber = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanJoinTeamNumber", function(self, teamNumber)
		local result = captainsModeEnabled and true or originalGetCanJoinTeamNumber(self, teamNumber)
		return result
	end)

	-- TGNS.RegisterEventHook("EverySecond", function()
	-- 	local secondsRemaining = getVoteSecondsRemaining()
	-- 	local playingReadyPlayerClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyPlayerClients, c) end)
	-- 	local adjustedNumberOfNeededReadyPlayerClients = getAdjustedNumberOfNeededReadyPlayerClients(playingReadyPlayerClients)
	-- end)

	local originalResetGame
	originalResetGame = TGNS.ReplaceClassMethod("NS2Gamerules", "ResetGame", function(gamerules)
		local teamChoiceCaptainClient = getTeamChoiceCaptainClient(captainClients)
		if captainsModeEnabled and teamChoiceCaptainClient then
			TGNS.RemoveTempGroup(teamChoiceCaptainClient, "teamchoicecaptain_group")
		end
		originalResetGame(gamerules)
		if captainsModeEnabled and teamChoiceCaptainClient and captainsGamesFinished == 0 then
			TGNS.RemoveTempGroup(teamChoiceCaptainClient, "teamchoicecaptain_group")
		end
		-- TGNS.ScheduleAction(2, function()
		-- 	local chairLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kMarineTeamType)):GetLocationName()
		-- 	local hiveLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kAlienTeamType)):GetLocationName()
		-- 	md:ToAllNotifyInfo(string.format("Marines: %s - Aliens: %s", chairLocationName, hiveLocationName))
		-- end)
	end)

	TGNS.ScheduleAction(10, function()
		local url = string.format("%s&n=%s", TGNS.Config.RecentCaptainPlayerIdsEndpointBaseUrl, TGNS.GetSimpleServerName())
		TGNS.GetHttpAsync(url, function(recentCaptainPlayerIdsResponseJson)
			local recentCaptainPlayerIdsResponse = json.decode(recentCaptainPlayerIdsResponseJson) or {}
			if recentCaptainPlayerIdsResponse.success then
				if #recentCaptainPlayerIdsResponse.result > 0 then
					TGNS.DoFor(recentCaptainPlayerIdsResponse.result, function(i)
						table.insert(recentCaptainPlayerIds, i)
					end)
				end
			else
				TGNS.DebugPrint(string.format("captains ERROR: Unable to access recentcaptainplayerids data for server %s. msg: %s | response: %s | stacktrace: %s", TGNS.GetSimpleServerName(), recentCaptainPlayerIdsResponse.msg, recentCaptainPlayerIdsResponseJson, recentCaptainPlayerIdsResponse.stacktrace))
			end
		end)
	end)

	local originalServerSetPassword = Server.SetPassword
	local function disallowPasswordAfterMidnightOnSaturdays()
		if TGNS.GetAbbreviatedDayOfWeek() == "Sat" and TGNS.GetCurrentHour() < 6 then
				Server.SetPassword("")
				Server.SetPassword = function()
					TGNS.ScheduleAction(0, function()
						md:ToAdminConsole("ERROR: Password disabled between midnight and 6AM Saturday.")
					end)
				end
		else
			Server.SetPassword = originalServerSetPassword
			TGNS.ScheduleAction(60, disallowPasswordAfterMidnightOnSaturdays)
		end
	end

	TGNS.ScheduleAction(10, disallowPasswordAfterMidnightOnSaturdays)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("captains", Plugin )