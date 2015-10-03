local ArclightModsEnabled = true
local ArclightMapName = "ns2_tgns_arclight"

if ArclightModsEnabled then
	Event.Hook("MapPostLoad", function()
		if Shared.GetMapName() == ArclightMapName then
			TGNS.ModifyAlienMaxSpeeds(function(maxSpeed) return maxSpeed + (kCelerityAddSpeed or 1.5) end)
			kStompEnergyCost = kStompEnergyCost * 2
		end
	end)
end
if Server or Client then
	local Plugin = {}

	Plugin.HILL_SOUND = "arclight_HILL_SOUND"

	TGNS.RegisterNetworkMessage(Plugin.HILL_SOUND, {i="integer", r="boolean"})

	if Client then
		local hill1SoundEventName = "sound/tgns.fev/hill/1"
		local hill2SoundEventName = "sound/tgns.fev/hill/2"
		local hill3SoundEventName = "sound/tgns.fev/hill/3"
		local hill4SoundEventName = "sound/tgns.fev/hill/4"
		local hill5SoundEventName = "sound/tgns.fev/hill/5"
		local hill6SoundEventName = "sound/tgns.fev/hill/6"
		local hill7SoundEventName = "sound/tgns.fev/hill/7"
		local hill8SoundEventName = "sound/tgns.fev/hill/8"
		local hill9SoundEventName = "sound/tgns.fev/hill/9"
		local hill10SoundEventName = "sound/tgns.fev/hill/10"
		local hillPitOpenMarinesSoundEventName = "sound/tgns.fev/hill/ns1_marine_lets_move_out"
		local hillPitOpenAliensSoundEventName = "sound/tgns.fev/hill/ns1_alien_now_we_donce"

		Client.PrecacheLocalSound(hill1SoundEventName)
		Client.PrecacheLocalSound(hill2SoundEventName)
		Client.PrecacheLocalSound(hill3SoundEventName)
		Client.PrecacheLocalSound(hill4SoundEventName)
		Client.PrecacheLocalSound(hill5SoundEventName)
		Client.PrecacheLocalSound(hill6SoundEventName)
		Client.PrecacheLocalSound(hill7SoundEventName)
		Client.PrecacheLocalSound(hill8SoundEventName)
		Client.PrecacheLocalSound(hill9SoundEventName)
		Client.PrecacheLocalSound(hill10SoundEventName)
		Client.PrecacheLocalSound(hillPitOpenMarinesSoundEventName)
		Client.PrecacheLocalSound(hillPitOpenAliensSoundEventName)

		TGNS.HookNetworkMessage(Plugin.HILL_SOUND, function(message)
			local soundEventName
			if message.i == 1 then
				soundEventName = hill1SoundEventName
			elseif message.i == 2 then
				soundEventName = hill2SoundEventName
			elseif message.i == 3 then
				soundEventName = hill3SoundEventName
			elseif message.i == 4 then
				soundEventName = hill4SoundEventName
			elseif message.i == 5 then
				soundEventName = hill5SoundEventName
			elseif message.i == 6 then
				soundEventName = hill6SoundEventName
			elseif message.i == 7 then
				soundEventName = hill7SoundEventName
			elseif message.i == 8 then
				soundEventName = hill8SoundEventName
			elseif message.i == 9 then
				soundEventName = hill9SoundEventName
			elseif message.i == 10 then
				soundEventName = hill10SoundEventName
			elseif message.i == 11 then
				soundEventName = hillPitOpenMarinesSoundEventName
			elseif message.i == 12 then
				soundEventName = hillPitOpenAliensSoundEventName
			end

			if soundEventName then
				Shared.PlaySound(Client.GetLocalPlayer(), soundEventName, 0.025)
				if message.r then
					Shine.Timer.Simple(0.25, function() Shared.PlaySound(Client.GetLocalPlayer(), soundEventName, 0.025) end)
				end
			end
		end)
	end

	if Server then
		function Plugin:IsArclight()
			local result = TGNS.GetCurrentMapName() == ArclightMapName
			return result
		end

		function Plugin:GetHillLocationName()
			return "The Pit"
		end
	end

	local function removeCommandStationRecycleButton()
		CommandStation.GetCanRecycleOverride = function(commandStationSelf) return false end
	end

	local function OnClientInitialise()
		removeCommandStationRecycleButton()
	end

	local function OnServerInitialise()
		Shine.Plugins.mapvote.Config.AlwaysExtend = true
		Shine.Plugins.mapvote.Config.AllowExtend = true
		Shine.Plugins.mapvote.CanExtend = function(mapVoteSelf) return true end
		Shine.Plugins.mapvote.Config.ForcedMaps[ArclightMapName] = true
		Shine.Plugins.mapvote.ForcedMapCount = 1

		local md = TGNSMessageDisplayer.Create()
		local hillPoints = 0
		local HILL_POSSESSION_POINT_DELTA = 3
		local pointsRemaining = {}
		local pointsMax = {}
		local maxPointsPenaltyAmount = {}
		local marinesOnHillCount
		local aliensOnHillCount
		local PRE_GAME_DURATION_IN_SECONDS = 60
		local REPLENISH_MULTIPLIER = 0.25
		local playersAreAllowedOutOfBase = true
		local teleportOutOfBaseAllowedAt = {}
		local MARINE_STARTING_POINTS = 1000
		local ALIEN_STARTING_POINTS = 1000
		local lastTubeOrigin = {}
		local teamNumberWhichCalledWinOrLose
		local voidTheJumpSlowdownUntil = {}

		local function prepareForNextGame(countdownStarting)
			pointsRemaining[kMarineTeamType] = MARINE_STARTING_POINTS
			pointsRemaining[kAlienTeamType] = ALIEN_STARTING_POINTS
			maxPointsPenaltyAmount[kMarineTeamType] = 0
			maxPointsPenaltyAmount[kAlienTeamType] = 0

			marinesOnHillCount = 0
			aliensOnHillCount = 0
			teamNumberWhichCalledWinOrLose = nil
			if countdownStarting then
				playersAreAllowedOutOfBase = false
			end
		end

		local function doForAllOutOfBaseTeleporters(action)
			local outOfBaseTeleporters = {}
			TGNS.DoFor({"MT1","MT2","MT3","MT4","AT1","AT2","AT3","AT4"}, function(outOfBaseTeleporterName)
				TGNS.DoFor(TGNS.GetEntitiesByName("TeleportTrigger", outOfBaseTeleporterName), function(teleporter) table.insert(outOfBaseTeleporters, teleporter) end)
			end)
			TGNS.DoFor(outOfBaseTeleporters, action)
		end

		prepareForNextGame()
	    pointsMax[kMarineTeamType] = MARINE_STARTING_POINTS
	    pointsMax[kAlienTeamType] = ALIEN_STARTING_POINTS

		removeCommandStationRecycleButton()

	    if not TGNS.IsProduction() then
			PRE_GAME_DURATION_IN_SECONDS = 3
		end

		local hillLocationName = Shine.Plugins.arclight:GetHillLocationName()

		local debug = function(message)
			if not TGNS.IsProduction() then
				Shared.Message(string.format("---------------------------------------------------- arclight: %s", message))
			end
		end

		local hillLocation = TGNS.GetFirst(GetLocationEntitiesNamed(hillLocationName))
		local controllingOrigin = hillLocation:GetOrigin()
		table.insert(kSkulkBrainActions, function(bot, brain)
	        local skulk = bot:GetPlayer()
			local numberOfMarinesAliveAndNotInMarineStart = #TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.PlayerIsMarine(p) and TGNS.IsPlayerAlive(p) and TGNS.GetPlayerLocationName(p) ~= "Marine Start" end)
			local weight = numberOfMarinesAliveAndNotInMarineStart > 0 and math.random() * 25 or 0
			if skulk:GetHealthScalar() < 1 then
				weight = 0 -- weight / 3
			end
	        return { name = "arclight", weight = weight,
	            perform = function(move)
					local eyePos = skulk:GetEyePos()
					local distance = eyePos:GetDistance(controllingOrigin)
					if distance > 5 and distance < 7 then
						move.commands = AddMoveCommand( move.commands, Move.Jump )
					else
		                bot:GetMotion():SetDesiredMoveTarget(Pathing.GetClosestPoint(controllingOrigin))
		                bot:GetMotion():SetDesiredViewTarget(nil)
					end
	            end }		        
	    end)


		local getTeleportOutOfBaseAllowedAt = function(client)
			local player = TGNS.GetPlayer(client)
			local pointValue = TGNS.GetPlayerPointValue(player)
			local damageScalar = 1 - player:GetHealthScalar()
			local delayInSeconds = pointValue * damageScalar
			-- debug(string.format("teleportOutOfBaseAllowedAt delayInSeconds: %s (%s x %s)", delayInSeconds, pointValue, damageScalar))
			local result = Shared.GetTime() + delayInSeconds
			return result
		end

		kTechData = nil
		ClearCachedTechData()
		local marineUpgradeResearchTimeMultiplier = TGNS.IsProduction() and 0.5 or 0.05
		kAdvancedArmoryResearchTime = kAdvancedArmoryResearchTime * marineUpgradeResearchTimeMultiplier
		kGrenadeTechResearchTime = kGrenadeTechResearchTime * marineUpgradeResearchTimeMultiplier
		kShotgunTechResearchTime = kShotgunTechResearchTime * marineUpgradeResearchTimeMultiplier
		kNanoSnieldResearchTime = kNanoSnieldResearchTime * marineUpgradeResearchTimeMultiplier
		kMineResearchTime = kMineResearchTime * marineUpgradeResearchTimeMultiplier
		kJetpackTechResearchTime = kJetpackTechResearchTime * marineUpgradeResearchTimeMultiplier
		kExosuitTechResearchTime = kExosuitTechResearchTime * marineUpgradeResearchTimeMultiplier
		kDualRailgunTechResearchTime = kDualRailgunTechResearchTime * marineUpgradeResearchTimeMultiplier
		kCatPackTechResearchTime = kCatPackTechResearchTime * marineUpgradeResearchTimeMultiplier
		kWeapons1ResearchTime = kWeapons1ResearchTime * marineUpgradeResearchTimeMultiplier
		kWeapons2ResearchTime = kWeapons2ResearchTime * marineUpgradeResearchTimeMultiplier
		kWeapons3ResearchTime = kWeapons3ResearchTime * marineUpgradeResearchTimeMultiplier
		kArmor1ResearchTime = kArmor1ResearchTime * marineUpgradeResearchTimeMultiplier
		kArmor2ResearchTime = kArmor2ResearchTime * marineUpgradeResearchTimeMultiplier
		kArmor3ResearchTime = kArmor3ResearchTime * marineUpgradeResearchTimeMultiplier

		local configureReturnTeleporter = function()
			local returnTele = TGNS.GetFirst(TGNS.GetEntitiesByName("TeleportTrigger", "returntele"))
			local marineReturnTele = TGNS.GetFirst(TGNS.GetEntitiesByName("TeleportTrigger", "marinereturntele"))
			local alienReturnTele = TGNS.GetFirst(TGNS.GetEntitiesByName("TeleportTrigger", "alienreturntele"))
			-- debug(string.format("returnTele: %s", returnTele))
			-- debug(string.format("marineReturnTele: %s", marineReturnTele))
			-- debug(string.format("alienReturnTele: %s", alienReturnTele))
			if returnTele and marineReturnTele and alienReturnTele then
	   			local originalReturnTeleOnTriggerEntered = returnTele.OnTriggerEntered
	   			returnTele.OnTriggerEntered = function(teleporterSelf, enterEnt, triggerEnt)
	   				local teamReturnTele = TGNS.PlayerIsMarine(enterEnt) and marineReturnTele or alienReturnTele
	   				local client = TGNS.GetClient(enterEnt)
	   				teleportOutOfBaseAllowedAt[client] = getTeleportOutOfBaseAllowedAt(client)
	   				teamReturnTele:OnTriggerEntered(enterEnt, triggerEnt)

	   				TGNS.ScheduleAction(teleportOutOfBaseAllowedAt[client] - Shared.GetTime(), function()
	   					if Shine:IsValidClient(client) then
	   						local player = TGNS.GetPlayer(client)
							doForAllOutOfBaseTeleporters(function(teleporter)
								local players = GetEntitiesWithinRange("Player", teleporter:GetOrigin(), 1)
								if TGNS.Has(players, player) then
									teleporter:OnTriggerEntered(player, teleporter)
								end
							end)
	   					end
	   				end)
	   			end
			end
		end

		-- local brieflySetWallwalkingValue = function(client, duration)
	-- 				if TGNS.GetIsClientVirtual(client) then
		-- 		isWallWalkingPossible[client] = false
		-- 		-- debug(string.format("Disabling wallwalk for %s...", TGNS.GetClientName(client)))
		-- 		TGNS.ScheduleAction(duration, function()
		-- 			-- debug(string.format("Enabling wallwalk for %s...", TGNS.GetClientName(client)))
		-- 			isWallWalkingPossible[client] = true
		-- 		end)
	-- 				end
		-- end

		-- debug("teleporters:")
		-- TGNS.DoFor(TGNS.GetEntitiesWithClassName("TeleportTrigger"), function(teleporter)
		-- 	Shared.Message(GetEntityInfo(teleporter))
		-- end)

		local configurePitBottomTeleporter = function()
			TGNS.DoFor(TGNS.GetEntitiesByName("TeleportTrigger", "bottomfloortele"), function(teleporter)
	   			local originalOnTriggerEntered = teleporter.OnTriggerEntered
	   			teleporter.OnTriggerEntered = function(teleporterSelf, enterEnt, triggerEnt)
	   				-- local client = TGNS.GetClient(enterEnt)
			   		-- brieflySetWallwalkingValue(client, 3)
			   		-- originalOnTriggerEntered(teleporterSelf, enterEnt, triggerEnt)
			   		local destinationTeleporterName = TGNS.GetFirst(TGNS.GetRandomizedElements(TGNS.PlayerIsMarine(enterEnt) and {"MT1","MT2","MT3","MT4"} or {"AT1","AT2","AT3","AT4"}))
			   		local destinationTele = TGNS.GetFirst(TGNS.GetEntitiesByName("TeleportTrigger", destinationTeleporterName))
			   		destinationTele:OnTriggerEntered(enterEnt, triggerEnt)		
	   			end
			end)
		end

		local configureOutOfBaseTeleporters = function()
			doForAllOutOfBaseTeleporters(function(teleporter)
				-- debug(string.format("teleporter: %s", teleporter))
	   			local originalOnTriggerEntered = teleporter.OnTriggerEntered
	   			teleporter.OnTriggerEntered = function(teleporterSelf, enterEnt, triggerEnt)
	   				local client = TGNS.GetClient(enterEnt)
	   				-- debug(string.format("enterEnt: %s", TGNS.GetClientName(client)))
	   				if playersAreAllowedOutOfBase then
		   				if TGNS.ClientIsMarine(client) then
			   				voidTheJumpSlowdownUntil[client] = Shared.GetTime() + 2.0
		   				end
		   				teleportOutOfBaseAllowedAt[client] = teleportOutOfBaseAllowedAt[client] or 0
		   				-- debug(string.format("teleportOutOfBaseAllowedAt[client]: %s", teleportOutOfBaseAllowedAt[client]))
		   				local secondsUntilCanReturnToFight = math.floor(teleportOutOfBaseAllowedAt[client] - Shared.GetTime())
	   					if secondsUntilCanReturnToFight <= 0 or not TGNS.IsGameInProgress() then
			   				originalOnTriggerEntered(teleporterSelf, enterEnt, triggerEnt)
			   				-- brieflySetWallwalkingValue(client, 3)
	   					else
	   						-- md:ToPlayerNotifyInfo(enterEnt, string.format("You recently teleported back to base. Wait %s seconds before returning to %s.", secondsUntilCanReturnToFight, hillLocationName))
	   					end
	   				else
		   			 	md:ToPlayerNotifyInfo(enterEnt, string.format("You cannot yet enter %s.", hillLocationName))
	   				end
	   			end
			end)
		end

		configureReturnTeleporter()

		TGNS.RegisterEventHook("GameCountdownStarted", function(secondsSinceEpoch)
			kHatchCooldown = 1
			kAlienSpawnTime = 0.5
			kEggGenerationRate = 0
			kMarineRespawnTime = kMarineRespawnTime / 2
			prepareForNextGame(true)
			TGNS.DoFor(TGNS.GetPlayers(TGNS.GetPlayingClients(TGNS.GetPlayerList())), function(p)
				local spawnLocationName = TGNS.PlayerIsMarine(p) and "Marine Start" or "The Hive"
				p:SetLocationName(spawnLocationName)
			end)
		end)

		local isStartCommandStructure = function(e) return TGNS.EntityIsCommandStructure(e) and TGNS.GetEntityLocationName(e) ~= hillLocationName end

	    local originalWeldableMixinGetCanBeWelded
		originalWeldableMixinGetCanBeWelded = TGNS.ReplaceClassMethod("WeldableMixin", "GetCanBeWelded", function(weldableMixinSelf, doer)
			local result = originalWeldableMixinGetCanBeWelded(weldableMixinSelf, doer)
			if result and TGNS.IsGameInProgress() and isStartCommandStructure(weldableMixinSelf) then
				result = false
			end
			return result
		end)

	    local originalLiveMixinGetCanBeHealed
		originalLiveMixinGetCanBeHealed = TGNS.ReplaceClassMethod("LiveMixin", "GetCanBeHealed", function(liveMixinSelf)
			local result = originalLiveMixinGetCanBeHealed(liveMixinSelf)
			if result and TGNS.IsGameInProgress() and isStartCommandStructure(liveMixinSelf) then
				result = false
			end
			return result
		end)

	    local originalTeamInfoOnCommanderLogin
		originalTeamInfoOnCommanderLogin = TGNS.ReplaceClassMethod("TeamInfo", "OnCommanderLogin", function(teamInfoSelf, commanderPlayer, forced)
			originalCommanderPlayerSetResources = commanderPlayer.SetResources
			commanderPlayer.SetResources = function() end
			originalTeamInfoOnCommanderLogin(teamInfoSelf, commanderPlayer, forced)
			commanderPlayer.SetResources = originalCommanderPlayerSetResources
		end)

		local originalHiveGenerateEggSpawns
		originalHiveGenerateEggSpawns = TGNS.ReplaceClassMethod("Hive", "GenerateEggSpawns", function(hiveSelf, hiveLocationName)
			if hiveLocationName ~= hillLocationName then
				originalHiveGenerateEggSpawns(hiveSelf, hiveLocationName)
			-- else
			-- 	debug("skipping GenerateEggSpawns for Pit hive...")
			end
		end)

		-- local originalSkulkGetIsWallWalkingPossible
		-- originalSkulkGetIsWallWalkingPossible = TGNS.ReplaceClassMethod("Skulk", "GetIsWallWalkingPossible", function(skulkSelf)
		-- 	local result = originalSkulkGetIsWallWalkingPossible(skulkSelf)
		-- 	local client = TGNS.GetClient(skulkSelf)
		-- 	if TGNS.GetIsClientVirtual(client) then
		-- 		result = isWallWalkingPossible[client] == nil or isWallWalkingPossible[client] == true
		-- 	end
		-- 	return result
		-- end)

	    local originalMarineTeamSpawnInitialStructures = MarineTeam.SpawnInitialStructures
	    MarineTeam.SpawnInitialStructures = function(selfx, techPoint)
	    	local originalGetNumPlayers = selfx.GetNumPlayers
		    	selfx.GetNumPlayers = function(selfy)
		    		return originalGetNumPlayers(selfy) + 9
		    	end
	    	local tower, commandStation = originalMarineTeamSpawnInitialStructures(selfx, techPoint)
	    	selfx.GetNumPlayers = originalGetNumPlayers
	    	return tower, commandStation
		end

		local originalResourceTowerCollectResources
		originalResourceTowerCollectResources = TGNS.ReplaceClassMethod("ResourceTower", "CollectResources", function(resourceTowerSelf)
			originalResourceTowerCollectResources(resourceTowerSelf)
			local commanderClient = TGNS.GetTeamCommanderClient(resourceTowerSelf:GetTeamNumber())
			if commanderClient then
				TGNS.AddClientResources(commanderClient, kPlayerResPerInterval)
			end
		end)

		local originalMarineModifyJumpLandSlowDown
		originalMarineModifyJumpLandSlowDown = TGNS.ReplaceClassMethod("Marine", "ModifyJumpLandSlowDown", function(marineSelf, slowdownScalar)
			local result = originalMarineModifyJumpLandSlowDown(marineSelf, slowdownScalar)
			local client = TGNS.GetClient(marineSelf)
			if Shared.GetTime() < (voidTheJumpSlowdownUntil[client] or 0) then
				result = 0
			end
			return result
		end)

		-- local originalTechPointGetAttached
		-- originalTechPointGetAttached = TGNS.ReplaceClassMethod("TechPoint", "GetAttached", function(techPointSelf)
		-- 	local result = originalTechPointGetAttached(techPointSelf)
		-- 	local gameDurationInSeconds = TGNS.GetCurrentGameDurationInSeconds()
		-- 	if not result and TGNS.GetEntityLocationName(techPointSelf) == hillLocationName and (gameDurationInSeconds ~= nil and gameDurationInSeconds < PRE_GAME_DURATION_IN_SECONDS) then
		-- 		result = true
		-- 	end
		-- 	return result
		-- end)

		ServerSponitor.OnEndMatch = function(serverSponitorSelf, winningTeam) end
		PlayerRanking.GetTrackServer = function(playerRankingSelf) return false end

		ARC.Deploy = function(arcSelf, commander)
			if commander then
				md:ToPlayerNotifyError(commander, "You may not deploy ARCs on this map.")
			end
		end

		local originalResetGame
		originalResetGame = TGNS.ReplaceClassMethod("NS2Gamerules", "ResetGame", function(gamerules)
			originalResetGame(gamerules)
			local originalCommandStructures = TGNS.GetCommandStructures()
			TGNS.DoFor(TGNS.Where(TGNS.GetTechPoints(), function(techPoint) return TGNS.GetEntityLocationName(techPoint) ~= hillLocationName end), function(techPoint)
				local commandStructure = TGNS.FirstOrNil(originalCommandStructures, function(s) return s:GetAttached() == techPoint end)
				if not commandStructure then
					commandStructure = techPoint:SpawnCommandStructure(TGNS.GetEntityLocationName(techPoint) == "Marine Start" and kMarineTeamType or kAlienTeamType)
					commandStructure:SetConstructionComplete()
				end
				commandStructure:SetHealth(commandStructure:GetMaxHealth())
				commandStructure:SetArmor(commandStructure:GetMaxArmor())
				if commandStructure.SetMature then
					commandStructure:SetHealth(commandStructure:GetMatureMaxHealth())
					commandStructure:SetArmor(commandStructure:GetMatureMaxArmor())
					commandStructure:SetMature()
				end
			end)
			
			configureOutOfBaseTeleporters()
			configurePitBottomTeleporter()
				configureReturnTeleporter()
		end)

		local originalEmbryoSetGestationData = Embryo.SetGestationData
		Embryo.SetGestationData = function(embryoSelf, techIds, previousTechId, healthScalar, armorScalar)
			originalEmbryoSetGestationData(embryoSelf, techIds, previousTechId, healthScalar, armorScalar)
			if embryoSelf:GetLocationName() == "The Hive" then
				embryoSelf.gestationTime = 0.75
			end
		end

		local originalHydraAttackTarget = Hydra.AttackTarget
		Hydra.AttackTarget = function(hydraSelf)
			originalHydraAttackTarget(hydraSelf)
			local numberOfBuiltAliveHydrasInRange = 0
			TGNS.DoForPairs(GetEntitiesForTeamWithinRange("Hydra", kAlienTeamType, hydraSelf:GetOrigin(), Hydra.kRange), function(index, hydra)
				if TGNS.StructureIsBuilt(hydra) and TGNS.StructureIsAlive(hydra) then
					numberOfBuiltAliveHydrasInRange = numberOfBuiltAliveHydrasInRange + 1
				end
			end)
			local timeOfNextFireDelayInSeconds = 0
			if numberOfBuiltAliveHydrasInRange > kHydrasPerHive then
				timeOfNextFireDelayInSeconds = 0.3 * numberOfBuiltAliveHydrasInRange
			end
			hydraSelf.timeOfNextFire = hydraSelf.timeOfNextFire + timeOfNextFireDelayInSeconds
		end

		local function buildHelpText(client)
			local teamNumber = TGNS.GetClientTeamNumber(client)
			local otherTeamName = TGNS.GetOtherPlayingTeamName(TGNS.GetClientTeamName(client))
			local otherTeamNamePossessive = otherTeamName and string.format("%s'", otherTeamName) or "other team's"
			local result = string.format("Gather on %s's center platform\nto drive down the %s points.\nDrive them all the way down to\nzero points to win the round!\n\nAll points drop faster when:\n - teams are full (8v8), or\n - one team has surrendered!", hillLocationName, otherTeamNamePossessive)
			return result
		end

		local function showHelpText(client)
			local message = buildHelpText(client)				
			local locationName = TGNS.GetClientLocationName(client)
			local rgb = TGNS.GetTeamRgb(TGNS.GetClientTeamNumber(client))
			local playerIsAliveOnTheGroundInBase = TGNS.Has({"Marine Start", "The Hive"}, locationName) and TGNS.IsClientAlive(client) and not TGNS.IsClientCommander(client)
			local playerIsDeadOnPlayingTeam = TGNS.ClientIsOnPlayingTeam(client) and not TGNS.IsClientAlive(client)
			if playerIsAliveOnTheGroundInBase or playerIsDeadOnPlayingTeam or not TGNS.ClientIsOnPlayingTeam(client) or not TGNS.IsGameInProgress() then
				--debug(string.format("HelpText: %s: show", TGNS.GetClientName(client)))
				Shine.ScreenText.Add(63, {X = 0.8, Y = 0.40, Text = message, Duration = 120, R = rgb.R, G = rgb.G, B = rgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, client)
			else
			-- 	debug(string.format("HelpText: %s: hide", TGNS.GetClientName(client)))
			 	Shine:RemoveText(client, { ID = 63 } )
			end
			if not Shine.Plugins.mapvote:VoteStarted() then
				if TGNS.IsClientReadyRoom(client) then
					message =           "This map is a work in progress. It takes a \"king of the hill\" format, where you control a central, contested area to win.\n"
					message = message .. string.format("On this map, that area is a central platform in %s, and you win by standing on this platform to drive down the points\n", Shine.Plugins.arclight:GetHillLocationName())
					Shine.ScreenText.Add(68, {X = 0.2, Y = 0.75, Text = message, Duration = 120, R = rgb.R, G = rgb.G, B = rgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, client)
					message = "\n\nof the other team. Meanwhile, they're doing the same thing! The first team to drive the other team to zero points wins!"
					Shine.ScreenText.Add(69, {X = 0.2, Y = 0.75, Text = message, Duration = 120, R = rgb.R, G = rgb.G, B = rgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, client)
				else
					Shine:RemoveText(client, { ID = 68 } )
					Shine:RemoveText(client, { ID = 69 } )
				end
			end
		end

		TGNS.RegisterEventHook("WinOrLoseCalled", function(teamNumber)
			teamNumberWhichCalledWinOrLose = teamNumber
		end)

		TGNS.RegisterEventHook("EndGame", function(gamerules, winningTeam)
			playersAreAllowedOutOfBase = true
		end)

		TGNS.RegisterEventHook("PlayerLocationChanged", function(player, locationName)
			local client = TGNS.GetClient(player)
			showHelpText(client)
			--debug(string.format("Location: %s - %s", TGNS.GetPlayerName(player), locationName))
		end)

		TGNS.RegisterEventHook("PostJoinTeam", function(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
			local client = TGNS.GetClient(player)
			TGNS.ScheduleAction(2, function()
				if Shine:IsValidClient(client) then
					showHelpText(client)
				end
			end)
		end)

		TGNS.RegisterEventHook("ClientConfirmConnect", function(client)
			showHelpText(client)
		end)

		local showHillTextMessages = function(messagesDatas, client, duration)
			TGNS.DoFor(messagesDatas, function(d)
				local message = d.m
				local teamNumber = d.t
				local rgb = TGNS.GetTeamRgb(teamNumber)
				local channel = 64 + teamNumber
				Shine.ScreenText.Add(channel, {X = 0.8, Y = 0.30, Text = message, Duration = duration, R = rgb.R, G = rgb.G, B = rgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, client)
			end)
		end
		local showTeleporterText = function(message, client, duration)
			Shine.ScreenText.Add(64, {X = 0.35, Y = 0.35, Text = message, Duration = duration, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, client)
		end
		local commandStructureIsAliveOnHill = function(e) return TGNS.GetEntityLocationName(e) == hillLocationName and TGNS.StructureIsAlive(e) and TGNS.StructureIsBuilt(e) end
		TGNS.ScheduleActionInterval(1, function()
			-- debug("every second")

			configureOutOfBaseTeleporters()
			configurePitBottomTeleporter()

			local playerList = TGNS.GetPlayerList()

			local bottomFloorTele = TGNS.GetFirst(TGNS.GetEntitiesByName("TeleportTrigger", "bottomfloortele"))

			local playingClients = TGNS.GetPlayingClients(playerList)
			local playingPlayers = TGNS.GetPlayers(playingClients)
			local teamNumberToHarm
			if TGNS.IsGameInProgress() then
				TGNS.DoFor(TGNS.Where(playerList, function(p) return TGNS.Has({"Marine Start", "The Hive"}, TGNS.GetPlayerLocationName(p)) end), function(p)
					if TGNS.GetIsPlayerVirtual(p) then
						bottomFloorTele:OnTriggerEntered(p, bottomFloorTele)
					else
						local c = TGNS.GetClient(p)
						if not TGNS.IsClientCommander(c) then
							teleportOutOfBaseAllowedAt[c] = teleportOutOfBaseAllowedAt[c] or 0
							local secondsUntilTeleportOutOfBaseAllowed = math.floor(teleportOutOfBaseAllowedAt[c] - Shared.GetTime())
							if secondsUntilTeleportOutOfBaseAllowed > -3 then
								local message = string.format("You may return to %s %s", hillLocationName, secondsUntilTeleportOutOfBaseAllowed > 0 and string.format("in: %s", Pluralize(secondsUntilTeleportOutOfBaseAllowed, "second")) or "NOW!")
								local rgb = TGNS.GetTeamRgb(TGNS.GetClientTeamNumber(c))
								Shine.ScreenText.Add(68, {X = 0.5, Y = 0.25, Text = message, Duration = 1.5, R = rgb.R, G = rgb.G, B = rgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
							end
						end
					end
				end)


				TGNS.DoFor(TGNS.Where(playerList, function(p) return TGNS.GetIsPlayerVirtual(p) and TGNS.Has({"Marine Start", "The Hive"}, TGNS.GetPlayerLocationName(p)) end), function(p)
					bottomFloorTele:OnTriggerEntered(p, bottomFloorTele)
				end)

				local gameDurationInSeconds = TGNS.RoundPositiveNumberDown(TGNS.GetCurrentGameDurationInSeconds())
				TGNS.DoFor(playingClients, function(c)
			   		local p = TGNS.GetPlayer(c)
		   			if gameDurationInSeconds < PRE_GAME_DURATION_IN_SECONDS and teamNumberWhichCalledWinOrLose == nil then
						local secondsUntilTeleportersComeOnline = PRE_GAME_DURATION_IN_SECONDS - gameDurationInSeconds
						-- local message = string.format("%s opens in %s. Tech up and/or plan your initial strategy!\nNiether team may drop a Command Structure in %s until it opens!", hillLocationName, Pluralize(secondsUntilTeleportersComeOnline, "second"), hillLocationName)
						local message = string.format("%s opens in %s. Tech up and/or plan your initial strategy!", hillLocationName, Pluralize(secondsUntilTeleportersComeOnline, "second"))
						showTeleporterText(message, c, 3)
		   			else
		   				if not playersAreAllowedOutOfBase then
			   				playersAreAllowedOutOfBase = true
		   					local soundIndex = TGNS.PlayerIsMarine(p) and 11 or 12
		   					TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.arclight.HILL_SOUND, {i=soundIndex})
		   				end
		   				if gameDurationInSeconds < PRE_GAME_DURATION_IN_SECONDS + 10 then
							local message = string.format("%s is OPEN!", hillLocationName)
							showTeleporterText(message, c, 3)
							doForAllOutOfBaseTeleporters(function(teleporter)
								local players = GetEntitiesWithinRange("Player", teleporter:GetOrigin(), 1)
								TGNS.DoFor(players, function(p)
									teleporter:OnTriggerEntered(p, teleporter)
								end)
							end)
		   				end
		   			end
		   			if TGNS.GetClientLocationName(c) == "tube" then
		   				local currentTubeOrigin = p:GetOrigin()
		   				if lastTubeOrigin[c] == currentTubeOrigin then
			   				bottomFloorTele:OnTriggerEntered(p, bottomFloorTele)
		   				end
		   				lastTubeOrigin[c] = currentTubeOrigin
		   			end
				end)

				TGNS.DoFor(TGNS.Where(TGNS.GetEntitiesForTeam("Contamination", kAlienTeamType), function(e) return TGNS.GetEntityLocationName(e) == "Marine Start" end), function(e)
					TGNS.DestroyEntity(e)
				end)

			end

			local marinePlayers = TGNS.GetMarinePlayers(playerList)
			local alienPlayers = TGNS.GetAlienPlayers(playerList)
			local lastMarinesOnHillCount = marinesOnHillCount
			local lastAliensOnHillCount = aliensOnHillCount
			marinesOnHillCount = #TGNS.Where(marinePlayers, function(p) return TGNS.GetPlayerLocationName(p) == hillLocationName and TGNS.IsPlayerAlive(p) end)
			aliensOnHillCount = #TGNS.Where(alienPlayers, function(p) return TGNS.GetPlayerLocationName(p) == hillLocationName and TGNS.IsPlayerAlive(p) end)
			if (marinesOnHillCount > lastAliensOnHillCount) or (teamNumberWhichCalledWinOrLose == kAlienTeamType) then
				teamNumberToHarm = kAlienTeamType
			elseif (aliensOnHillCount > lastMarinesOnHillCount) or (teamNumberWhichCalledWinOrLose == kMarineTeamType) then
				teamNumberToHarm = kMarineTeamType
			end

			if Shine.Plugins.mapvote:VoteStarted() then
				Shine:RemoveText(nil, { ID = 63 } )
				Shine:RemoveText(nil, { ID = 65 } )
				Shine:RemoveText(nil, { ID = 66 } )
			else
				local hillTextMessageDatas = {}
				TGNS.DoForPairs(pointsRemaining, function(teamNumber, points)
					local onHillCount = teamNumber == kMarineTeamType and marinesOnHillCount or aliensOnHillCount
					local otherTeamOnHillCount = teamNumber == kMarineTeamType and aliensOnHillCount or marinesOnHillCount
					local teamTotalPlayerCount = teamNumber == kMarineTeamType and #marinePlayers or #alienPlayers
					local otherTeamTotalPlayerCount = teamNumber == kMarineTeamType and #alienPlayers or #marinePlayers
					local originalPoints = points
					local maximumTeamPoints = pointsMax[teamNumber]
					local maximumAllowedPoints = maximumTeamPoints - math.floor(maxPointsPenaltyAmount[teamNumber])
					local maxPointsPenaltyMaxAmount = (maximumTeamPoints * 0.9)
					if TGNS.IsGameInProgress() then
						local shouldDamage = teamNumber == teamNumberToHarm
						local damageRate = 4.0
						local damageAmount = maximumTeamPoints * (damageRate / 100) * (shouldDamage and 1 or -REPLENISH_MULTIPLIER)
						if shouldDamage then
							local teamPercentageThatIsDamaging = otherTeamOnHillCount / otherTeamTotalPlayerCount
							damageAmount = damageAmount * teamPercentageThatIsDamaging
							if teamNumberWhichCalledWinOrLose == teamNumberToHarm or #playingClients == 16 then
								damageAmount = damageAmount * 2
							end
							if teamPercentageThatIsDamaging > 0 then
								local level = 10 - (math.ceil(10 * teamPercentageThatIsDamaging) - 1)
								local playersToPlaySoundTo = TGNS.IsProduction() and (teamNumberToHarm == kMarineTeamType and marinePlayers or alienPlayers) or playerList
								TGNS.DoFor(playersToPlaySoundTo, function(p)
									-- debug(string.format("Playing level %s to %s...", level, TGNS.GetPlayerName(p)))
									local shouldRepeat = points - damageAmount <= maximumTeamPoints * 0.33
									TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.arclight.HILL_SOUND, {i=level,r=shouldRepeat})
								end)
							end
						end

						local maxPointsPenalty = (damageAmount * (shouldDamage and 0.1 or 0.05))
						maxPointsPenaltyAmount[teamNumber] = maxPointsPenaltyAmount[teamNumber] + maxPointsPenalty
						maxPointsPenaltyAmount[teamNumber] = maxPointsPenaltyAmount[teamNumber] >= 0 and maxPointsPenaltyAmount[teamNumber] or 0
						maxPointsPenaltyAmount[teamNumber] = maxPointsPenaltyAmount[teamNumber] <= maxPointsPenaltyMaxAmount and maxPointsPenaltyAmount[teamNumber] or maxPointsPenaltyMaxAmount
						maximumAllowedPoints = maximumTeamPoints - math.floor(maxPointsPenaltyAmount[teamNumber])
						points = points - damageAmount
						points = points >= 0 and points or 0
						points = points <= maximumAllowedPoints and points or maximumAllowedPoints
					end

					table.insert(hillTextMessageDatas, {m=string.format("%s%s: %s/%s (%s %s)", teamNumber == kAlienTeamType and "\n" or "", TGNS.GetTeamName(teamNumber), math.ceil(points), math.ceil(maximumAllowedPoints), onHillCount, (teamNumberToHarm ~= nil and teamNumberToHarm ~= teamNumber) and "controlling" or "gathered"),t=teamNumber})

					if originalPoints ~= 0 and points == 0 then
						TGNS.DoFor(TGNS.Where(TGNS.GetCommandStructures(), function(s) return TGNS.GetEntityLocationName(s) ~= hillLocationName and TGNS.StructureIsAlive(s) and s:GetTeamNumber() == teamNumber end), function(s)
							s:Kill()
						end)
					end
					pointsRemaining[teamNumber] = points
				end)
				TGNS.DoFor(TGNS.GetClientList(), function(c)
					showHillTextMessages(hillTextMessageDatas, c, 2)
				end)
			end

		end)
	end

	function Plugin:Initialise()
		self.Enabled = ArclightModsEnabled

		Shine.Timer.Simple(5, function()
			if Shared.GetMapName() == ArclightMapName then
				if Client then OnClientInitialise() end
				if Server then OnServerInitialise() end
			end
		end)
		return true
	end

	function Plugin:Cleanup()
	    --Cleanup your extra stuff like timers, data etc.
	    self.BaseClass.Cleanup( self )
	end

	Shine:RegisterExtension("arclight", Plugin )
end