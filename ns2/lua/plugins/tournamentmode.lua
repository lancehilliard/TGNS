//NS2 Tournament Mod Server side script

local TournamentModeSettings = { countdownstarted = false, countdownstarttime = 0, countdownstartcount = 0, lastmessage = 0, official = false, roundstarted = 0}

local function LoadTournamentMode()
	if DAK.settings.TournamentMode then
		//Shared.Message("TournamentMode Enabled")
		DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, "TournamentMode Enabled")
	else
		DAK.settings.TournamentMode = false
	end
	if DAK.settings.FriendlyFire then
		//Shared.Message("FriendlyFire Enabled")
		DAK:ExecutePluginGlobalFunction("enhancedlogging", EnhancedLogMessage, "FriendlyFire Enabled")
	else
		DAK.settings.FriendlyFire = false
	end
end

LoadTournamentMode()

local function BlockMapChange()
	return DAK.settings.TournamentMode and not DAK.config.tournamentmode.kTournamentModePubMode
end

DAK:RegisterEventHook("CheckMapChange", BlockMapChange, 5, "tournamentmode")

local function ResetPlayerScores()
	for _, player in ientitylist(Shared.GetEntitiesWithClassname("Player")) do            
		if player.ResetScores then
			player:ResetScores()
		end            
	end
end

local function StartCountdown(gamerules)
	if gamerules then
		gamerules:ResetGame() 
		//gamerules:ResetGame() - Dont think this is necessary anymore, and probably could potentially cause issues.  
		//Used this back when you could hear where the other team spawned to make it more difficult
		gamerules:SetGameState(kGameState.Countdown)      
		ResetPlayerScores()
		gamerules.countdownTime = kCountDownLength 
		gamerules.lastCountdownPlayed = nil 
		TournamentModeSettings.roundstarted = Shared.GetTime()
		//kTournamentModeRestartDuration
	end
end

local function ClearTournamentModeState()
	TournamentModeSettings[1] = {ready = false, lastready = 0, captain = nil}
	TournamentModeSettings[2] = {ready = false, lastready = 0, captain = nil}
	TournamentModeSettings.countdownstarted = false
	TournamentModeSettings.countdownstarttime = 0
	TournamentModeSettings.countdownstartcount = 0
	TournamentModeSettings.lastmessage = 0
	TournamentModeSettings.roundstarted = 0
end

ClearTournamentModeState()

local function CheckCancelGameStart()
	if TournamentModeSettings.countdownstarttime ~= 0 then
		DAK:DisplayMessageToAllClients("TournamentModeGameCancelled")
		TournamentModeSettings.countdownstarttime = 0
		TournamentModeSettings.countdownstartcount = 0
		TournamentModeSettings.countdownstarted = false
	end
end

local function CheckGameStart(gamerules)
	if TournamentModeSettings.countdownstarttime < Shared.GetTime() then
		ClearTournamentModeState()
		if gamerules ~= nil then
			StartCountdown(gamerules)
		end
	end
end

local function AnnounceTournamentModeCountDown(gamerules)

	if TournamentModeSettings.countdownstarted and TournamentModeSettings.countdownstarttime - TournamentModeSettings.countdownstartcount < Shared.GetTime() and TournamentModeSettings.countdownstartcount ~= 0 then
		if (math.fmod(TournamentModeSettings.countdownstartcount, DAK.config.tournamentmode.kTournamentModeCountdownDelay) == 0 or TournamentModeSettings.countdownstartcount <= 5) then
			DAK:DisplayMessageToAllClients("TournamentModeCountdown", TournamentModeSettings.countdownstartcount)
		end
		TournamentModeSettings.countdownstartcount = TournamentModeSettings.countdownstartcount - 1
	end
	
end

