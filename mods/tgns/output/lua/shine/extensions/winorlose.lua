local kWinOrLoseVoteArray = { }
local kWinOrLoseTeamCount = 2
local kTimeAtWhichWinOrLoseVoteSucceeded = 0
local kTeamWhichWillWinIfWinLoseCountdownExpires = nil
local kCountdownTimeRemaining = 0
local ENTITY_CLASSNAMES_TO_DESTROY_ON_LOSING_TEAM = { "Sentry", "Mine", "Armory", "Whip", "Clog", "Hydra", "Crag", "ARC", "Observatory" }
local VOTE_HOWTO_TEXT = "Press 'M > Surrender' to vote."
local GIVE_TEXT = "Give 100% until the game is over!"
local md
local lastVoteStartTimes = {}
local numberOfSecondsToDeductFromCountdownTimeRemaining
local mayVoteAt = 0
local lastNoAttackNoticeTimes = {}
local lastBannerDisplayCountdownRemaining
local TEXT_LOCATION_HEIGHT_ADDITIVE = 0.15
local textLocationHeightAdditive = TEXT_LOCATION_HEIGHT_ADDITIVE
local VOTE_START_COOLDOWN = 180
local attackOrderLastGivenWhen = {}
local attackEnhancementLastGivenWhen = {}
local lowestTimeRemainingFromWhichToDeduct = 20
local maximumAllowableNumberOfSecondsToDeduct = 14
local initialNumberOfSecondsToDeduct = 9
local whenBigVotesFailedWithMajorityThisGame = {}
local huhBangPoints = {}
local gameDurationWhenWinOrLoseVoteLastSucceeded

local originalGetCanAttack

local function removeBanners()
	Shine.ScreenText.End(70)
	Shine.ScreenText.End(71)
	Shine.ScreenText.End(72)
	Shine.ScreenText.End(73)
	Shine.ScreenText.End(74)
end

