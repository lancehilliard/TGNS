//NS2 Tournament Mod Server side script

if kDAKConfig and kDAKConfig.TournamentMode then

	local TournamentModeSettings = { countdownstarted = false, countdownstarttime = 0, countdownstartcount = 0, lastmessage = 0, official = false}
	local lastreadyalert = 0

	local function LoadTournamentMode()
		if kDAKSettings.TournamentMode then
			Shared.Message("TournamentMode Enabled")
			//EnhancedLog("TournamentMode Enabled")
		else
			kDAKSettings.TournamentMode = false
		end
		if kDAKSettings.FriendlyFire then
			Shared.Message("FriendlyFire Enabled")
			//EnhancedLog("FriendlyFire Enabled")
		else
			kDAKSettings.FriendlyFire = false
		end
	end

	LoadTournamentMode()

	function GetTournamentMode()
		return kDAKSettings.TournamentMode
	end
	
	local function BlockMapChange()
		return kDAKSettings.TournamentMode and not kDAKConfig.TournamentMode.kTournamentModePubMode
	end
	
	DAKRegisterEventHook(kDAKCheckMapChange, BlockMapChange, 5)
	
	function GetFriendlyFire()
		return kDAKSettings.FriendlyFire
	end
	
	local function StartCountdown(gamerules)
		if gamerules then
			gamerules:ResetGame() 
			//gamerules:ResetGame() - Dont think this is necessary anymore, and probably could potentially cause issues.  
			//Used this back when you could hear where the other team spawned to make it more difficult
			gamerules:SetGameState(kGameState.Countdown)      
			gamerules.countdownTime = kCountDownLength     
			gamerules.lastCountdownPlayed = nil 
		end
    end
	
	local function ClearTournamentModeState()
		TournamentModeSettings[1] = {ready = false, lastready = 0, captain = nil}
		TournamentModeSettings[2] = {ready = false, lastready = 0, captain = nil}
		TournamentModeSettings.countdownstarted = false
		TournamentModeSettings.countdownstarttime = 0
		TournamentModeSettings.countdownstartcount = 0
		TournamentModeSettings.lastmessage = 0
	end
	
	ClearTournamentModeState()
	
	local function CheckCancelGameStart()
		if TournamentModeSettings.countdownstarttime ~= 0 then
			DAKDisplayMessageToAllClients("kTournamentModeGameCancelled")
			TournamentModeSettings.countdownstarttime = 0
			TournamentModeSettings.countdownstartcount = 0
			TournamentModeSettings.countdownstarted = false
		end
	end
	
	local function MonitorCountDown()
	
		if TournamentModeSettings.countdownstarted then	
								
			if TournamentModeSettings.countdownstarttime - TournamentModeSettings.countdownstartcount < Shared.GetTime() and TournamentModeSettings.countdownstartcount ~= 0 then
				if (math.fmod(TournamentModeSettings.countdownstartcount, kDAKConfig.TournamentMode.kTournamentModeCountdownDelay) == 0 or TournamentModeSettings.countdownstartcount <= 5) then
					DAKDisplayMessageToAllClients("kTournamentModeCountdown", TournamentModeSettings.countdownstartcount)
				end
				TournamentModeSettings.countdownstartcount = TournamentModeSettings.countdownstartcount - 1
			end
			
			if TournamentModeSettings.countdownstarttime < Shared.GetTime() then
				ClearTournamentModeState()
				local gamerules = GetGamerules()
				if gamerules ~= nil then
					StartCountdown(gamerules)
				end
			end
			
		else
		
			if lastreadyalert + kDAKConfig.TournamentMode.kTournamentModeAlertDelay < Shared.GetTime() then
			
				if TournamentModeSettings[1].ready or TournamentModeSettings[2].ready then
					if TournamentModeSettings[1].ready then
						DAKDisplayMessageToAllClients("kTournamentModeTeamReadyAlert", 1, 2)
					else
						DAKDisplayMessageToAllClients("kTournamentModeTeamReadyAlert", 2, 1)
					end
				else
					DAKDisplayMessageToAllClients("kTournamentModeReadyAlert")
				end
				
				lastreadyalert = Shared.GetTime()
				
			end
			
		end
		
	end
	
	local function MonitorPubMode(gamerules)
		
		if gamerules and gamerules:GetTeam1():GetNumPlayers() >= kDAKConfig.TournamentMode.kTournamentModePubMinPlayersPerTeam and gamerules:GetTeam2():GetNumPlayers() >= kDAKConfig.TournamentMode.kTournamentModePubMinPlayersPerTeam then
			if not TournamentModeSettings.countdownstarted then
				TournamentModeSettings.countdownstarted = true
				TournamentModeSettings.countdownstarttime = Shared.GetTime() + kDAKConfig.TournamentMode.kTournamentModePubGameStartDelay
				TournamentModeSettings.countdownstartcount = kDAKConfig.TournamentMode.kTournamentModePubGameStartDelay
			end
		else
			CheckCancelGameStart()
			if TournamentModeSettings.lastpubmessage + kDAKConfig.TournamentMode.kTournamentModePubAlertDelay < Shared.GetTime() then
				DAKDisplayMessageToAllClients("kTournamentModePubPlayerWarning", kDAKConfig.TournamentMode.kTournamentModePubMinPlayersPerTeam)
				TournamentModeSettings.lastpubmessage = Shared.GetTime()
			end
		end

	end
	
	local function TournamentModeOnDisconnect(client)
		if TournamentModeSettings.countdownstarted and not kDAKConfig.TournamentMode.kTournamentModePubMode then
			CheckCancelGameStart()
		end
	end
	
	DAKRegisterEventHook(kDAKOnClientDisconnect, TournamentModeOnDisconnect, 5)
	
	local function UpdatePregame(self, timePassed)
	
		if self and GetTournamentMode() and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() and self:GetGameState() == kGameState.PreGame and 
		(not kDAKConfig.TournamentMode.kTournamentModePubMode or #EntityListToTable(Shared.GetEntitiesWithClassname("Player")) >= kDAKConfig.TournamentMode.kTournamentModePubMinPlayersOnline) then
			if kDAKConfig.TournamentMode.kTournamentModePubMode then
				MonitorPubMode(self)
			end
			MonitorCountDown()
			return true
		end
		
	end
	
	DAKRegisterEventHook(kDAKOnUpdatePregame, UpdatePregame, 6)
		
	if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.GamerulesExtensions then
		if kDAKConfig.TournamentMode.kTournamentModeOverrideCanJoinTeam then
			local originalNS2GRGetCanJoinTeamNumber
			
			originalNS2GRGetCanJoinTeamNumber = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "GetCanJoinTeamNumber", 
				function(self, teamNumber)
		
					if GetTournamentMode() and (teamNumber == 1 or teamNumber == 2) then
						return true
					end
					return originalNS2GRGetCanJoinTeamNumber(self, teamNumber)
					
				end
			)
		end
	end
	
	local function EnablePCWMode(client)
		DAKDisplayMessageToAllClients("kTournamentModePCWMode")
	end	
	
	local function EnableOfficialMode(client)
		DAKDisplayMessageToAllClients("kTournamentModeOfficialsMode")
		//eventually add additional req. for offical matches
	end

	local function OnCommandTournamentMode(client, state, ffstate, newmode)
		local alert = false
		if (state ~= true or state ~= false) and state ~= nil then
			local newstate = tonumber(state)
			assert(type(newstate) == "number")
			if newstate > 0 then
				state = true
			else
				state = false
			end
		end
		if (ffstate ~= true or ffstate ~= false) and ffstate ~= nil then
			local newffstate = tonumber(ffstate)
			assert(type(newffstate) == "number")
			if newffstate > 0 then
				ffstate = true
			else
				ffstate = false
			end
		end
		if (newmode ~= true or newmode ~= false) and newmode ~= nil then
			local newnummode = tonumber(newmode)
			assert(type(newnummode) == "number")
			if newnummode > 0 then
				newmode = true
			else
				newmode = false
			end
		end
		if state ~= nil and state ~= GetTournamentMode() then
			kDAKSettings.TournamentMode = state
			ServerAdminPrint(client, "TournamentMode " .. ConditionalValue(GetTournamentMode(), "enabled", "disabled"))
			SaveDAKSettings()
			alert = true
		end
		if ffstate ~= nil and ffstate ~= GetFriendlyFire() then
			kDAKSettings.FriendlyFire = ffstate
			ServerAdminPrint(client, "FriendlyFire " .. ConditionalValue(GetFriendlyFire(), "enabled", "disabled"))
			SaveDAKSettings()
			alert = true
		end
		if newmode ~= nil and TournamentModeSettings.official ~= newmode then
			if newmode == true then
				EnableOfficialMode(client)
			elseif newmode == false then
				EnablePCWMode(client)
			end
			TournamentModeSettings.official = newmode
			alert = true
		end
		PrintToAllAdmins("sv_tournamentmode", client, " " .. ToString(state) .. " " .. ToString(ffstate) .. " " .. ToString(newmode))
		if not alert then
			ServerAdminPrint(client, string.format("Tournamentmode set to - " .. ToString(kDAKSettings.TournamentMode)
				.. " FriendlyFire set to - " .. ToString(kDAKSettings.FriendlyFire)
				.. " Official set to - ".. ToString(TournamentModeSettings.official)))
		end
	end

	DAKCreateServerAdminCommand("Console_sv_tournamentmode", OnCommandTournamentMode, "<state> <ffstate> <mode> Enable/Disable tournament mode, friendlyfire or change mode (PCW/OFFICIAL).")
	
	local function OnCommandSetupCaptain(client, teamnum, captain)
	
		local tmNum = tonumber(teamnum)
		local cp = tonumber(captain)
		assert(type(tmNum) == "number")
		assert(type(cp) == "number")
		if tmNum == 1 or tmNum == 2 and client then
			if GetClientMatchingGameId(cp) then
				TournamentModeSettings[tmNum].captain = GetClientMatchingGameId(cp):GetUserId()
			else
				TournamentModeSettings[tmNum].captain = captain
			end
			ServerAdminPrint(client, string.format("Team captain for team %s set to %s", tmNum, TournamentModeSettings[tmNum].captain))
		end
		if client ~= nil then 
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_setcaptain", client, " " .. ToString(tmNum) .. " " .. ToString(cp))
			end
		end
		
	end
	
	DAKCreateServerAdminCommand("Console_sv_setcaptain", OnCommandSetupCaptain, "<team> <captain> Set the captain for a team by gameid/steamid.")
	
	local function OnCommandForceStartRound(client)
	
		ClearTournamentModeState()
		local gamerules = GetGamerules()
		if gamerules ~= nil then
			StartCountdown(gamerules)
		end
		
		if client ~= nil then 
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_forceroundstart", client)
			end
		end
	end
	
	DAKCreateServerAdminCommand("Console_sv_forceroundstart", OnCommandForceStartRound, "Force start a round in tournamentmode.")
	
	local function OnCommandCancelRoundStart(client)
	
		CheckCancelGameStart()
		ClearTournamentModeState()
		
		if client ~= nil then 
			local player = client:GetControllingPlayer()
			if player ~= nil then
				PrintToAllAdmins("sv_cancelroundstart", client)
			end
		end
	end
	
	DAKCreateServerAdminCommand("Console_sv_cancelroundstart", OnCommandCancelRoundStart, "Cancel the start of a round in tournamentmode.")

	local function CheckGameCountdownStart()
		if TournamentModeSettings[1].ready and TournamentModeSettings[2].ready then
			TournamentModeSettings.countdownstarted = true
			TournamentModeSettings.countdownstarttime = Shared.GetTime() + kDAKConfig.TournamentMode.kTournamentModeGameStartDelay
			TournamentModeSettings.countdownstartcount = kDAKConfig.TournamentMode.kTournamentModeGameStartDelay
		end
	end
	
	local function ClientReady(client)
	
		local player = client:GetControllingPlayer()
		local playername = player:GetName()
		local teamnum = player:GetTeamNumber()
		local clientid = client:GetUserId()
		if teamnum == 1 or teamnum == 2 then
			if TournamentModeSettings.official and TournamentModeSettings[teamnum].captain then			
				if TournamentModeSettings[teamnum].lastready + kDAKConfig.TournamentMode.kTournamentModeReadyDelay < Shared.GetTime() and TournamentModeSettings[teamnum].captain == clientid then
					TournamentModeSettings[teamnum].ready = not TournamentModeSettings[teamnum].ready
					TournamentModeSettings[teamnum].lastready = Shared.GetTime()
					DAKDisplayMessageToAllClients("kTournamentModeTeamReady", playername, ConditionalValue(TournamentModeSettings[teamnum].ready, "readied", "unreadied"), teamnum)
					CheckGameCountdownStart()
				end
			elseif not TournamentModeSettings.official then
				if TournamentModeSettings[teamnum].lastready + kDAKConfig.TournamentMode.kTournamentModeReadyDelay < Shared.GetTime() then
					TournamentModeSettings[teamnum].ready = not TournamentModeSettings[teamnum].ready
					TournamentModeSettings[teamnum].lastready = Shared.GetTime()
					DAKDisplayMessageToAllClients("kTournamentModeTeamReady", playername, ConditionalValue(TournamentModeSettings[teamnum].ready, "readied", "unreadied"), teamnum)
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
			if GetTournamentMode() and (gamerules:GetGameState() == kGameState.NotStarted or gamerules:GetGameState() == kGameState.PreGame) and not kDAKConfig.TournamentMode.kTournamentModePubMode then
				if not isCaptainsMode() or isCaptain(client:GetUserId()) then
					ClientReady(client)
				end
			end
		end
	end

	Event.Hook("Console_ready",                 OnCommandReady)
		
	local function OnTournamentModeChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
	
		if client and steamId and steamId ~= 0 then
			for c = 1, #kDAKConfig.TournamentMode.kReadyChatCommands do
				local chatcommand = kDAKConfig.TournamentMode.kReadyChatCommands[c]
				if message == chatcommand then
					OnCommandReady(client)
				end
			end
		end
	
	end
	
	DAKRegisterEventHook(kDAKOnClientChatMessage, OnTournamentModeChatMessage, 5)

end

Shared.Message("TournamentMode Loading Complete")