local function MonitorCountDown(gamerules)

	if not TournamentModeSettings.countdownstarted then
		if TournamentModeSettings.lastmessage + DAK.config.tournamentmode.kTournamentModeAlertDelay < Shared.GetTime() then
			if TournamentModeSettings[1].ready or TournamentModeSettings[2].ready then
				if TournamentModeSettings[1].ready then
					DAK:DisplayMessageToAllClients("TournamentModeTeamReadyAlert", DAK.config.loader.TeamOneName, DAK.config.loader.TeamTwoName)
				else
					DAK:DisplayMessageToAllClients("TournamentModeTeamReadyAlert", DAK.config.loader.TeamTwoName, DAK.config.loader.TeamOneName)
				end
			else
				DAK:DisplayMessageToAllClients("TournamentModeReadyAlert")
			end
			TournamentModeSettings.lastmessage = Shared.GetTime()
		end
	else
		AnnounceTournamentModeCountDown(gamerules)
		CheckGameStart(gamerules)
	end
	
end

local function MonitorPubMode(gamerules)
	
	if gamerules and gamerules:GetTeam1():GetNumPlayers() >= DAK.config.tournamentmode.kTournamentModePubMinPlayersPerTeam and 
		gamerules:GetTeam2():GetNumPlayers() >= DAK.config.tournamentmode.kTournamentModePubMinPlayersPerTeam then
		if not TournamentModeSettings.countdownstarted then
			TournamentModeSettings.countdownstarted = true
			TournamentModeSettings.countdownstarttime = Shared.GetTime() + DAK.config.tournamentmode.kTournamentModePubGameStartDelay
			TournamentModeSettings.countdownstartcount = DAK.config.tournamentmode.kTournamentModePubGameStartDelay
		else
			AnnounceTournamentModeCountDown(gamerules)
			CheckGameStart(gamerules)
		end
	else
		CheckCancelGameStart()
		if TournamentModeSettings.lastmessage + DAK.config.tournamentmode.kTournamentModeAlertDelay < Shared.GetTime() then
			DAK:DisplayMessageToAllClients("TournamentModePubPlayerWarning", DAK.config.tournamentmode.kTournamentModePubMinPlayersPerTeam)
			TournamentModeSettings.lastmessage = Shared.GetTime()
		end
	end

end

local function TournamentModeOnDisconnect(client)
	if DAK.settings.TournamentMode and TournamentModeSettings.countdownstarted and not DAK.config.tournamentmode.kTournamentModePubMode then
		CheckCancelGameStart()
	end
end

DAK:RegisterEventHook("OnClientDisconnect", TournamentModeOnDisconnect, 5, "tournamentmode")

local function UpdatePregame(self, timePassed)

	if self and DAK.settings.TournamentMode and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() and self:GetGameState() == kGameState.PreGame then
		if DAK.config.tournamentmode.kTournamentModePubMode then
			if Server.GetNumPlayers() >= DAK.config.tournamentmode.kTournamentModePubMinPlayersOnline then
				MonitorPubMode(self)
				return true
			end
		else
			MonitorCountDown(self)
			return true
		end
	end
	
end

DAK:RegisterEventHook("OnUpdatePregame", UpdatePregame, 6, "tournamentmode")
	
local function OnPluginInitialized()

	kFriendlyFireScalar = DAK.config.tournamentmode.kTournamentModeFriendlyFirePercent

	if DAK.config.tournamentmode.kTournamentModeOverrideCanJoinTeam then
		local originalNS2GRGetCanJoinTeamNumber
		
		originalNS2GRGetCanJoinTeamNumber = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "GetCanJoinTeamNumber", 
			function(self, teamNumber)
	
				if DAK.settings.TournamentMode and not DAK.config.tournamentmode.kTournamentModePubMode and (teamNumber == 1 or teamNumber == 2) then
					return true
				end
				return originalNS2GRGetCanJoinTeamNumber(self, teamNumber)
				
			end
		)
	end

end