local function showVoteUpdateMessageToTeamAndSpectators(teamNumber, message)
	local notify = function(md, teamNumber, displayTeamNumber, message)
		if TGNS.Contains(message, "expired") then
			md:ToTeamNotifyColors(displayTeamNumber, message, 255, 255, 255, 255, 0, 0)
		else
			local secondsRemaining = math.ceil((kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning + kWinOrLoseVoteArray[teamNumber].VotingTimeInSeconds) - TGNS.GetSecondsSinceMapLoaded())
			local voteIsCloseToEnding = false
			local displayTeamClients = TGNS.GetTeamClients(displayTeamNumber, TGNS.GetPlayerList())
			TGNS.DoFor(displayTeamClients, function(c)
				local messageRed = 255
				local messageGreen = 255
				local messageBlue = 255
				local p = TGNS.GetPlayer(c)
				local playerHasVoted = false
				if TGNS.Has(kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes, c:GetUserId()) then
					messageRed = 3
					messageGreen = 192
					messageBlue = 60
					playerHasVoted = true
				elseif secondsRemaining > 0 and secondsRemaining <= 10 then
					messageRed = 255
					messageGreen = 255
					messageBlue = 0
					voteIsCloseToEnding = true
				end
				local numberOfTeamVotes = #kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes
				local teamClients = TGNS.GetTeamClients(teamNumber, TGNS.GetPlayerList())
				local amountOfTeamThatHasVoted = numberOfTeamVotes / #teamClients
				if TGNS.IsGameplayTeamNumber(displayTeamNumber) and voteIsCloseToEnding and amountOfTeamThatHasVoted >= 0.5 and not playerHasVoted then
					local reminderMessage = "WinOrLose?"
					if amountOfTeamThatHasVoted > 0.5 then
						reminderMessage = string.format("%s!", reminderMessage)
					end
					Shine.ScreenText.Add(79, {X = 0.5, Y = 0.7, Text = reminderMessage, Duration = 5, R = messageRed, G = messageGreen, B = messageBlue, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
				end
				md:ToPlayerNotifyColors(p, message, 255, 255, 255, messageRed, messageGreen, messageBlue)
			end)
		end
	end

	notify(md, teamNumber, teamNumber, message)
	local teamName = TGNS.GetTeamName(teamNumber)
	local teamMd = TGNSMessageDisplayer.Create(string.format("WINORLOSE (%s)", TGNS.ToUpper(teamName)))
	notify(teamMd, teamNumber, kSpectatorIndex, message)
end

local function SetupWinOrLoseVars()
	for i = 1, kWinOrLoseTeamCount do
		local WinOrLoseVoteTeamArray = {WinOrLoseRunning = 0, WinOrLoseVotes = { }, WinOrLoseVotesAlertTime = 0, VotingTimeInSeconds = 0}
		table.insert(kWinOrLoseVoteArray, WinOrLoseVoteTeamArray)
	end
end

local function GetCommandStructureToKeep(commandStructures)
	local builtAndAliveCommandStructures = TGNS.Where(commandStructures, TGNS.CommandStructureIsBuiltAndAlive)
	TGNS.SortDescending(builtAndAliveCommandStructures, TGNS.GetNumberOfWorkingInfantryPortals)
	local commandStructuresWithCommanders = TGNS.Where(builtAndAliveCommandStructures, TGNS.CommandStructureHasCommander)
	local builtAndAliveCommandStationsWithWorkingInfantryPortal = TGNS.Where(builtAndAliveCommandStructures, function(s) return TGNS.GetNumberOfWorkingInfantryPortals(s) > 0 end)
	local firstCommandStructureWithCommander = #commandStructuresWithCommanders > 0 and TGNS.GetFirst(commandStructuresWithCommanders) or nil
	local firstCommandStationWithWorkingInfantryPortal = #builtAndAliveCommandStationsWithWorkingInfantryPortal > 0 and TGNS.GetFirst(builtAndAliveCommandStationsWithWorkingInfantryPortal) or nil
	local firstBuiltAndAliveCommandStructure = #builtAndAliveCommandStructures > 0 and TGNS.GetFirst(builtAndAliveCommandStructures) or nil
	local result = firstCommandStructureWithCommander or firstCommandStationWithWorkingInfantryPortal or firstBuiltAndAliveCommandStructure or TGNS.GetFirst(commandStructures)
	return result
end

local function getNumberOfRequiredVotes(potentialVoterPlayers)
	local votersCount = #TGNS.Where(potentialVoterPlayers, function(p) return not (TGNS.PlayerIsRookie(p) and TGNS.IsPlayerStranger(p)) end)
	local minimumPercentage = Shine.Plugins.winorlose.Config.MinimumPercentage
	local result = math.floor((votersCount * (minimumPercentage / 100)))
	if votersCount >= 7 then
		local votesRequiredToLower = Shine.Plugins.winorlose.Config.RecentFailedMajorityVotesRequiredToLowerPercentage
		local pastDurationToLower = votesRequiredToLower * Shine.Plugins.winorlose.Config.VotingTimeInSeconds
		if #TGNS.Where(whenBigVotesFailedWithMajorityThisGame, function(w) return w >= Shared.GetTime() - pastDurationToLower end) >= votesRequiredToLower then
			result = math.ceil((votersCount * (51 / 100)))
		end
	end
	-- TGNS.DebugPrint(string.format("winorlosedebug [%s]: %s voters have minimumPercentage: %s require %s votes with %s", Shared.GetTime(), votersCount, minimumPercentage, result, TGNS.Join(whenBigVotesFailedWithMajorityThisGame, ", ")))
	return result
end

local function onVoteSuccessful(teamNumber)
	local teamName = TGNS.GetTeamName(teamNumber)
	local threateningActionName = (Shine.Plugins.arclight and Shine.Plugins.arclight:IsArclight()) and "control the platform" or "attack"
	local chatMessage = string.sub(string.format("WinOrLose! %s surrendered and can't %s! End it in %s secs, or THEY WIN!", teamName, threateningActionName, Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds), 1, kMaxChatLength)
	md:ToAllNotifyInfo(chatMessage)

	if math.random() < 0.1 then
		TGNS.ScheduleAction(7, function()
			if TGNS.IsGameInProgress() then
				local nominationsMd = TGNSMessageDisplayer.Create("MAPCYCLE")
				TGNS.DoFor(TGNS.GetPlayers(TGNS.GetTeamClients(teamNumber)), function(p)
					nominationsMd:ToPlayerNotifyInfo(p, "Put in nominations now for the next map!")
				end)
			end
		end)
	end

	kTimeAtWhichWinOrLoseVoteSucceeded = TGNS.GetSecondsSinceMapLoaded()
	gameDurationWhenWinOrLoseVoteLastSucceeded = TGNS.GetCurrentGameDurationInSeconds()
	kTeamWhichWillWinIfWinLoseCountdownExpires = TGNS.GetTeamFromTeamNumber(teamNumber)
	numberOfSecondsToDeductFromCountdownTimeRemaining = initialNumberOfSecondsToDeduct
	kCountdownTimeRemaining = Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds

	kWinOrLoseVoteArray[teamNumber].WinOrLoseVotesAlertTime = 0
	kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning = 0
	kWinOrLoseVoteArray[teamNumber].VotingTimeInSeconds = 0
	kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes = { }
	TGNS.ExecuteEventHooks("WinOrLoseCalled", teamNumber)
	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
		TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.SHOW_TEAM_MESSAGES, {s=false})
	end)
end

