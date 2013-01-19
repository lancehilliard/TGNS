//NS2 Tournament Mod Server side script

if kDAKConfig and kDAKConfig.TournamentMode then

	local TournamentModeSettings = { countdownstarted = false, countdownstarttime = 0, countdownstartcount = 0, lastmessage = 0, official = false}
	local lastreadyalert = 0
	local gamepaused = false
	local gamepausedtime = 0
	local gamepausedmoveblock = 0
	
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
			
		elseif not kDAKConfig.TournamentMode.kTournamentModePubMode then
		
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
			if TournamentModeSettings.lastmessage + kDAKConfig.TournamentMode.kTournamentModeAlertDelay < Shared.GetTime() then
				DAKDisplayMessageToAllClients("kTournamentModePubPlayerWarning", kDAKConfig.TournamentMode.kTournamentModePubMinPlayersPerTeam)
				TournamentModeSettings.lastmessage = Shared.GetTime()
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
		
					if GetTournamentMode() and not kDAKConfig.TournamentMode.kTournamentModePubMode and (teamNumber == 1 or teamNumber == 2) then
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
		if state ~= nil and state ~= GetTournamentMode() then
			kDAKSettings.TournamentMode = state
			if client ~= nil then
				ServerAdminPrint(client, "TournamentMode " .. ConditionalValue(GetTournamentMode(), "enabled", "disabled"))
			else
				Shared.Message("TournamentMode " .. ConditionalValue(GetTournamentMode(), "enabled", "disabled"))
			end
			SaveDAKSettings()
			alert = true
		end
		if ffstate ~= nil and ffstate ~= GetFriendlyFire() then
			kDAKSettings.FriendlyFire = ffstate
			if client ~= nil then
				ServerAdminPrint(client, "FriendlyFire " .. ConditionalValue(GetFriendlyFire(), "enabled", "disabled"))
			else
				Shared.Message("FriendlyFire " .. ConditionalValue(GetTournamentMode(), "enabled", "disabled"))
			end
			
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
	
	if kDAKConfig.TournamentMode.kTournamentModePauseEnabled then
	
		local originalNS2PlayingTeamUpdateResourceTowers
		
		originalNS2PlayingTeamUpdateResourceTowers = Class_ReplaceMethod("PlayingTeam", "UpdateResourceTowers", 
			function(self)
	
				if GetTournamentMode() and gamepaused then
					return true
				end
				return originalNS2PlayingTeamUpdateResourceTowers(self)
				
			end
		)
		
		local originalNS2ResearchMixinUpdateResearch
		
		originalNS2ResearchMixinUpdateResearch = Class_ReplaceMethod("ResearchMixin", "UpdateResearch", 
			function(self, deltaTime)
	
				if GetTournamentMode() and gamepaused then
					return true
				end
				return originalNS2ResearchMixinUpdateResearch(self, deltaTime)
				
			end
		)
		
		local originalNS2CommanderProcessTechTreeAction
		
		originalNS2CommanderProcessTechTreeAction = Class_ReplaceMethod("Commander", "ProcessTechTreeAction", 
			function(self, techId, pickVec, orientation, worldCoordsSpecified)
	
				if GetTournamentMode() and gamepaused then
					return false
				end
				return originalNS2CommanderProcessTechTreeAction(self, techId, pickVec, orientation, worldCoordsSpecified)
				
			end
		)
		
		local originalNS2AlienTeamUpdate

		originalNS2AlienTeamUpdate = Class_ReplaceMethod("AlienTeam", "Update", 
			function(self, timePassed)
	
				if GetTournamentMode() and gamepaused then
					//Push out alien respawn time.
					self.timeLastWave = self.timeLastWave + timePassed
				end
				originalNS2AlienTeamUpdate(self, timePassed)
				
			end
		)
		
		local originalNS2HiveOnUpdate

		originalNS2HiveOnUpdate = Class_ReplaceMethod("Hive", "OnUpdate", 
			function(self, deltaTime)
	
				if GetTournamentMode() and gamepaused then
					CommandStructure.OnUpdate(self, deltaTime)
					return
				end
				originalNS2HiveOnUpdate(self, deltaTime)
				
			end
		)
		
		local originalNS2ConstructMixinConstruct

		originalNS2ConstructMixinConstruct = Class_ReplaceMethod("ConstructMixin", "Construct", 
			function(self, elapsedTime, builder)
	
				if GetTournamentMode() and gamepaused then
					return
				end
				originalNS2ConstructMixinConstruct(self, elapsedTime, builder)
				
			end
		)
		
		local originalNS2ShiftEnergizeInRange

		originalNS2ShiftEnergizeInRange = Class_ReplaceMethod("Shift", "EnergizeInRange", 
			function(self)
	
				if GetTournamentMode() and gamepaused then
					return true
				end
				return originalNS2ShiftEnergizeInRange(self)
				
			end
		)
		
		local originalNS2ShadeUpdateCloaking

		originalNS2ShadeUpdateCloaking = Class_ReplaceMethod("Shade", "UpdateCloaking", 
			function(self)
	
				if GetTournamentMode() and gamepaused then
					return true
				end
				return originalNS2ShadeUpdateCloaking(self)
				
			end
		)
		
		local originalNS2CommanderAbilityOnThink

		originalNS2CommanderAbilityOnThink = Class_ReplaceMethod("CommanderAbility", "OnThink", 
			function(self)
	
				if GetTournamentMode() and gamepaused then
					self:CreateRepeatEffect()
					//Set Think for next frame :/  Seems wierd, but hoping I can just delay any actions and have anything queued trigger correctly once resumed.
					self:SetNextThink(0.03)
				end
				return originalNS2CommanderAbilityOnThink(self)
				
			end
		)
		
		local originalNS2FireMixinComputeDamageOverrideMixin
		
		originalNS2FireMixinComputeDamageOverrideMixin = Class_ReplaceMethod("FireMixin", "ComputeDamageOverrideMixin", 
			function(self, attacker, damage, damageType, time)
	
				if GetTournamentMode() and gamepaused then
					return 0
				end
				return originalNS2FireMixinComputeDamageOverrideMixin(self, attacker, damage, damageType, time)
				
			end
		)
		
		local originalNS2DotMarkerOnUpdate
		
		originalNS2DotMarkerOnUpdate = Class_ReplaceMethod("DotMarker", "OnUpdate", 
			function(self, deltaTime)
	
				if GetTournamentMode() and gamepaused then
					self.timeLastUpdate = self.timeLastUpdate + deltaTime
				end
				originalNS2DotMarkerOnUpdate(self, deltaTime)
				
			end
		)
		
		local originalNS2DotMarkerOnCreate
		
		originalNS2DotMarkerOnCreate = Class_ReplaceMethod("DotMarker", "OnCreate", 
			function(self)
	
				self.adjustedcreationtime = Shared.GetTime()
				originalNS2DotMarkerOnCreate(self)
				
			end
		)
		
		local originalNS2DotMarkerTimeUp
		
		originalNS2DotMarkerTimeUp = Class_ReplaceMethod("DotMarker", "TimeUp", 
			function(self)
	
				if self.adjustedcreationtime + self.dotlifetime <= Shared.GetTime() then
					originalNS2DotMarkerTimeUp(self)
				else
					self:AddTimedCallback(DotMarker.TimeUp, math.max(self.adjustedcreationtime + self.dotlifetime - Shared.GetTime(), 0.1))
				end
				
			end
		)
		
		local originalNS2DotMarkerSetLifeTime
		
		originalNS2DotMarkerSetLifeTime = Class_ReplaceMethod("DotMarker", "SetLifeTime", 
			function(self, lifeTime)
	
				self.dotlifetime = lifeTime
				originalNS2DotMarkerSetLifeTime(self, lifeTime)
				
			end
		)
		
		local originalNS2PickupableMixin_DestroySelf
		
		originalNS2PickupableMixin_DestroySelf = Class_ReplaceMethod("PickupableMixin", "_DestroySelf", 
			function(self)
	
				if self.adjustedcreationtime + kItemStayTime <= Shared.GetTime() then
					originalNS2PickupableMixin_DestroySelf(self)
				else
					self:AddTimedCallback(PickupableMixin._DestroySelf, math.max(self.adjustedcreationtime + kItemStayTime - Shared.GetTime(), 0.1))
				end
				
			end
		)
		
		local originalNS2PickupableMixin__initmixin
		
		originalNS2PickupableMixin__initmixin = Class_ReplaceMethod("PickupableMixin", "__initmixin", 
			function(self)
	
				self.adjustedcreationtime = Shared.GetTime()
				originalNS2PickupableMixin__initmixin(self)
				
			end
		)
		
		local originalNS2PathingMixinMoveToTarget
		
		originalNS2PathingMixinMoveToTarget = Class_ReplaceMethod("PathingMixin", "MoveToTarget", 
			function(self, physicsGroupMask, endPoint, movespeed, time)
	
				if GetTournamentMode() and gamepaused then
					return false
				end
				return originalNS2PathingMixinMoveToTarget(self, physicsGroupMask, endPoint, movespeed, time)
				
			end
		)
		
		//No escaping the command structures pesky comms
		local originalNS2CommandStructureLogout
		
		originalNS2CommandStructureLogout = Class_ReplaceMethod("CommandStructure", "Logout", 
			function(self)
	
				if GetTournamentMode() and gamepaused then
					return self:GetCommander()
				end
				return originalNS2CommandStructureLogout(self)
				
			end
		)
		
	end
	
	local function PausedJoinTeam(self, player, newTeamNumber, force)
		if GetTournamentMode() and gamepaused and (newTeamNumber ~= 1 and newTeamNumber ~= 2) then
			return true
		end
	end
	
	local function UpdateMoveState(deltatime)
		if gamepaused then
			//Going to check and reblock player movement every second or so
			if gamepausedmoveblock + 1 < Shared.GetTime() then
				local playerRecords = Shared.GetEntitiesWithClassname("Player")
				for _, player in ientitylist(playerRecords) do
					if player ~= nil then
						player:BlockMove()
					end
				end
				gamepausedmoveblock = Shared.GetTime()
			end
			//Update time based stuff like respawns with difference it times
			//Update IPS Spawn Times
			local InfantryPortals = Shared.GetEntitiesWithClassname("InfantryPortal")
			for _, IP in ientitylist(InfantryPortals) do
				if IP.queuedPlayerStartTime ~= nil then
					IP.queuedPlayerStartTime = IP.queuedPlayerStartTime + deltatime
				end
			end
			//Update Crag lastheal
			//Set lastheal time to basically never occur but always ready to occur next frame if crag had never healed (probably rare, but might as well)
			local Crags = Shared.GetEntitiesWithClassname("Crag")
			for _, Crag in ientitylist(Crags) do
				if Crag.timeOfLastHeal == nil then Crag.timeOfLastHeal = (Shared.GetTime() - Crag.kHealInterval) end
				Crag.timeOfLastHeal = Crag.timeOfLastHeal + deltatime
			end
			//Ok gotta make some decisions here regarding what should be kept alive
			//Umbra,Spores,Ink,HealingWave,Bonewall,Scan
			local CommanderAbilities = Shared.GetEntitiesWithClassname("CommanderAbility")
			for _, CommanderAbility in ientitylist(CommanderAbilities) do
				CommanderAbility.timeCreated = CommanderAbility.timeCreated + deltatime
			end
			//Meds/Ammo
			local DropPacks = Shared.GetEntitiesWithClassname("DropPack")
			for _, DropPack in ientitylist(DropPacks) do
				DropPack.adjustedcreationtime = DropPack.adjustedcreationtime + deltatime
			end
			//Grenades
			local Grenades = Shared.GetEntitiesWithClassname("Grenade")
			for _, grenade in ientitylist(Grenades) do
				 if not grenade.endOfLife then
					grenade.endOfLife = Shared.GetTime() + kGrenadeLifetime
				end
				grenade.endOfLife = grenade.endOfLife + deltatime
			end
			//NanoShield
			local nanoshieldents = GetEntitiesWithMixin("NanoShieldAble")
			for _, nanoshieldent in ipairs(nanoshieldents) do
				if nanoshieldent:GetIsNanoShielded() then
					nanoshieldent.timeNanoShieldInit = nanoshieldent.timeNanoShieldInit + deltatime
				end
			end
			//Update anything thats teleporting to block - Echo
			local teleportEnts = GetEntitiesWithMixin("TeleportAble")
			for _, teleportEnt in ipairs(teleportEnts) do
				if teleportEnt.isTeleporting then 
					teleportEnt.timeUntilPort = teleportEnt.timeUntilPort + deltatime
				end
			end
			//Update Flamedamage init time
			local flameableEnts = GetEntitiesWithMixin("Fire")
			for _, flameableEnt in ipairs(flameableEnts) do
				if flameableEnt.timeBurnInit ~= 0 then 
					flameableEnt.timeBurnInit = flameableEnt.timeBurnInit + deltatime
				end
			end
			//Update DOTS (only BB???) lifetime
			local Dots = Shared.GetEntitiesWithClassname("DotMarker")
			for _, Dot in ientitylist(Dots) do
				dot.adjustedcreationtime = dot.adjustedcreationtime + deltatime
			end
			//Update Lerk Poison Bite
			local Poisoned = Shared.GetEntitiesWithClassname("Marine")
			for _, PM in ientitylist(Poisoned) do
				if PM.poisoned then
					if PM:GetIsAlive() and PM.timeLastPoisonDamage then
						PM.timeLastPoisonDamage = PM.timeLastPoisonDamage + deltatime
						PM.timePoisoned = PM.timePoisoned + deltatime
					end
				end
			end
		else
			local playerRecords = Shared.GetEntitiesWithClassname("Player")
			for _, player in ientitylist(playerRecords) do
				if player ~= nil then
					player:RetrieveMove()
				end
			end
			//Restore Maturity generation
			local gameEnts = GetEntitiesWithMixin("MaturityMixin")
			for _, ent in ipairs(gameEnts) do
				ent.updateMaturity = not HasMixin(self, "Construct") or self:GetIsBuilt()
			end
			//Update Next Thinks
			local CommanderAbilities = Shared.GetEntitiesWithClassname("CommanderAbility")
			for _, CommanderAbility in ientitylist(CommanderAbilities) do
				CommanderAbility:SetNextThink(math.max(CommanderAbility:GetThinkTime() - (Shared.GetTime() - CommanderAbility.timeCreated), 0.1))
			end
			gamepausedtime = 0
			DAKDeregisterEventHook(kDAKOnServerUpdateEveryFrame, UpdateMoveState)
			DAKDeregisterEventHook(kDAKOnTeamJoin, PausedJoinTeam)
		end
		//Kinda a crap/slow way of doing this, but if the server is paused we really dont care about server performance so kinda a moot point.  Do need to make sure that this 
		//encompasses all things that need to be blocked - there may be some exceptions.  Cant really fake gametime unless I adjust the starting point forward accordingly, which really isnt correct.
	end
	
	local function OnCommandPause(client)
		
		if kDAKConfig.TournamentMode.kTournamentModePauseEnabled and GetTournamentMode() then
			gamepaused = not gamepaused
			if gamepaused then
				//What needs to be blocked - played movement, commander abilities.  Researches paused, res income blocked.  Cant join spec.
				//Commander probably being the only difficult part - may get pretty wierd as there is no known client side effects that block your inputs fully.
				//Going to try just blocking techtree actions
				//Need to block respawns and eggs
				//Also block alien regen and crag heal
				local gameEnts = GetEntitiesWithMixin("MaturityMixin")
				
				for _, ent in ipairs(gameEnts) do
					ent.updateMaturity = false
				end
				//Cache real creation time
				local CommanderAbilities = Shared.GetEntitiesWithClassname("CommanderAbility")
				for _, CommanderAbility in ientitylist(CommanderAbilities) do
					CommanderAbility.timePausedCreated = CommanderAbility.timeCreated
				end
				//Block movement instantly so that its not updated each frame needlessly
				local playerRecords = Shared.GetEntitiesWithClassname("Player")
				for _, player in ientitylist(playerRecords) do
					if player ~= nil then
						player:BlockMove()
					end
				end
				gamepausedtime = Shared.GetTime()
				DAKRegisterEventHook(kDAKOnServerUpdateEveryFrame, UpdateMoveState, 5)
				DAKRegisterEventHook(kDAKOnTeamJoin, PausedJoinTeam, 5)
			end
			if client ~= nil then
				local player = client:GetControllingPlayer()
				if player ~= nil then
					PrintToAllAdmins("sv_pause", client)
				end
				ServerAdminPrint(client, "Game " .. ConditionalValue(gamepaused, "paused", "unpaused"))
			end
		end
		
	end
	
	DAKCreateServerAdminCommand("Console_sv_pause", OnCommandPause, "Will pause or resume current game.")

end

Shared.Message("TournamentMode Loading Complete")