if DAK.config and DAK.config.loader and DAK.config.loader.GamerulesExtensions then
	DAK:RegisterEventHook("OnPluginInitialized", OnPluginInitialized, 5, "tournamentmode")
end

local function EnablePCWMode(client)
	DAK:DisplayMessageToAllClients("TournamentModePCWMode")
end	

local function EnableOfficialMode(client)
	DAK:DisplayMessageToAllClients("TournamentModeOfficialsMode")
	//eventually add additional req. for offical matches
	//Update certain console commands on clients to force consistency
	//Server.SendCommand(player, "net_lag 0")
	//Server.SendCommand(player, "r_pq true")
	//Server.SendCommand(player, "r_particles true")
end

local function OnCommandTournamentMode(client, state, ffstate, newmode)
	local alert = false
	if state ~= nil then
		local newstate = tonumber(state)
		if newstate > 0 then
			state = true
		else
			state = false
		end
	end
	if ffstate ~= nil then
		local newffstate = tonumber(ffstate)
		if newffstate > 0 then
			ffstate = true
		else
			ffstate = false
		end
	end
	if newmode ~= nil then
		local newnummode = tonumber(newmode)
		if newnummode > 0 then
			newmode = true
		else
			newmode = false
		end
	end
	if state ~= nil and state ~= DAK.settings.TournamentMode then
		DAK.settings.TournamentMode = state
		ServerAdminPrint(client, "TournamentMode " .. ConditionalValue(DAK.settings.TournamentMode, "enabled", "disabled"))
		DAK:SaveSettings()
		alert = true
	end
	if ffstate ~= nil and ffstate ~= DAK.settings.FriendlyFire then
		DAK.settings.FriendlyFire = ffstate
		ServerAdminPrint(client, "FriendlyFire " .. ConditionalValue(DAK.settings.FriendlyFire, "enabled", "disabled"))		
		DAK:SaveSettings()
		alert = true
	end
	if client ~= nil and newmode ~= nil and TournamentModeSettings.official ~= newmode then
		if newmode == true then
			EnableOfficialMode(client)
		elseif newmode == false then
			EnablePCWMode(client)
		end
		TournamentModeSettings.official = newmode
		alert = true
	end
	if not alert then 		
		ServerAdminPrint(client, string.format("Tournamentmode set to - " .. ToString(DAK.settings.TournamentMode)
			.. " FriendlyFire set to - " .. ToString(DAK.settings.FriendlyFire)
			.. " Official set to - ".. ToString(TournamentModeSettings.official)))
	end
	DAK:PrintToAllAdmins("sv_tournamentmode", client, ToString(state) .. " " .. ToString(ffstate) .. " " .. ToString(newmode))
	
end

DAK:CreateServerAdminCommand("Console_sv_tournamentmode", OnCommandTournamentMode, "<state> <ffstate> <mode> Enable/Disable tournament mode, friendlyfire or change mode (PCW/OFFICIAL).")

local function OnCommandSetupCaptain(client, teamnum, captain)

	local tmNum = tonumber(teamnum)
	local cp = tonumber(captain)
	assert(type(tmNum) == "number")
	assert(type(cp) == "number")
	if tmNum == 1 or tmNum == 2 then
		if DAK:GetClientMatchingGameId(cp) then
			TournamentModeSettings[tmNum].captain = DAK:GetClientMatchingGameId(cp):GetUserId()
		else
			TournamentModeSettings[tmNum].captain = captain
		end
		ServerAdminPrint(client, string.format("Team captain for team %s set to %s", tmNum, TournamentModeSettings[tmNum].captain))
	end
	DAK:PrintToAllAdmins("sv_setcaptain", client, " " .. ToString(tmNum) .. " " .. ToString(cp))
	
end

DAK:CreateServerAdminCommand("Console_sv_setcaptain", OnCommandSetupCaptain, "<team> <captain> Set the captain for a team by gameid/steamid.")