local function showHuhBangPoints(teamNumber)
	if not TGNS.IsProduction() then
		local testClient = TGNS.GetClientList()[1]
		teamNumber = TGNS.GetClientTeamNumber(testClient)
		gameDurationWhenWinOrLoseVoteLastSucceeded = 300
		huhBangPoints[testClient] = huhBangPoints[testClient] or 100
	end


	local huhBangPointsDisplayData = {}
	TGNS.DoForPairs(huhBangPoints, function(pointsClient, points)
		if Shine:IsValidClient(pointsClient) and TGNS.GetClientTeamNumber(pointsClient) == teamNumber then
			huhBangPointsDisplayDatum = {}
			huhBangPointsDisplayDatum.ClientName = TGNS.GetClientName(pointsClient)
			huhBangPointsDisplayDatum.Points = points
			table.insert(huhBangPointsDisplayData, huhBangPointsDisplayDatum)
		end
	end)
	local gameDurationInMinutes = TGNS.ConvertSecondsToMinutes(gameDurationWhenWinOrLoseVoteLastSucceeded)
	local getPointsDisplay = function(points)
		return math.ceil(points * gameDurationInMinutes * 20)
	end
	if TGNS.Any(huhBangPointsDisplayData) then
		TGNS.SortDescending(huhBangPointsDisplayData, function(d) return d.Points end)
		local padLength = ((#tostring(getPointsDisplay(TGNS.GetFirst(huhBangPointsDisplayData).Points))) * 2) + 7
		local huhBangPointIndexDisplay = "?!:"
		local huhBangPointPointsDisplay = ""
		local huhBangPointNamesDisplay = ""
		TGNS.DoFor(huhBangPointsDisplayData, function(d, index)
			huhBangPointIndexDisplay = string.format("%s\n%s", huhBangPointIndexDisplay, index)
			huhBangPointPointsDisplay = string.format("%s\n   - %s", huhBangPointPointsDisplay, getPointsDisplay(d.Points))
			huhBangPointNamesDisplay = string.format("%s\n%s", huhBangPointNamesDisplay, string.rep(" ", padLength)  .. d.ClientName)
		end)
		local teamRgb = TGNS.GetTeamRgb(teamNumber)
		TGNS.DoFor(TGNS.GetTeamClients(teamNumber), function(c)
			Shine.ScreenText.Add(76, {X = 0.7, Y = .3, Text = huhBangPointIndexDisplay, Duration = Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 1, FadeIn = 0, IgnoreFormat = true}, c)
			Shine.ScreenText.Add(77, {X = 0.7, Y = .3, Text = huhBangPointPointsDisplay, Duration = Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 1, FadeIn = 0, IgnoreFormat = true}, c)
			Shine.ScreenText.Add(78, {X = 0.7, Y = .3, Text = huhBangPointNamesDisplay, Duration = Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 1, FadeIn = 0, IgnoreFormat = true}, c)
		end)
	end
end

local function UpdateWinOrLoseVotes(forceVoteStatusUpdateForTeamNumber)
	if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
		local teamNumberWhichWillWinIfWinLoseCountdownExpires = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber()
		if kCountdownTimeRemaining > 0 then
			if ((lastBannerDisplayCountdownRemaining == nil or lastBannerDisplayCountdownRemaining >= kCountdownTimeRemaining + Shine.Plugins.winorlose.Config.WarningIntervalInSeconds) or kCountdownTimeRemaining <= 10 or kCountdownTimeRemaining > Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds - 3) then
				local teamName = TGNS.GetTeamName(teamNumberWhichWillWinIfWinLoseCountdownExpires)
				local threateningActionName = (Shine.Plugins.arclight and Shine.Plugins.arclight:IsArclight()) and "control the platform" or "attack"
				local chatMessage = string.format("%s can't %s. Game ends in %s seconds.", teamName, threateningActionName, kCountdownTimeRemaining)
				local bannerLocationName = ""

				local teamNumberWhichWillLoseIfWinLoseCountdownExpires = TGNS.GetOtherPlayingTeamNumber(teamNumberWhichWillWinIfWinLoseCountdownExpires)
				local teamNameWhichMustWinOrLose = TGNS.GetTeamName(teamNumberWhichWillLoseIfWinLoseCountdownExpires)
				local howToWinDescription = string.format("Kill the %s", TGNS.GetTeamCommandStructureCommonName(teamNumberWhichWillWinIfWinLoseCountdownExpires))
				if Shine.Plugins.arclight and Shine.Plugins.arclight:IsArclight() then
					howToWinDescription = "Control the platform"
					bannerLocationName = string.format(" in %s", Shine.Plugins.arclight:GetHillLocationName())
				else
					local commandStructures = TGNS.GetEntitiesForTeam("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires)
					TGNS.DoFor(commandStructures, function(s)
						s.GetCanBeHealedOverride = function(self) return false, false end
						s.GetCanBeWeldedOverride = function(self, doer) return false, false end
					end)
					local commandStructureToKeep = GetCommandStructureToKeep(commandStructures)
					if commandStructureToKeep ~= nil then
						if teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType then
							commandStructureToKeep.GetCanBeNanoShieldedOverride = function(self, resultTable)
			    				resultTable.shieldedAllowed = false
			    				local commanderClient = TGNS.GetFirst(TGNS.Where(TGNS.GetTeamClients(teamNumberWhichWillWinIfWinLoseCountdownExpires), TGNS.IsClientCommander))
			    				local commanderPlayer = TGNS.GetPlayer(commanderClient)
			    				md:ToPlayerNotifyError(commanderPlayer, "Command chairs may not be nanoshielded during WinOrLose.")
			    			end
						end
						local locationNameOfCommandStructureToKeep = commandStructureToKeep:GetLocationName()
						TGNS.DestroyEntitiesExcept(commandStructures, commandStructureToKeep)
						bannerLocationName = string.format(" in %s", locationNameOfCommandStructureToKeep)

						local waypointAction = teamNumberWhichWillLoseIfWinLoseCountdownExpires == kMarineTeamType and function(p, c)
							if p.GiveOrder and not TGNS.IsClientCommander(c) then
								p:GiveOrder(kTechId.Attack, commandStructureToKeep:GetId(), commandStructureToKeep:GetOrigin())
								return true
							end
						end or function(p, c)
							CreatePheromone(kTechId.LargeThreatMarker, commandStructureToKeep:GetOrigin(), kAlienTeamType)
							return true
						end

						local enhancementAction = teamNumberWhichWillLoseIfWinLoseCountdownExpires == kMarineTeamType and function(p, c)
							if p.ApplyCatPack and not TGNS.IsClientCommander(c) then
								StartSoundEffectAtOrigin(CatPack.kPickupSound, p:GetOrigin())
					    		p:ApplyCatPack()
					    		return true
							end
						end or function(p, c)
							if p.TriggerEnzyme and p.SetSpeedBoostDuration and not TGNS.IsClientCommander(c) then
								p:TriggerEnzyme(8)
	            				p:SetSpeedBoostDuration(8)
	            				return true
							end
						end

						TGNS.DoFor(TGNS.GetTeamClients(teamNumberWhichWillLoseIfWinLoseCountdownExpires, TGNS.GetPlayerList()), function(c)
							if attackOrderLastGivenWhen[c] == nil or Shared.GetTime() - attackOrderLastGivenWhen[c] >= 6 then
								local p = TGNS.GetPlayer(c)
								if not GetCanSeeEntity(p, commandStructureToKeep, true) then
									if waypointAction(p, c) then
										attackOrderLastGivenWhen[c] = Shared.GetTime()
									end
								end
							end
							if attackEnhancementLastGivenWhen[c] == nil or Shared.GetTime() - attackEnhancementLastGivenWhen[c] >= 15 then
								local p = TGNS.GetPlayer(c)
								if enhancementAction(p, c) then
									attackEnhancementLastGivenWhen[c] = Shared.GetTime()
								end
							end
						end)
					end
				end
				TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c)
					local p = TGNS.GetPlayer(c)
					local teamNumber = TGNS.GetPlayerTeamNumber(p)
					local teamRgb = TGNS.GetTeamRgb(teamNumber)
					local explanationText = TGNS.IsClientStranger(c) and "They surrendered!" or "WinOrLose!"
					local winningTeamText = string.format("%s %s%s!", explanationText, howToWinDescription, bannerLocationName)
					local losingTeamText = string.format("Your team has surrendered. %s must WinOrLose!", teamNameWhichMustWinOrLose)
					local bannerText = teamNumber == teamNumberWhichWillWinIfWinLoseCountdownExpires and losingTeamText or winningTeamText


					local LOWEST_ALLOWABLE_TEXT_LOCATION_HEIGHT = 0.2
					local textLocationHeight = LOWEST_ALLOWABLE_TEXT_LOCATION_HEIGHT
					local additiveShouldBeApplied = true -- TGNS.ClientIsStranger(c)
					if additiveShouldBeApplied then
						textLocationHeight = textLocationHeight + textLocationHeightAdditive
					end


					Shine.ScreenText.Add(71, {X = 0.5, Y = textLocationHeight, Text = bannerText, Duration = Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
					Shine.ScreenText.Add(72, {X = 0.5, Y = textLocationHeight + 0.04, Text = chatMessage, Duration = Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
					textLocationHeightAdditive = textLocationHeightAdditive > 0 and textLocationHeightAdditive - 0.05 or textLocationHeightAdditive
					TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.WINORLOSE_WARNING, {})
					--showHuhBangPoints(teamNumberWhichWillWinIfWinLoseCountdownExpires)
				end)
				local spectatorsText = string.format("WinOrLose! %s have %s seconds to %s%s!", teamNameWhichMustWinOrLose, kCountdownTimeRemaining, TGNS.ToLower(howToWinDescription), bannerLocationName)
				TGNS.DoFor(TGNS.GetSpectatorClients(TGNS.GetPlayerList()), function(c)
					-- Shine:SendText(c, Shine.BuildScreenMessage(74, 0.5, 0.85, spectatorsText, Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, 255, 255, 255, 1, 1, 0))
					Shine.ScreenText.Add(74, {X = 0.5, Y = 0.85, Text = spectatorsText, Duration = Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, R = 255, G = 255, B = 255, Alignment = TGNS.ShineTextAlignmentCenter, Size = 1, FadeIn = 0, IgnoreFormat = true}, c)
				end)
				TGNS.DoFor(ENTITY_CLASSNAMES_TO_DESTROY_ON_LOSING_TEAM, function(className)
					TGNS.DestroyAllEntities(className, teamNumberWhichWillWinIfWinLoseCountdownExpires)
				end)
				lastBannerDisplayCountdownRemaining = kCountdownTimeRemaining
			end
			kCountdownTimeRemaining = kCountdownTimeRemaining - 1
		else
			removeBanners()
			-- Shine:SendText(nil, Shine.BuildScreenMessage(75, 0.5, 0.2, "WinOrLose, on to the next game!", 7, 255, 255, 255, 1, 3, 0 ) )
			Shine.ScreenText.Add(75, {X = 0.5, Y = 0.2, Text = "WinOrLose, on to the next game!", Duration = 7, R = 255, G = 255, B = 255, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true})
			-- Shine:SendText(nil, Shine.BuildScreenMessage(72, 0.5, 0.24, "", 1, 255, 255, 255, 1, 1, 0))
			-- Shine:SendText(nil, Shine.BuildScreenMessage(74, 0.5, 0.85, "", 1, 255, 255, 255, 1, 1, 0))
			TGNS.DestroyAllEntities("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType and kAlienTeamType or kMarineTeamType)
			kTimeAtWhichWinOrLoseVoteSucceeded = 0
			--showHuhBangPoints(teamNumberWhichWillWinIfWinLoseCountdownExpires)
		end
		TGNS.ExecuteEventHooks("WinOrLoseCountdownChanged", kCountdownTimeRemaining)
	else
		for i = 1, kWinOrLoseTeamCount do
			if (forceVoteStatusUpdateForTeamNumber and forceVoteStatusUpdateForTeamNumber == i) or (kWinOrLoseVoteArray[i].WinOrLoseRunning ~= 0 and TGNS.IsGameInProgress() and kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime + Shine.Plugins.winorlose.Config.AlertDelayInSeconds < TGNS.GetSecondsSinceMapLoaded()) then
				local playerRecords = TGNS.GetPlayers(TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return p:GetTeamNumber() == i end))
				local totalvotes = 0
				for j = #kWinOrLoseVoteArray[i].WinOrLoseVotes, 1, -1 do
					local steamId = kWinOrLoseVoteArray[i].WinOrLoseVotes[j]
					local stillplaying = false

					for k = 1, #playerRecords do
						local player = playerRecords[k]
						if player ~= nil then
							local client = Server.GetOwner(player)
							if client ~= nil then
								if steamId == TGNS.GetClientSteamId(client) then
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
				if totalvotes >= getNumberOfRequiredVotes(playerRecords) then
					onVoteSuccessful(i)
				else
					local chatMessage
					if kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime == 0 then
						-- chatMessage = string.sub(string.format("Concede vote started. %s votes are needed. %s", getNumberOfRequiredVotes(playerRecords), VOTE_HOWTO_TEXT), 1, kMaxChatLength)
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = TGNS.GetSecondsSinceMapLoaded()
						local someStrangersAreRequiredToPassTheVote = getNumberOfRequiredVotes(playerRecords) > #TGNS.Where(TGNS.GetClients(playerRecords), TGNS.HasClientSignedPrimerWithGames)
						kWinOrLoseVoteArray[i].VotingTimeInSeconds = someStrangersAreRequiredToPassTheVote and Shine.Plugins.winorlose.Config.VotingTimeInSeconds or math.floor(Shine.Plugins.winorlose.Config.VotingTimeInSeconds * 0.75)
					elseif kWinOrLoseVoteArray[i].WinOrLoseRunning + kWinOrLoseVoteArray[i].VotingTimeInSeconds < TGNS.GetSecondsSinceMapLoaded() then
						--local abstainedNames = {}
						--TGNS.DoFor(playerRecords, function(p)
						--	local playerSteamId = TGNS.ClientAction(p, TGNS.GetClientSteamId)
						--	if not TGNS.Has(kWinOrLoseVoteArray[i].WinOrLoseVotes, playerSteamId) then
						--		table.insert(abstainedNames, TGNS.GetPlayerName(p))
						--	end
						--end)
						--chatMessage = string.sub(string.format("Concede vote expired. Abstained: %s", TGNS.Join(abstainedNames, ", ")), 1, kMaxChatLength)
						chatMessage = totalvotes > 1 and "Concede vote expired" or ""
						if (#playerRecords >= 7 and totalvotes > #playerRecords / 2) then
							table.insert(whenBigVotesFailedWithMajorityThisGame, Shared.GetTime())
							local teamSteamIds = TGNS.Select(TGNS.GetTeamClients(i), TGNS.GetClientSteamId)
							local abstainerSteamIds = TGNS.Where(teamSteamIds, function(steamId) return not TGNS.Has(kWinOrLoseVoteArray[i].WinOrLoseVotes, steamId) end)
							local abstainerPlayers = TGNS.Select(abstainerSteamIds, TGNS.GetPlayerMatchingSteamId)
							local randomizedAbstainerPlayers = TGNS.GetRandomizedElements(abstainerPlayers)
							local randomAbstainerPlayer = TGNS.GetFirst(randomizedAbstainerPlayers)
							local randomAbstainerPlayerName = TGNS.GetPlayerName(randomAbstainerPlayer)
							chatMessage = string.format("%s with majority. %s: make sure there's a team plan!", chatMessage, randomAbstainerPlayerName)
						else
							if TGNS.HasNonEmptyValue(chatMessage) then
								chatMessage = string.format("%s.", chatMessage)
							end
						end
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
						kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
						kWinOrLoseVoteArray[i].VotingTimeInSeconds = 0
						kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
					else
						if kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime + Shine.Plugins.winorlose.Config.AlertDelayInSeconds < TGNS.GetSecondsSinceMapLoaded() then
							local secondsLeft = math.ceil((kWinOrLoseVoteArray[i].WinOrLoseRunning + kWinOrLoseVoteArray[i].VotingTimeInSeconds) - TGNS.GetSecondsSinceMapLoaded())
							if secondsLeft <= Shine.Plugins.winorlose.Config.AlertDelayInSeconds and totalvotes > 1 then
								chatMessage = string.sub(string.format("%s/%s votes to concede; %s secs left. %s", totalvotes,
								 getNumberOfRequiredVotes(playerRecords),
								 secondsLeft, VOTE_HOWTO_TEXT), 1, kMaxChatLength)
							end

							kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = TGNS.GetSecondsSinceMapLoaded()
						end
					end
					if TGNS.HasNonEmptyValue(chatMessage) then
						showVoteUpdateMessageToTeamAndSpectators(i, chatMessage)
					end
					-- TGNS.DoFor(playerRecords, function(p)
					-- 	md:ToPlayerNotifyInfo(p, chatMessage)
					-- end)
				end
			end
		end
	end
end

local function InitializeVariables()
	for i = 1, kWinOrLoseTeamCount do
		kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
		kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
		kWinOrLoseVoteArray[i].VotingTimeInSeconds = 0
		kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
	end
	kTimeAtWhichWinOrLoseVoteSucceeded = 0
	lastVoteStartTimes = {}
	lastBannerDisplayCountdownRemaining = nil
	textLocationHeightAdditive = TEXT_LOCATION_HEIGHT_ADDITIVE
end

local function OnCommandWinOrLose(client)
	local player = TGNS.GetPlayer(client)
	if Shine.GetGamemode() == "ns2" then
		if TGNS.IsGameInProgress() then
			if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
				md:ToPlayerNotifyError(player, "WinOrLose in progress.")
			elseif TGNS.GetSecondsSinceMapLoaded() < mayVoteAt then
				md:ToPlayerNotifyError(player, "You may not yet WinOrLose.")
			else
				--if player:GetTeam():GetNumAliveCommandStructures() <= 2 then
					local steamId = TGNS.GetClientSteamId(client)
					local teamNumber = TGNS.GetPlayerTeamNumber(player)
					if TGNS.IsGameplayTeamNumber(teamNumber) then
						if kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning ~= 0 then
							local alreadyvoted = false
							for i = #kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes, 1, -1 do
								if kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes[i] == steamId then
									alreadyvoted = true
									break
								end
							end
							if alreadyvoted then
								chatMessage = string.sub(string.format("You already voted to concede."), 1, kMaxChatLength)
								md:ToPlayerNotifyError(player, chatMessage)
							else
								table.insert(kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes, steamId)
								showVoteUpdateMessageToTeamAndSpectators(teamNumber, string.format("%s would like to concede. %s", TGNS.IsClientCommander(client) and "The Commander" or "A teammate", VOTE_HOWTO_TEXT))
								-- md:ToPlayerNotifyInfo(player, string.format("Voted! %s", GIVE_TEXT))
							end
							UpdateWinOrLoseVotes(teamNumber)
						else
							if lastVoteStartTimes[client] == nil or lastVoteStartTimes[client] + VOTE_START_COOLDOWN <= TGNS.GetSecondsSinceMapLoaded() then
								kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning = TGNS.GetSecondsSinceMapLoaded()
								table.insert(kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes, steamId)
								lastVoteStartTimes[client] = TGNS.GetSecondsSinceMapLoaded()
								if TGNS.IsClientCommander(client) or Shine.Plugins.communityslots:IsClientRecentCommander(client) then
									showVoteUpdateMessageToTeamAndSpectators(teamNumber, string.format("The Commander would like to concede. %s %s", VOTE_HOWTO_TEXT, GIVE_TEXT))
								else
									md:ToPlayerNotifyInfo(player, string.format("Voted! %s", GIVE_TEXT))
								end
							else
								md:ToPlayerNotifyError(player, "You started a vote too recently. When another")
								md:ToPlayerNotifyError(player, "teammate starts a vote, you may participate.")
							end
						end
					else
						md:ToPlayerNotifyError(player, "You must be on a team.")
					end
				--else
				--	chatMessage = string.sub(string.format("You may concede only when you have one or two command structures."), 1, kMaxChatLength)
				--	Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				--end
			end
		else
			md:ToPlayerNotifyError(player, "Game is not in progress.")
		end
	else
		md:ToPlayerNotifyError(player, "WinOrLose is not supported in this game mode.")
	end
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "winorlose.json"

function Plugin:GetWinOrLoseCountdownData()
	return kCountdownTimeRemaining, kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber()
end

local lastSpecInNoticeShownAt = {}
function Plugin:PostJoinTeam()
	-- if not TGNS.IsProduction() then
	-- 	showHuhBangPoints()
	-- end
	TGNS.ScheduleAction(10, function()
		if TGNS.IsGameInProgress() and kTimeAtWhichWinOrLoseVoteSucceeded == 0 then
			local playerList = TGNS.GetPlayerList()
			local marinesCount = #TGNS.GetMarineClients(playerList)
			local aliensCount = #TGNS.GetAlienClients(playerList)
			if marinesCount ~= aliensCount then
				TGNS.DoFor(TGNS.GetSpectatorClients(playerList), function(c)
					if Shared.GetTime() - (lastSpecInNoticeShownAt[c] or 0) > 60 then
						local specInMd = TGNSMessageDisplayer.Create()
						local message = string.format("%s: Gameplay slot open?", TGNS.GetClientName(c))
						specInMd:ToPlayerNotifyInfo(TGNS.GetPlayer(c), message)
						lastSpecInNoticeShownAt[c] = Shared.GetTime()
					end
				end)
			end
		end
	end)
end

function Plugin:CreateCommands()
	local command = self:BindCommand("sh_winorlose", nil, OnCommandWinOrLose, true)
	command:Help("Cast a WinOrLose vote.")

	if not TGNS.IsProduction() then
		local testCommand = self:BindCommand("sh_setnumber", "n", function(client, n)
			huhBangPoints[client] = tonumber(n)
			md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), tostring(n))
		end)
		testCommand:AddParam{ Type = "string" }
		testCommand:Help("Set the number.")
	end

end

function Plugin:CallWinOrLose(teamNumber)
	onVoteSuccessful(teamNumber)
end

function Plugin:GetDamageModification( Ent, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
	local result
	if kTimeAtWhichWinOrLoseVoteSucceeded > 0 and kCountdownTimeRemaining > 0 and Attacker and Attacker:isa("Player") and Attacker:GetTeamNumber() == kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber() and Ent and Ent:GetTeamNumber() ~= Attacker:GetTeamNumber() then
		result = {}
		result.Damage = 0
		result.HealthUsed = 0
		result.ArmourUsed = 0
		result.NotifyAction = function()
			local client = TGNS.GetClient(Attacker)
			if client and (lastNoAttackNoticeTimes[client] == nil or lastNoAttackNoticeTimes[client] < Shared.GetTime() - 1) then
				local teamRgb = TGNS.GetTeamRgb(Attacker:GetTeamNumber())
				Shine.ScreenText.Add(70, {X = 0.5, Y = 0.6, Text = "You cannot do damage. Your team has surrendered.", Duration = 6, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, client)
				lastNoAttackNoticeTimes[client] = Shared.GetTime()
				huhBangPoints[client] = huhBangPoints[client] or 0
				huhBangPoints[client] = huhBangPoints[client] + Damage
			end
		end
	end
	return result
end

function Plugin:Initialise()
    self.Enabled = true

	md = TGNSMessageDisplayer.Create("WINORLOSE")
	-- originalGetCanAttack = TGNS.ReplaceClassMethod("Player", "GetCanAttack", function(self)
	-- 	local winOrLoseChallengeIsInProgressByMyTeam = kTimeAtWhichWinOrLoseVoteSucceeded > 0 and self:GetTeam() == kTeamWhichWillWinIfWinLoseCountdownExpires
	-- 	local canAttack = originalGetCanAttack(self) and not winOrLoseChallengeIsInProgressByMyTeam
	-- 	return canAttack
	-- end)

	local originalObservatoryTriggerDistressBeacon = Observatory.TriggerDistressBeacon
	Observatory.TriggerDistressBeacon = function(observatorySelf)
		local timeRemainingThreshold = math.floor(Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds * .9)
		if kTimeAtWhichWinOrLoseVoteSucceeded > 0 and kCountdownTimeRemaining < timeRemainingThreshold then
			local teamNumberWhichWillWinIfWinLoseCountdownExpires = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber()
			local commanderClient = TGNS.GetFirst(TGNS.Where(TGNS.GetTeamClients(TGNS.GetOtherPlayingTeamNumber(teamNumberWhichWillWinIfWinLoseCountdownExpires)), TGNS.IsClientCommander))
			local commanderPlayer = TGNS.GetPlayer(commanderClient)
			md:ToPlayerNotifyError(commanderPlayer, "WinOrLose beacons are allowed only immediately after the countdown begins.")
			return false, true
		else
			return originalObservatoryTriggerDistressBeacon(observatorySelf)
		end
	end

	TGNS.RegisterEventHook("GameStarted", function()
		mayVoteAt = TGNS.GetSecondsSinceMapLoaded() + (TGNS.IsProduction() and 5 or 0)
		whenBigVotesFailedWithMajorityThisGame = {}
		
		-- if not TGNS.IsProduction() then
		-- 	self:CallWinOrLose(TGNS.GetOtherPlayingTeamNumber(TGNS.GetClientTeamNumber(TGNS.GetFirst(TGNS.GetHumanClientList()))))
		-- end
	end)
	SetupWinOrLoseVars()
	TGNS.RegisterEventHook("OnEverySecond", function()
		if TGNS.IsGameInProgress() then
			UpdateWinOrLoseVotes()
		end
	end)
	self:CreateCommands()
	InitializeVariables()

    return true
end

function Plugin:EndGame(gamerules, winningTeam)
	InitializeVariables()
	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
		TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.SHOW_TEAM_MESSAGES, {s=true})
	end)
	removeBanners()
	huhBangPoints = {}
end

function Plugin:CastVoteByPlayer(gamerules, voteTechId, player)
	local cancel = false
	if voteTechId == kTechId.VoteConcedeRound and Shine.GetGamemode() == "ns2" then
		TGNS.ClientAction(player, OnCommandWinOrLose)
		cancel = true
	end
	if cancel then
		return true
	end
end

function Plugin:OnEntityKilled(gamerules, victimEntity, attackerEntity, inflictorEntity, point, direction)
	if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
		local teamNumberWhichWillWinIfWinLoseCountdownExpires = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber()
		if TGNS.EntityIsCommandStructure(victimEntity) and victimEntity:GetTeamNumber() == teamNumberWhichWillWinIfWinLoseCountdownExpires then
			TGNS.DestroyAllEntities("CommandStructure", victimEntity:GetTeamNumber())
		else
			if kCountdownTimeRemaining > 0 and victimEntity and victimEntity:isa("Player") and victimEntity:GetTeamNumber() == teamNumberWhichWillWinIfWinLoseCountdownExpires then
				-- Shine:SendText(victimEntity, Shine.BuildScreenMessage(70, 0.5, 0.4, "", 6, 255, 255, 255, 1, 3, 0 ) )
				Shine.ScreenText.End(70, victimEntity)
			end
			if kCountdownTimeRemaining < Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds - 1 then
				if victimEntity and attackerEntity and victimEntity:isa("Player") and attackerEntity:isa("Player") and inflictorEntity:GetParent() == attackerEntity and not TGNS.GetIsClientVirtual(TGNS.GetClient(victimEntity)) and not TGNS.IsPlayerHallucination(victimEntity) then
					local commandStructureCommonName = TGNS.GetTeamCommandStructureCommonName(teamNumberWhichWillWinIfWinLoseCountdownExpires)
					local attackerTeamNumber = TGNS.GetPlayerTeamNumber(attackerEntity)
					local attackerIsMarine = attackerTeamNumber == kMarineTeamType
					-- todo mlh convert to use TGNS.GetTeamRgb
					local attackerRed = attackerIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
					local attackerGreen = attackerIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
					local attackerBlue = attackerIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
					local victimTeamNumber = TGNS.GetPlayerTeamNumber(victimEntity)
					local victimIsMarine = victimTeamNumber == kMarineTeamType
					-- todo mlh convert to use TGNS.GetTeamRgb
					local victimRed = victimIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
					local victimGreen = victimIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
					local victimBlue = victimIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
					if kCountdownTimeRemaining >= lowestTimeRemainingFromWhichToDeduct then
						if attackerTeamNumber ~= teamNumberWhichWillWinIfWinLoseCountdownExpires and victimTeamNumber == teamNumberWhichWillWinIfWinLoseCountdownExpires then
							numberOfSecondsToDeductFromCountdownTimeRemaining = numberOfSecondsToDeductFromCountdownTimeRemaining + 1
							numberOfSecondsToDeductFromCountdownTimeRemaining = numberOfSecondsToDeductFromCountdownTimeRemaining > maximumAllowableNumberOfSecondsToDeduct and maximumAllowableNumberOfSecondsToDeduct or numberOfSecondsToDeductFromCountdownTimeRemaining
							local deductionAmountMultiplier = TGNS.IsClientStranger(TGNS.GetClient(attackerEntity)) and 0.5 or 1
							kCountdownTimeRemaining = kCountdownTimeRemaining - math.floor(numberOfSecondsToDeductFromCountdownTimeRemaining * deductionAmountMultiplier)
							local attackerTeamNumber = TGNS.GetPlayerTeamNumber(attackerEntity)
							local attackerIsMarine = attackerTeamNumber == kMarineTeamType
							-- todo mlh convert to use TGNS.GetTeamRgb
							local attackerRed = attackerIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
							local attackerGreen = attackerIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
							local attackerBlue = attackerIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
							TGNS.DoFor(TGNS.GetTeamClients(attackerTeamNumber, TGNS.GetPlayerList()), function(c)
								-- Shine:SendText(c, Shine.BuildScreenMessage(73, 0.5, 0.4, string.format("%s killed a player. Timer reduced to %s!", TGNS.GetPlayerName(attackerEntity), kCountdownTimeRemaining), 3, attackerRed, attackerGreen, attackerBlue, 1, 2, 0 ) )
								Shine.ScreenText.Add(73, {X = 0.5, Y = 0.4, Text = string.format("%s killed a player. Timer reduced to %s!", TGNS.GetPlayerName(attackerEntity), kCountdownTimeRemaining), Duration = 3, R = attackerRed, G = attackerGreen, B = attackerBlue, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
							end)
							TGNS.DoFor(TGNS.GetTeamClients(victimTeamNumber, TGNS.GetPlayerList()), function(c)
								-- Shine:SendText(c, Shine.BuildScreenMessage(73, 0.5, 0.7, string.format("%s did not die in vain! Timer reduced!", TGNS.GetPlayerName(victimEntity)), 6, victimRed, victimGreen, victimBlue, 1, 3, 0 ) )
								Shine.ScreenText.Add(73, {X = 0.5, Y = 0.7, Text = string.format("%s did not die in vain! Timer reduced!", TGNS.GetPlayerName(victimEntity)), Duration = 6, R = victimRed, G = victimGreen, B = victimBlue, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
							end)
						end
					else
						TGNS.DoFor(TGNS.GetTeamClients(victimTeamNumber, TGNS.GetPlayerList()), function(c)
							local comfortingText = string.format("the %s still stands", TGNS.ToLower(commandStructureCommonName))
							if Shine.Plugins.arclight and Shine.Plugins.arclight:IsArclight() then
								comfortingText = "we still have points"
							end
							Shine.ScreenText.Add(73, {X = 0.5, Y = 0.7, Text = string.format("%s has fallen, yet %s!", TGNS.GetPlayerName(victimEntity), comfortingText), Duration = 6, R = victimRed, G = victimGreen, B = victimBlue, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
						end)
					end
				end
			end
		end
	end
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup(self)
end

Shine:RegisterExtension("winorlose", Plugin)