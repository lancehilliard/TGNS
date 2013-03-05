//NS2 Pause Plugin

local gamestate = {
gamepaused = false,
gamepausedtime = 0,
gamepausedcountdown = 0,
gamepausedmessagetime = 0,
gamepausingteam = 0,
team1pauses = 0,
team2pauses = 0, 
team1resume = false, 
team2resume = false
}

local function OnPluginInitialized()

	local originalNS2PlayingTeamUpdateResourceTowers

	originalNS2PlayingTeamUpdateResourceTowers = Class_ReplaceMethod("PlayingTeam", "UpdateResourceTowers", 
		function(self)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return true
			end
			return originalNS2PlayingTeamUpdateResourceTowers(self)
			
		end
	)

	local originalNS2ResearchMixinUpdateResearch

	originalNS2ResearchMixinUpdateResearch = Class_ReplaceMethod("ResearchMixin", "UpdateResearch", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return true
			end
			return originalNS2ResearchMixinUpdateResearch(self, deltaTime)
			
		end
	)

	local originalNS2CommanderProcessTechTreeAction

	originalNS2CommanderProcessTechTreeAction = Class_ReplaceMethod("Commander", "ProcessTechTreeAction", 
		function(self, techId, pickVec, orientation, worldCoordsSpecified)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return false
			end
			return originalNS2CommanderProcessTechTreeAction(self, techId, pickVec, orientation, worldCoordsSpecified)
			
		end
	)

	local originalNS2AlienTeamUpdate

	originalNS2AlienTeamUpdate = Class_ReplaceMethod("AlienTeam", "Update", 
		function(self, timePassed)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				//Push out alien respawn time.
				if self.timeNextWave ~= nil then
					self.timeNextWave = self.timeNextWave + timePassed
				end
				if self.timeOfLastAutoHeal ~= nil then
					self.timeOfLastAutoHeal = self.timeOfLastAutoHeal + timePassed
				end
			end
			originalNS2AlienTeamUpdate(self, timePassed)
			
		end
	)

	local originalNS2HiveOnUpdate

	originalNS2HiveOnUpdate = Class_ReplaceMethod("Hive", "OnUpdate", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				CommandStructure.OnUpdate(self, deltaTime)
				return
			end
			originalNS2HiveOnUpdate(self, deltaTime)
			
		end
	)

	local originalNS2ConstructMixinConstruct

	originalNS2ConstructMixinConstruct = Class_ReplaceMethod("ConstructMixin", "Construct", 
		function(self, elapsedTime, builder)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2ConstructMixinConstruct(self, elapsedTime, builder)
			
		end
	)

	local originalNS2ShiftEnergizeInRange

	originalNS2ShiftEnergizeInRange = Class_ReplaceMethod("Shift", "EnergizeInRange", 
		function(self)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return true
			end
			return originalNS2ShiftEnergizeInRange(self)
			
		end
	)

	local originalNS2CommanderAbilityOnThink

	originalNS2CommanderAbilityOnThink = Class_ReplaceMethod("CommanderAbility", "OnThink", 
		function(self)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
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

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return 0
			end
			return originalNS2FireMixinComputeDamageOverrideMixin(self, attacker, damage, damageType, time)
			
		end
	)

	local originalNS2DotMarkerOnUpdate

	originalNS2DotMarkerOnUpdate = Class_ReplaceMethod("DotMarker", "OnUpdate", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
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
				self:AddTimedCallback(DotMarker.TimeUp, math.max(self.adjustedcreationtime + self.dotlifetime - Shared.GetTime() + 0.1, 0.1))
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

	local originalNS2PickupableMixin__initmixin

	originalNS2PickupableMixin__initmixin = Class_ReplaceMethod("PickupableMixin", "__initmixin", 
		function(self)

			self.adjustedcreationtime = Shared.GetTime()
			originalNS2PickupableMixin__initmixin(self)
			
		end
	)

	local originalNS2PickupableMixin_DestroySelf

	originalNS2PickupableMixin_DestroySelf = Class_ReplaceMethod("PickupableMixin", "_DestroySelf", 
		function(self)

			if self.adjustedcreationtime + kItemStayTime <= Shared.GetTime() then
				originalNS2PickupableMixin_DestroySelf(self)
			else
				self:AddTimedCallback(PickupableMixin._DestroySelf, math.max(self.adjustedcreationtime + kItemStayTime - Shared.GetTime() + 0.5, 0.5))
			end
			
		end
	)

	local originalNS2PathingMixinMoveToTarget

	originalNS2PathingMixinMoveToTarget = Class_ReplaceMethod("PathingMixin", "MoveToTarget", 
		function(self, physicsGroupMask, endPoint, movespeed, time)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return false
			end
			return originalNS2PathingMixinMoveToTarget(self, physicsGroupMask, endPoint, movespeed, time)
			
		end
	)

	//No escaping the command structures pesky comms
	local originalNS2CommandStructureLogout

	originalNS2CommandStructureLogout = Class_ReplaceMethod("CommandStructure", "Logout", 
		function(self)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return self:GetCommander()
			end
			return originalNS2CommandStructureLogout(self)
			
		end
	)

	local originalNS2CommanderHandleButtons

	originalNS2CommanderHandleButtons = Class_ReplaceMethod("Commander", "HandleButtons", 
		function(self, input)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2CommanderHandleButtons(self, input)
			
		end
	)

	local originalNS2MaturityMixinOnUpdate

	originalNS2MaturityMixinOnUpdate = Class_ReplaceMethod("MaturityMixin", "OnUpdate", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2MaturityMixinOnUpdate(self, deltaTime)
			
		end
	)

	local originalNS2MaturityMixinOnProcessMove

	originalNS2MaturityMixinOnProcessMove = Class_ReplaceMethod("MaturityMixin", "OnProcessMove", 
		function(self, input)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2MaturityMixinOnProcessMove(self, input)
			
		end
	)

	local originalNS2FireMixinOnUpdate

	originalNS2FireMixinOnUpdate = Class_ReplaceMethod("FireMixin", "OnUpdate", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2FireMixinOnUpdate(self, deltaTime)
			
		end
	)

	local originalNS2FireMixinOnProcessMove

	originalNS2FireMixinOnProcessMove = Class_ReplaceMethod("FireMixin", "OnProcessMove", 
		function(self, input)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2FireMixinOnProcessMove(self, input)
			
		end
	)

	local originalNS2AlienUpdateAutoHeal

	originalNS2AlienUpdateAutoHeal = Class_ReplaceMethod("Alien", "UpdateAutoHeal", 
		function(self)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2AlienUpdateAutoHeal(self)
			
		end
	)

	local originalNS2ClipWeaponOnTag

	originalNS2ClipWeaponOnTag = Class_ReplaceMethod("ClipWeapon", "OnTag", 
		function(self, tagName)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2ClipWeaponOnTag(self, tagName)
			
		end
	)

	local originalNS2ClipWeaponOnUpdateAnimationInput

	originalNS2ClipWeaponOnUpdateAnimationInput = Class_ReplaceMethod("ClipWeapon", "OnUpdateAnimationInput", 
		function(self, modelMixin)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2ClipWeaponOnUpdateAnimationInput(self, modelMixin)
			
		end
	)

	local originalNS2ARCAcquireTarget

	originalNS2ARCAcquireTarget = Class_ReplaceMethod("ARC", "AcquireTarget", 
		function(self)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				self:SetMode(ARC.kMode.Stationary)
				return
			end
			originalNS2ARCAcquireTarget(self, modelMixin)
			
		end
	)

	local originalNS2ARCOnTag

	originalNS2ARCOnTag = Class_ReplaceMethod("ARC", "OnTag", 
		function(self, tagName)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				//Force stop to make sure it doesnt constantly fire needlessly
				self:SetMode(ARC.kMode.Stationary)
				return
			end
			originalNS2ARCOnTag(self, tagName)
			
		end
	)

	local originalNS2ArmoryGetShouldResupplyPlayer

	originalNS2ArmoryGetShouldResupplyPlayer = Class_ReplaceMethod("Armory", "GetShouldResupplyPlayer", 
		function(self, player)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return false
			end
			return originalNS2ArmoryGetShouldResupplyPlayer(self, player)
			
		end
	)

	local originalNS2MACOnUpdate

	originalNS2MACOnUpdate = Class_ReplaceMethod("MAC", "OnUpdate", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2MACOnUpdate(self, deltaTime)
			
		end
	)

	local originalNS2MACProcessBuildConstruct

	originalNS2MACProcessBuildConstruct = Class_ReplaceMethod("MAC", "ProcessBuildConstruct", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2MACProcessBuildConstruct(self, deltaTime)
			
		end
	)

	local originalNS2MACProcessWeldOrder

	originalNS2MACProcessWeldOrder = Class_ReplaceMethod("MAC", "ProcessWeldOrder", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2MACProcessWeldOrder(self, deltaTime)
			
		end
	)

	local originalNS2AiAttacksMixinOnTag

	originalNS2AiAttacksMixinOnTag = Class_ReplaceMethod("AiAttacksMixin", "OnTag", 
		function(self, tagName)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2AiAttacksMixinOnTag(self, tagName)		

		end
	)

	local originalNS2MinimapMoveMixinUpdateMove

	originalNS2MinimapMoveMixinUpdateMove = Class_ReplaceMethod("MinimapMoveMixin", "UpdateMove", 
		function(self, input)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2MinimapMoveMixinUpdateMove(self, input)		

		end
	)
	
	local originalNS2PlayerOnProcessMove

	originalNS2PlayerOnProcessMove = Class_ReplaceMethod("Player", "OnProcessMove", 
		function(self, input)

			//if DAK:GetTournamentMode() and GetIsGamePaused() then
				//return
			//end
			originalNS2PlayerOnProcessMove(self, input)		

		end
	)
	
	local originalNS2PlayerOnUpdatePlayer

	originalNS2PlayerOnUpdatePlayer = Class_ReplaceMethod("Player", "OnUpdatePlayer", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2PlayerOnUpdatePlayer(self, deltaTime)		

		end
	)
	
	local originalNS2TeamSpectatorOnProcessMove

	originalNS2TeamSpectatorOnProcessMove = Class_ReplaceMethod("TeamSpectator", "OnProcessMove", 
		function(self, input)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2TeamSpectatorOnProcessMove(self, input)		

		end
	)
	
	local originalNS2EmbryoUpdateGestation

	originalNS2EmbryoUpdateGestation = Class_ReplaceMethod("Embryo", "UpdateGestation", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return true
			end
			return originalNS2EmbryoUpdateGestation(self, deltaTime)
			
		end
	)
	
	local originalNS2TunnelUserMixinOnProcessMove

	originalNS2TunnelUserMixinOnProcessMove = Class_ReplaceMethod("TunnelUserMixin", "OnProcessMove", 
		function(self, input)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2TunnelUserMixinOnProcessMove(self, input)
			
		end
	)
	
	local originalNS2TunnelUserMixinOnUpdate

	originalNS2TunnelUserMixinOnUpdate = Class_ReplaceMethod("TunnelUserMixin", "OnUpdate", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2TunnelUserMixinOnUpdate(self, deltaTime)
			
		end
	)
	
	local originalNS2BabblerOnProcessMove

	originalNS2BabblerOnProcessMove = Class_ReplaceMethod("Babbler", "OnProcessMove", 
		function(self, input)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2BabblerOnProcessMove(self, input)
			
		end
	)
	
	local originalNS2BabblerOnUpdate

	originalNS2BabblerOnUpdate = Class_ReplaceMethod("Babbler", "OnUpdate", 
		function(self, deltaTime)

			if DAK:GetTournamentMode() and GetIsGamePaused() then
				return
			end
			originalNS2BabblerOnUpdate(self, deltaTime)
			
		end
	)
	
	local originalNS2BabblerOnInitialized

	originalNS2BabblerOnInitialized = Class_ReplaceMethod("Babbler", "OnInitialized", 
		function(self)

			self.adjustedcreationtime = Shared.GetTime()
			originalNS2BabblerOnInitialized(self)
			
		end
	)
	
	local kBabblerLifeTime = 120

	local originalNS2BabblerTimeUp

	originalNS2BabblerTimeUp = Class_ReplaceMethod("Babbler", "TimeUp", 
		function(self)

			if self.adjustedcreationtime + kBabblerLifeTime <= Shared.GetTime() then
				originalNS2BabblerTimeUp(self)
			else
				self:AddTimedCallback(Babbler.TimeUp, math.max(self.adjustedcreationtime + kBabblerLifeTime - Shared.GetTime() + 0.5, 0.5))
			end
			
		end
	)
	
end

if DAK.config and DAK.config.loader and DAK.config.loader.GamerulesExtensions then
	DAK:RegisterEventHook("OnPluginInitialized", OnPluginInitialized, 5)
end

local function PausedJoinTeam(self, player, newTeamNumber, force)
	if DAK:GetTournamentMode() and GetIsGamePaused() and (newTeamNumber ~= 1 and newTeamNumber ~= 2) then
		// send message telling people that they cant do that.
		return true
	end
end

local function PauseEndGame(self, winningTeam)
	gamestate.team1pauses = 0
	gamestate.team2pauses = 0
	gamestate.team1resume = false
	gamestate.team2resume = false
end

DAK:RegisterEventHook("OnGameEnd", PauseEndGame, 5)

function GetIsGamePaused()
	return gamestate.gamepaused
end

//This runs every tick to procedurally update any timerelevant fields of any relevant ents to insure they remain in the appropriate state.
local function UpdateEntStates(deltatime)
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			if not player.countingDown then
				player.countingDown = true
				player.followMoveEnabled = false
				player:PrimaryAttackEnd()
				player.cachedorigin = player:GetOrigin()
				player.cachedvelocity = player:GetVelocity()
				if(player.secondaryAttackLastFrame ~= nil and player.secondaryAttackLastFrame) then
					player:SecondaryAttackEnd()
				end
			end
			if player.cachedorigin ~= nil then
				player:SetOrigin(player.cachedorigin)
			end
			if player.cachedvelocity ~= nil then
				player:SetVelocity(player.cachedvelocity)
			end
			if player:isa("Alien") then
				player.timeAbilityEnergyChanged = Shared.GetTime()
			elseif player:isa("JetpackMarine") then
				player.timeJetpackingChanged = Shared.GetTime()
			end
			if player.timeLastTunnelCorrodeCheck ~= nil then
				player.timeLastTunnelCorrodeCheck = player.timeLastTunnelCorrodeCheck + deltatime
			end
		end
	end
	//Update MiniGun heat levels
	local Miniguns = Shared.GetEntitiesWithClassname("Minigun")
	for _, Minigun in ientitylist(Miniguns) do
		if Minigun.cachedheatAmount ~= nil then
			Minigun.heatAmount = Minigun.cachedheatAmount
		end
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
	//Babblers
	local Babblers = Shared.GetEntitiesWithClassname("Babbler")
	for _, Babbler in ientitylist(Babblers) do
		Babbler.adjustedcreationtime = Babbler.adjustedcreationtime + deltatime
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
	//Cloaking
	local cloakers = GetEntitiesWithMixin("Cloakable")
	for _, cloak in ipairs(cloakers) do
		if cloak.cachedcloakedFraction then
			cloak.cloakedFraction = cloak.cachedcloakedFraction
		end
	end
	//Update anything thats teleporting to block - Echo
	local teleportEnts = GetEntitiesWithMixin("TeleportAble")
	for _, teleportEnt in ipairs(teleportEnts) do
		if teleportEnt.isTeleporting then 
			teleportEnt.timeUntilPort = teleportEnt.timeUntilPort + deltatime
		end
	end
	//Update Vortex - This could be reallllllllllllllly annoying with the sound and effects if they loop :X:X
	local vortexEnts = GetEntitiesWithMixin("VortexAble")
	for _, vortexEnt in ipairs(vortexEnts) do
		if vortexEnt:GetIsVortexed() then 
			vortexEnt.remainingVortexDuration = vortexEnt.remainingVortexDuration + deltatime
		end
	end
	//Update Flamedamage init time
	local flameableEnts = GetEntitiesWithMixin("Fire")
	for _, flameableEnt in ipairs(flameableEnts) do
		if flameableEnt.timeBurnInit ~= 0 then 
			flameableEnt.timeBurnInit = flameableEnt.timeBurnInit + deltatime
		end
	end
	//Stunned - Stomp
	local stunnedEnts = GetEntitiesWithMixin("Stun")
	for _, stunnedEnt in ipairs(stunnedEnts) do
		if stunnedEnt:GetIsStunned() then 
			stunnedEnt.stunTime = stunnedEnt.stunTime + deltatime
		end
	end
	//Beep beep boom
	local Mines = Shared.GetEntitiesWithClassname("Mine")
	for _, Mine in ientitylist(Mines) do
		Mine.active = false
	end
	//Hydras
	local Hydras = Shared.GetEntitiesWithClassname("Hydra")
	for _, hydra in ientitylist(Hydras) do
		if hydra.timeOfNextFire ~= nil then 
			hydra.timeOfNextFire = hydra.timeOfNextFire + deltatime
		end
	end
	//Update DOTS (only BB???) lifetime  - MOAR DOTS
	local Dots = Shared.GetEntitiesWithClassname("DotMarker")
	for _, dot in ientitylist(Dots) do
		dot.adjustedcreationtime = dot.adjustedcreationtime + deltatime
	end
	//Infestation
	local InfestationEnts = Shared.GetEntitiesWithClassname("Infestation")
	for _, inf in ientitylist(InfestationEnts) do
		inf.timeCycleStarted = inf.timeCycleStarted + deltatime
	end
	//Update Lerk Poison Bite, why isnt this a dot?...
	local PoisonedMarines = Shared.GetEntitiesWithClassname("Marine")
	for _, PM in ientitylist(PoisonedMarines) do
		if PM.poisoned then
			if PM:GetIsAlive() and PM.timeLastPoisonDamage then
				PM.timeLastPoisonDamage = PM.timeLastPoisonDamage + deltatime
				PM.timePoisoned = PM.timePoisoned + deltatime
			end
		end
	end
	//Updated phase delay to prevent annoying hopping.
	local PGs = Shared.GetEntitiesWithClassname("PhaseGate")
	for _, PG in ientitylist(PGs) do
		if PG.timeOfLastPhase == nil then PG.timeOfLastPhase = (Shared.GetTime() - 0.5) end
		PG.timeOfLastPhase = PG.timeOfLastPhase + deltatime
	end
	//Stop the bacon from spammmming.
	local Obs = Shared.GetEntitiesWithClassname("Observatory")
	for _, Ob in ientitylist(Obs) do
		if Ob.distressBeaconTime ~= nil then
			Ob.distressBeaconTime = Ob.distressBeaconTime + deltatime
			Ob.distressBeaconSoundMarine:Stop()
			Ob.distressBeaconSoundAlien:Stop()
			//Dont wanna listen to that noise over and over and over and over and over ..
		end
	end
	//Update dropped guns.
	local Weapons = Shared.GetEntitiesWithClassname("Weapon")
	for _, Weap in ientitylist(Weapons) do
		if Weap.weaponWorldStateTime ~= nil then
			Weap.weaponWorldStateTime = Weap.weaponWorldStateTime + deltatime
		end
	end
end

//This runs when game resumes, should restore any ents whos states were saved initially.
local function ResumeEntStates()
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			player.countingDown = false
			player.followMoveEnabled = true
			if player.cachedorigin ~= nil then
				player:SetOrigin(player.cachedorigin)
			end
			if player.cachedvelocity ~= nil then
				player:SetVelocity(player.cachedvelocity)
			end
			if player:isa("JetpackMarine") then
				player.timeJetpackingChanged = Shared.GetTime()
			elseif player:isa("Alien") then
				player.timeAbilityEnergyChanged = Shared.GetTime()
			end
		end
	end
	//Resume the annoying noise
	local Obs = Shared.GetEntitiesWithClassname("Observatory")
	for _, Ob in ientitylist(Obs) do
		if Ob.distressBeaconTime ~= nil then
			Ob.distressBeaconSoundMarine:Start()
			Ob.distressBeaconSoundAlien:Start()
			
			local origin = Ob:GetDistressOrigin()
			Ob.distressBeaconSoundMarine:SetOrigin(origin)
			Ob.distressBeaconSoundAlien:SetOrigin(origin)
		end
	end
	//Update MiniGun heat levels
	local Miniguns = Shared.GetEntitiesWithClassname("Minigun")
	for _, Minigun in ientitylist(Miniguns) do
		if Minigun.cachedheatAmount ~= nil then
			Minigun.heatAmount = Minigun.cachedheatAmount
			Minigun.heatUISound:Start()
			Minigun.cachedheatAmount = nil
		end
	end
	//Cloaking
	local cloakers = GetEntitiesWithMixin("Cloakable")
	for _, cloak in ipairs(cloakers) do
		if cloak.cachedcloakedFraction then
			cloak.cloakedFraction = cloak.cachedcloakedFraction
		end
	end
	//Beep beep boom
	local Mines = Shared.GetEntitiesWithClassname("Mine")
	for _, Mine in ientitylist(Mines) do
		if Mine.wasactive then
			Mine.active = true
		else
			local activateFunc = function(self)
                                 self.active = true
                             end
			Mine:AddTimedCallback(activateFunc, kMineActiveTime)
		end
	end
	//Update Next Thinks
	local CommanderAbilities = Shared.GetEntitiesWithClassname("CommanderAbility")
	for _, CommanderAbility in ientitylist(CommanderAbilities) do
		CommanderAbility:SetNextThink(math.max(CommanderAbility:GetThinkTime() - (Shared.GetTime() - CommanderAbility.timeCreated), 0.1))
	end
end

// This runs when the pause enables, saves the times/states of any ents that cannot be procedurally correctly.
local function SaveEntStates()
	//What needs to be blocked - played movement, commander abilities.  Researches paused, res income blocked.  Cant join spec.
	//Commander probably being the only difficult part - may get pretty wierd as there is no known client side effects that block your inputs fully.
	//Going to try just blocking techtree actions
	//Need to block respawns and eggs
	//Also block alien regen and crag heal
	//Cache real creation time
	local CommanderAbilities = Shared.GetEntitiesWithClassname("CommanderAbility")
	for _, CommanderAbility in ientitylist(CommanderAbilities) do
		CommanderAbility.timePausedCreated = CommanderAbility.timeCreated
	end
	//Cache MiniGun heat levels
	//Stopppp the retarded sound
	local Miniguns = Shared.GetEntitiesWithClassname("Minigun")
	for _, Minigun in ientitylist(Miniguns) do
		Minigun.cachedheatAmount = Minigun.heatAmount
		Minigun.heatUISound:Stop()
	end
	//Stopppp the duck turrets
	local Sentries = Shared.GetEntitiesWithClassname("Sentry")
	for _, Sentry in ientitylist(Sentries) do
		Sentry.attacking = false
	end
	//Beep beep boom
	local Mines = Shared.GetEntitiesWithClassname("Mine")
	for _, Mine in ientitylist(Mines) do
		Mine.wasactive = Mine.active
		Mine.active = false
	end
	//Cloaking
	local cloakers = GetEntitiesWithMixin("Cloakable")
	for _, cloak in ipairs(cloakers) do
		cloak.cachedcloakedFraction = cloak.cloakedFraction
	end
	//Block movement instantly so that its not updated each frame needlessly
	local playerRecords = Shared.GetEntitiesWithClassname("Player")
	for _, player in ientitylist(playerRecords) do
		if player ~= nil then
			player:PrimaryAttackEnd()
			player.countingDown = true
			player.followMoveEnabled = false
			player.cachedorigin = player:GetOrigin()
			player.cachedvelocity = player:GetVelocity()
			if(player.secondaryAttackLastFrame ~= nil and player.secondaryAttackLastFrame) then
				player:SecondaryAttackEnd()
			end
			if player:isa("JetpackMarine") then
				player.timeJetpackingChanged = Shared.GetTime()
			elseif player:isa("Alien") then
				player.timeAbilityEnergyChanged = Shared.GetTime()
			end
		end
	end
end

local function UpdateMoveState(deltatime)

	if GetIsGamePaused() then
		//Going to check and reblock player movement every second or so - trying every frame, might as well.
		if gamestate.gamepausedmessagetime + DAK.config.pause.kPausedReadyNotificationDelay < Shared.GetTime() and gamestate.gamepausedcountdown == 0 then
			if gamestate.team2resume and not gamestate.team1resume then
				DAK:DisplayMessageToAllClients("PauseTeamReadyPeriodicMessage", DAK.config.loader.TeamTwoName, DAK.config.loader.TeamOneName)
			elseif gamestate.team1resume and not gamestate.team2resume then
				DAK:DisplayMessageToAllClients("PauseTeamReadyPeriodicMessage", DAK.config.loader.TeamOneName, DAK.config.loader.TeamTwoName)
			elseif not gamestate.team1resume and not gamestate.team2resume then
				DAK:DisplayMessageToAllClients("PauseNoTeamReadyMessage")
			end
			if DAK.config.pause.kPausedMaxDuration ~= 0 then
				DAK:DisplayMessageToAllClients("PauseResumeWarningMessage", ((gamestate.gamepausedtime + DAK.config.pause.kPausedMaxDuration) - Shared.GetTime()))
			end
			gamestate.gamepausedmessagetime = Shared.GetTime()
		end
		UpdateEntStates(deltatime)
		if DAK.config.pause.kPausedMaxDuration ~= 0 and (Shared.GetTime() - gamestate.gamepausedtime) >= DAK.config.pause.kPausedMaxDuration and gamestate.gamepausedcountdown == 0 then
			RegisterUpdateServerPauseState()
			gamestate.gamepausedcountdown = Shared.GetTime() + DAK.config.pause.kPauseChangeDelay
		end
	else
		ResumeEntStates()
		DAK:DeregisterEventHook("OnServerUpdateEveryFrame", UpdateMoveState)
		DAK:DeregisterEventHook("OnTeamJoin", PausedJoinTeam)
		if gamestate.gamepausingteam ~= 0 then
			DAK:DisplayMessageToAllClients("PauseResumeMessage", ConditionalValue(gamestate.gamepausingteam == 1,DAK.config.loader.TeamOneName ,DAK.config.loader.TeamTwoName), (DAK.config.pause.kPauseMaxPauses - (ConditionalValue(gamestate.gamepausingteam == 1, gamestate.team1pauses, gamestate.team2pauses))))
		end
		gamestate.gamepausedtime = 0
		gamestate.gamepausingteam = 0
	end
	
end

local function UpdateServerPauseState()

	local tt = Shared.GetTime()
	if gamestate.gamepausedcountdown - tt > 0 then
		DAK:DisplayMessageToAllClients("PauseWarningMessage", ConditionalValue(GetIsGamePaused(), "resume", "pause"), (gamestate.gamepausedcountdown - tt))
	else
		if not GetIsGamePaused() then
			SaveEntStates()
			DAK:RegisterEventHook("OnServerUpdateEveryFrame", UpdateMoveState, 5)
			DAK:RegisterEventHook("OnTeamJoin", PausedJoinTeam, 5)
			DAK:DisplayMessageToAllClients("PausePausedMessage")
			gamestate.gamepausedtime = Shared.GetTime()
		else
			//Since other event already running, just let the final trigger run there (will be next frame).
		end
		DAK:DeregisterEventHook("OnServerUpdate", UpdateServerPauseState)
		gamestate.gamepaused = not GetIsGamePaused()
		gamestate.gamepausedcountdown = 0
	end
	
end

function RegisterUpdateServerPauseState()
	DAK:RegisterEventHook("OnServerUpdate", UpdateServerPauseState, 5)
end

local function ValidateTeamNumber(teamnum)
	return teamnum == 1 or teamnum == 2
end

local function OnCommandPause(client)
	
	if DAK:GetTournamentMode() and client ~= nil and GetGamerules():GetGameStarted() then
		local player = client:GetControllingPlayer()
		if player ~= nil and not GetIsGamePaused() then
			local teamnumber = player:GetTeamNumber()
			if teamnumber and ValidateTeamNumber(teamnumber) then
				local validpause = false
				if teamnumber == 1 then
					if gamestate.team1pauses < DAK.config.pause.kPauseMaxPauses then
						gamestate.team1pauses = gamestate.team1pauses + 1
						validpause = true
					end
				else
					if gamestate.team2pauses < DAK.config.pause.kPauseMaxPauses then
						gamestate.team2pauses = gamestate.team2pauses + 1
						validpause = true
					end
				end
				if validpause then
					gamestate.team1resume = false
					gamestate.team2resume = false
					gamestate.gamepausedcountdown = Shared.GetTime() + DAK.config.pause.kPauseChangeDelay
					gamestate.gamepausingteam = teamnumber
					DAK:RegisterEventHook("OnServerUpdate", UpdateServerPauseState, 5)
					DAK:DisplayMessageToAllClients("PausePlayerMessage", player:GetName())
				else
					DAK:DisplayMessageToClient(client, "PauseTooManyPausesMessage")
				end
			end
		end
	end
	
end

Event.Hook("Console_pause",               OnCommandPause)
DAK:RegisterChatCommand(DAK.config.pause.kPauseChatCommands, OnCommandPause, false)

local function OnCommandUnPause(client)
	
	if DAK:GetTournamentMode() and client ~= nil then
		local player = client:GetControllingPlayer()
		if player ~= nil  and GetIsGamePaused() then
			local teamnumber = player:GetTeamNumber()
			if teamnumber and ValidateTeamNumber(teamnumber) then
				if teamnumber == 1 then
					gamestate.team1resume = not gamestate.team1resume
				else
					gamestate.team2resume = not gamestate.team2resume
				end
				if gamestate.team2resume and not gamestate.team1resume then
					DAK:DisplayMessageToAllClients("PauseTeamReadyMessage", player:GetName(), DAK.config.loader.TeamTwoName, DAK.config.loader.TeamOneName)
				elseif gamestate.team1resume and not gamestate.team2resume then
					DAK:DisplayMessageToAllClients("PauseTeamReadyMessage", player:GetName(), DAK.config.loader.TeamOneName, DAK.config.loader.TeamTwoName)
				elseif not gamestate.team1resume and not gamestate.team2resume then
					DAK:DisplayMessageToAllClients("PauseNoTeamReadyMessage")
				else
					DAK:DisplayMessageToAllClients("PauseTeamReadiedMessage", player:GetName(), ConditionalValue(teamnumber == 1,DAK.config.loader.TeamOneName ,DAK.config.loader.TeamTwoName))
					DAK:RegisterEventHook("OnServerUpdate", UpdateServerPauseState, 5)
					gamestate.gamepausedcountdown = Shared.GetTime() + DAK.config.pause.kPauseChangeDelay
				end
			end
		end
	end
	
end

Event.Hook("Console_unpause",               OnCommandUnPause)
DAK:RegisterChatCommand(DAK.config.pause.kUnPauseChatCommands, OnCommandUnPause, false)

local function OnCommandAdminPause(client)
	
	if DAK:GetTournamentMode() and GetGamerules():GetGameStarted() then
		if gamestate.gamepausedcountdown == 0 then
			DAK:RegisterEventHook("OnServerUpdate", UpdateServerPauseState, 5)
			gamestate.team1resume = false
			gamestate.team2resume = false
			gamestate.gamepausedcountdown = Shared.GetTime() + DAK.config.pause.kPauseChangeDelay
		else
			DAK:DeregisterEventHook("OnServerUpdate", UpdateServerPauseState)
			DAK:DisplayMessageToAllClients("PauseCancelledMessage")
			gamestate.gamepausedcountdown = 0
		end
		
		DAK:PrintToAllAdmins("sv_pause", client)
		
		if client ~= nil then
			ServerAdminPrint(client, "Game " .. ConditionalValue(not GetIsGamePaused(), "pausing.", "unpausing."))
		end
	end
	
end

DAK:CreateServerAdminCommand("Console_sv_pause", OnCommandAdminPause, "Will pause or resume current game.")