local md = TGNSMessageDisplayer.Create()
local timerInProgress
local countdownSeconds = 60
local secondsRemaining
local gameEndedRecently
local fifteenSecondAfkTimerWasLastAdvertisedAt = 0

local Plugin = {}

local function showTimeRemaining()
	local playerList = TGNS.GetPlayerList()
	local marinePlayerCount = #TGNS.GetMarineClients(playerList)
	local alienPlayerCount = #TGNS.GetAlienClients(playerList)
	local teamsAreTooImbalanced = math.abs(marinePlayerCount - alienPlayerCount) >= 2
	if teamsAreTooImbalanced or not timerInProgress then
		timerInProgress = false
		secondsRemaining = secondsRemaining + math.ceil((countdownSeconds - secondsRemaining) / 2)
		if teamsAreTooImbalanced and not Shine.Plugins.captains:IsCaptainsModeEnabled() then
			Shine.ScreenText.Add(51, {X = 0.5, Y = 0.45, Text = "Countdown will resume when teams fill.", Duration = 10, R = 255, G = 0, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true})
		end
	else
		if not (TGNS.IsGameInCountdown() or TGNS.IsGameInProgress() or Shine.Plugins.captains:IsCaptainsModeEnabled() or Shine.Plugins.mapvote:VoteStarted()) then
			if secondsRemaining >= 1 then
				local duration = secondsRemaining < 3 and 5 or 1.5
				local secondsRemainingDescription = secondsRemaining <= 3 and "a few" or secondsRemaining
				local message = string.format("Game will force-start in %s seconds.\nPre/early-game AFK timer: 15 seconds!\n\n\n\nPer team with no Commander at game\nstart, one randomly selected player will\nbegin without any personal resources.", secondsRemainingDescription)
				Shine.ScreenText.Add(51, {X = 0.5, Y = 0.40, Text = message, Duration = duration, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true})
				fifteenSecondAfkTimerWasLastAdvertisedAt = Shared.GetTime()

				local warnPlayers = function(level, shouldRepeat)
					local playingClients = TGNS.GetPlayingClients(playerList)
					local warnPlayer = function(p) TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.arclight.HILL_SOUND, {i=level, r=shouldRepeat}) end
					TGNS.DoFor(TGNS.GetPlayers(playingClients), warnPlayer)
					if #playingClients < Shine.Plugins.communityslots.Config.PublicSlots then
						TGNS.DoFor(TGNS.GetReadyRoomPlayers(playerList), warnPlayer)
					end
				end
				if secondsRemaining % 10 == 0 then
					warnPlayers(secondsRemaining/10, true)
				end
				if secondsRemaining <= 10 then
					warnPlayers(secondsRemaining)
				end

				if secondsRemaining == 1 then
					TGNS.ScheduleAction(0.5, function()
						local clientsToTakeStartingPersonalResourcesFrom = {}
					    local originalTeamInfoReset = TeamInfo.Reset
					    local teamHasCommander = {}
					    teamHasCommander[kMarineTeamType] = GetTeamHasCommander(kMarineTeamType)
					    teamHasCommander[kAlienTeamType] = GetTeamHasCommander(kAlienTeamType)
					    TeamInfo.Reset = function(teamInfoSelf)
					    	originalTeamInfoReset(teamInfoSelf)
					    	if GetGamerules():GetGameState() == kGameState.NotStarted then
					    		local teamNumber = teamInfoSelf:GetTeamNumber()
					    		if not teamHasCommander[teamNumber] then
							    	local players = teamInfoSelf.team:GetPlayers()
							    	if #players > 0 then
								    	if teamInfoSelf.lastCommLoginTime == 0 then
								    		table.insert(clientsToTakeStartingPersonalResourcesFrom, TGNS.GetClient(TGNS.GetFirst(TGNS.GetRandomizedElements(players))))
								    		teamInfoSelf.lastCommLoginTime = Shared.GetTime()
								    	end
							    	end
					    		end
					    	end
						end
						TGNS.ForceGameStart()
						TGNS.DoFor(clientsToTakeStartingPersonalResourcesFrom, function(c)
							local playerToTakeStartingPersonalResourcesFrom = TGNS.GetPlayer(c)
				    		TGNS.SetPlayerResources(playerToTakeStartingPersonalResourcesFrom, 0)
				    		md:ToTeamNotifyInfo(TGNS.GetClientTeamNumber(c), string.format("%s started without a Commander. One teammate lost personal resources.", TGNS.GetClientTeamName(c)))
						end)
						TeamInfo.Reset = originalTeamInfoReset
					end)
				else
					secondsRemaining = secondsRemaining - 1
					TGNS.ScheduleAction(1, showTimeRemaining)
				end
			end
		end
	end
end

function Plugin:GetWhenFifteenSecondAfkTimerWasLastAdvertised()
	return fifteenSecondAfkTimerWasLastAdvertisedAt
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if not (TGNS.IsGameInProgress() or gameEndedRecently or Shine.Plugins.bots:GetTotalNumberOfBots() > 0) then
		local playerList = TGNS.GetPlayerList()
		local playingClients = TGNS.GetPlayingClients(playerList)
		local numberOfPlayingClients = #playingClients
		if timerInProgress then
			if numberOfPlayingClients == 0 then
				timerInProgress = false
				secondsRemaining = countdownSeconds
				if not Shine.Plugins.captains:IsCaptainsModeEnabled() then
					Shine.ScreenText.Add(51, {X = 0.5, Y = 0.45, Text = "Countdown halted.", Duration = 5, R = 255, G = 0, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true})
				end
			end
		else
			local numberOfPrimerSignersAmongPlayingClients = #TGNS.GetPrimerWithGamesClients(TGNS.GetPlayers(playingClients))
			local percentPrimerSignersAmongPlayingClients = numberOfPrimerSignersAmongPlayingClients / numberOfPlayingClients
			local serverIsHighPopulationAndMostlyPrimerSigners = numberOfPlayingClients >= Shine.Plugins.communityslots.Config.PublicSlots - 2 and percentPrimerSignersAmongPlayingClients >= 0.82
			if serverIsHighPopulationAndMostlyPrimerSigners and Shine.GetGamemode() == "ns2" then
				timerInProgress = true
				secondsRemaining = secondsRemaining or countdownSeconds
				secondsRemaining = (secondsRemaining >= 20 and secondsRemaining < countdownSeconds) and secondsRemaining or countdownSeconds
				showTimeRemaining()
			end
		end
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	secondsRemaining = countdownSeconds
	timerInProgress = false
	gameEndedRecently = true
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 1, function()
		gameEndedRecently = false
	end)
end

function Plugin:CreateCommands()
	local haltCountdownCommand = self:BindCommand( "sh_haltcountdown", "haltcountdown", function(client)
		timerInProgress = false
	end)
	haltCountdownCommand:Help( "Halt the forced game-start countdown." )
end

function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("timedstart", Plugin )