local function OnCommandForceStartRound(client)

	ClearTournamentModeState()
	local gamerules = GetGamerules()
	if gamerules ~= nil then
		StartCountdown(gamerules)
	end
	
	DAK:PrintToAllAdmins("sv_forceroundstart", client)
	
end

DAK:CreateServerAdminCommand("Console_sv_forceroundstart", OnCommandForceStartRound, "Force start a round in tournamentmode.")

local function OnCommandCancelRoundStart(client)

	CheckCancelGameStart()
	ClearTournamentModeState()
	
	DAK:PrintToAllAdmins("sv_cancelroundstart", client)

end

DAK:CreateServerAdminCommand("Console_sv_cancelroundstart", OnCommandCancelRoundStart, "Cancel the start of a round in tournamentmode.")

local function CheckGameCountdownStart()
	if TournamentModeSettings[1].ready and TournamentModeSettings[2].ready then
		TournamentModeSettings.countdownstarted = true
		TournamentModeSettings.countdownstarttime = Shared.GetTime() + DAK.config.tournamentmode.kTournamentModeGameStartDelay
		TournamentModeSettings.countdownstartcount = DAK.config.tournamentmode.kTournamentModeGameStartDelay
	end
end

local function ClientReady(client)

	local player = client:GetControllingPlayer()
	local playername = player:GetName()
	local teamnum = player:GetTeamNumber()
	local clientid = client:GetUserId()
	if teamnum == 1 or teamnum == 2 then
		if TournamentModeSettings.official and TournamentModeSettings[teamnum].captain then			
			if TournamentModeSettings[teamnum].lastready + DAK.config.tournamentmode.kTournamentModeReadyDelay < Shared.GetTime() and TournamentModeSettings[teamnum].captain == clientid then
				TournamentModeSettings[teamnum].ready = not TournamentModeSettings[teamnum].ready
				TournamentModeSettings[teamnum].lastready = Shared.GetTime()
				DAK:DisplayMessageToAllClients("TournamentModeTeamReady", playername, ConditionalValue(TournamentModeSettings[teamnum].ready, "readied", "unreadied"), ConditionalValue(teamnum == 1, DAK.config.loader.TeamOneName, DAK.config.loader.TeamTwoName))
				CheckGameCountdownStart()
			end
		elseif not TournamentModeSettings.official then
			if TournamentModeSettings[teamnum].lastready + DAK.config.tournamentmode.kTournamentModeReadyDelay < Shared.GetTime() then
				TournamentModeSettings[teamnum].ready = not TournamentModeSettings[teamnum].ready
				TournamentModeSettings[teamnum].lastready = Shared.GetTime()
				DAK:DisplayMessageToAllClients("TournamentModeTeamReady", playername, ConditionalValue(TournamentModeSettings[teamnum].ready, "readied", "unreadied"), ConditionalValue(teamnum == 1, DAK.config.loader.TeamOneName, DAK.config.loader.TeamTwoName))
				CheckGameCountdownStart()
			end
		end
	end
	if teamoneready == false or teamtwoready == false then
		CheckCancelGameStart()
	end
	
end

local function OnCommandReady(client)
	local gamerules = GetGamerules()
	if gamerules ~= nil and client ~= nil then
		if DAK.settings.TournamentMode and (gamerules:GetGameState() == kGameState.NotStarted or gamerules:GetGameState() == kGameState.PreGame or (TournamentModeSettings.roundstarted ~= 0 and TournamentModeSettings.roundstarted + DAK.config.tournamentmode.kTournamentModeRestartDuration < Shared.GetTime())) and not DAK.config.tournamentmode.kTournamentModePubMode then
			gamerules:SetGameState(kGameState.PreGame)
			ClientReady(client)
		end
	end
end

Event.Hook("Console_ready",                 OnCommandReady)

DAK:RegisterChatCommand(DAK.config.tournamentmode.kReadyChatCommands, OnCommandReady, false)