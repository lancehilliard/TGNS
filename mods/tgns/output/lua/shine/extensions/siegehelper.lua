local md = TGNSMessageDisplayer.Create()
local isSiege = false
local siegeAdvisory = "Alltalk enabled during siege play. Siege is used only to seed the server until we have enough for normal 8v8 NS2 play."
local hillPoints = 0
local HILL_POSSESSION_POINT_DELTA = 3
local pointsRemaining = {}
local pointsMax = {}
local marinesOnHillCount
local aliensOnHillCount
local PRE_GAME_DURATION_IN_SECONDS = 60
local REPLENISH_MULTIPLIER = 0.25
local playersAreAllowedOutOfBase = true
local isWallWalkingPossible = {}
local lastReturnTeleporterTime = {}
local RETURN_TELEPORTER_COOLDOWN_IN_SECONDS = 10
local MARINE_STARTING_POINTS = 1000
local ALIEN_STARTING_POINTS = 1000
local lastTubeOrigin = {}
local teamNumberWhichCalledWinOrLose

local function prepareForNextGame(countdownStarting)
	pointsRemaining[kMarineTeamType] = MARINE_STARTING_POINTS
	pointsRemaining[kAlienTeamType] = ALIEN_STARTING_POINTS
	marinesOnHillCount = 0
	aliensOnHillCount = 0
	teamNumberWhichCalledWinOrLose = nil
	if countdownStarting then
		playersAreAllowedOutOfBase = false
	end
end

local function showSiegeAdvisory(client)
	if Shine:IsValidClient(client) then
		md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), siegeAdvisory)
		-- md:ToClientConsole(client, "------------")
		-- md:ToClientConsole(client, " TGNS BOTS")
		-- md:ToClientConsole(client, "------------")
		-- md:ToClientConsole(client, string.format("Bots are used on TGNS to seed the server to %s non-AFK human players.", PLAYER_COUNT_THRESHOLD))
		-- md:ToClientConsole(client, string.format("When the server reaches %s non-AFK human players, the aliens surrender and humans-only NS2 play begins.", PLAYER_COUNT_THRESHOLD))
		-- md:ToClientConsole(client, "During TGNS bots play: marines spawn more quickly than in normal NS2 play")
		-- md:ToClientConsole(client, "During TGNS bots play: marines receive personal resources more quickly than in normal NS2 play")
		-- md:ToClientConsole(client, "During TGNS bots play: marines spawn more quickly than in normal NS2 play")
		-- md:ToClientConsole(client, "During TGNS bots play: marines receive catpacks when killing bots")
		-- md:ToClientConsole(client, "During TGNS bots play: marines receive a clip of ammo when killing bots")
		-- md:ToClientConsole(client, "During TGNS bots play: alien hives have more health")
		-- md:ToClientConsole(client, "During TGNS bots play: aliens get one free persistent crag")
		-- md:ToClientConsole(client, "During TGNS bots play: alltalk is enabled")
		-- md:ToClientConsole(client, "Many thanks to TAW|Leech for contributing to our skulk bot brain code!")
	end
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "siegehelper.json"

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
end

function Plugin:ClientConfirmConnect(client)
	if isSiege and not TGNS.GetIsClientVirtual(client) then
		showSiegeAdvisory(client)
		TGNS.ScheduleAction(5, function() showSiegeAdvisory(client) end)
		TGNS.ScheduleAction(12, function() showSiegeAdvisory(client) end)
		TGNS.ScheduleAction(20, function() showSiegeAdvisory(client) end)
		TGNS.ScheduleAction(40, function() showSiegeAdvisory(client) end)
	end
end

function Plugin:CreateCommands()
	if not TGNS.IsProduction() then
		local levelsCommand = self:BindCommand( "sh_testlevel", "lvl", function(client, level)
			level = tonumber(level)
			TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), Shine.Plugins.scoreboard.HILL_SOUND, {i=level})
		end)
		levelsCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
		levelsCommand:Help( "<level> Test sound levels." )
	end
end

function Plugin:IsArclight()
	local result = TGNS.GetCurrentMapName() == "ns2_tgns_arclight"
	return result
end

function Plugin:GetHillLocationName()
	return "The Pit"
end

function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()
    -- TGNS.ExecuteServerCommand(string.format("sh_alltalk %s", TGNS.Contains(TGNS.GetCurrentMapName(), "siege") and "on" or "off"))

	prepareForNextGame()
    pointsMax[kMarineTeamType] = MARINE_STARTING_POINTS
    pointsMax[kAlienTeamType] = ALIEN_STARTING_POINTS

    TGNS.ScheduleAction(5, function()
	    if not TGNS.IsProduction() then
	    	PRE_GAME_DURATION_IN_SECONDS = 3
	    end
    	if TGNS.Contains(TGNS.GetCurrentMapName(), "siege") then
    		Shine.Plugins.communityslots.Config.PublicSlots = 20
    		isSiege = true
    	end
    end)
    local originalGetCanPlayerHearPlayer
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		if isSiege and not (Shine.Plugins.sidebar and Shine.Plugins.sidebar.IsEitherPlayerInSidebar and Shine.Plugins.sidebar:IsEitherPlayerInSidebar(listenerPlayer, speakerPlayer)) then
			result = true
		end
		return result
	end)

	TGNS.ScheduleAction(5, function()
		if self:IsArclight() then
			local hillLocationName = self:GetHillLocationName()

			local debug = function(message)
				if not TGNS.IsProduction() then
					Shared.Message(string.format("---------------------------------------------------- siegehelper: %s", message))
				end
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
			kStompEnergyCost = kStompEnergyCost * 2.0

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
		   				lastReturnTeleporterTime[TGNS.GetClient(enterEnt)] = Shared.GetTime()
		   				teamReturnTele:OnTriggerEntered(enterEnt, triggerEnt)
		   			end
	   			end
			end

			local brieflySetWallwalkingValue = function(client, duration)
   				if TGNS.GetIsClientVirtual(client) then
					isWallWalkingPossible[client] = false
					-- debug(string.format("Disabling wallwalk for %s...", TGNS.GetClientName(client)))
					TGNS.ScheduleAction(duration, function()
						-- debug(string.format("Enabling wallwalk for %s...", TGNS.GetClientName(client)))
						isWallWalkingPossible[client] = true
					end)
   				end
			end

			-- debug("teleporters:")
			-- TGNS.DoFor(TGNS.GetEntitiesWithClassName("TeleportTrigger"), function(teleporter)
			-- 	Shared.Message(GetEntityInfo(teleporter))
			-- end)

			local configurePitBottomTeleporter = function()
				TGNS.DoFor(TGNS.GetEntitiesByName("TeleportTrigger", "bottomfloortele"), function(teleporter)
		   			local originalOnTriggerEntered = teleporter.OnTriggerEntered
		   			teleporter.OnTriggerEntered = function(teleporterSelf, enterEnt, triggerEnt)
		   				local client = TGNS.GetClient(enterEnt)
				   		brieflySetWallwalkingValue(client, 3)
				   		-- originalOnTriggerEntered(teleporterSelf, enterEnt, triggerEnt)
				   		local destinationTeleporterName = TGNS.GetFirst(TGNS.GetRandomizedElements(TGNS.PlayerIsMarine(enterEnt) and {"MT1","MT2","MT3","MT4"} or {"AT1","AT2","AT3","AT4"}))
				   		local destinationTele = TGNS.GetFirst(TGNS.GetEntitiesByName("TeleportTrigger", destinationTeleporterName))
				   		destinationTele:OnTriggerEntered(enterEnt, triggerEnt)		
		   			end
				end)
			end

			local configureOutOfBaseTeleporters = function()
				local outOfBaseTeleporters = {}
				TGNS.DoFor({"MT1","MT2","MT3","MT4","AT1","AT2","AT3","AT4"}, function(outOfBaseTeleporterName)
					TGNS.DoFor(TGNS.GetEntitiesByName("TeleportTrigger", outOfBaseTeleporterName), function(teleporter) table.insert(outOfBaseTeleporters, teleporter) end)
				end)
	   			TGNS.DoFor(outOfBaseTeleporters, function(teleporter)
	   				-- debug(string.format("teleporter: %s", teleporter))
		   			local originalOnTriggerEntered = teleporter.OnTriggerEntered
		   			teleporter.OnTriggerEntered = function(teleporterSelf, enterEnt, triggerEnt)
		   				local client = TGNS.GetClient(enterEnt)
		   				-- debug(string.format("enterEnt: %s", TGNS.GetClientName(client)))
		   				if playersAreAllowedOutOfBase then
			   				lastReturnTeleporterTime[client] = lastReturnTeleporterTime[client] or 0
			   				-- debug(string.format("lastReturnTeleporterTime[client]: %s", lastReturnTeleporterTime[client]))
			   				local secondsUntilCanReturnToFight = RETURN_TELEPORTER_COOLDOWN_IN_SECONDS - math.floor(Shared.GetTime() - lastReturnTeleporterTime[client])
		   					if secondsUntilCanReturnToFight <= 0 or not TGNS.IsGameInProgress() then
				   				originalOnTriggerEntered(teleporterSelf, enterEnt, triggerEnt)
				   				brieflySetWallwalkingValue(client, 3)
		   					else
		   						md:ToPlayerNotifyInfo(enterEnt, string.format("You recently teleported back to base. Wait %s seconds before returning to %s.", secondsUntilCanReturnToFight, hillLocationName))
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

			local alienMaxSpeedModifier = kCelerityAddSpeed
		    local originalOnosGetMaxSpeed
			originalOnosGetMaxSpeed = TGNS.ReplaceClassMethod("Onos", "GetMaxSpeed", function(alienUnitSelf, possible)
				local result = originalOnosGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedModifier
				return result
			end)

		    local originalFadeGetMaxSpeed
			originalFadeGetMaxSpeed = TGNS.ReplaceClassMethod("Fade", "GetMaxSpeed", function(alienUnitSelf, possible)
				local result = originalFadeGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedModifier
				return result
			end)

		    local originalLerkGetMaxSpeed
			originalLerkGetMaxSpeed = TGNS.ReplaceClassMethod("Lerk", "GetMaxSpeed", function(alienUnitSelf, possible)
				local result = originalLerkGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedModifier
				return result
			end)

		    local originalGorgeGetMaxSpeed
			originalGorgeGetMaxSpeed = TGNS.ReplaceClassMethod("Gorge", "GetMaxSpeed", function(alienUnitSelf, possible)
				local result = originalGorgeGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedModifier
				return result
			end)

		    local originalSkulkGetMaxSpeed
			originalSkulkGetMaxSpeed = TGNS.ReplaceClassMethod("Skulk", "GetMaxSpeed", function(alienUnitSelf, possible)
				local result = originalSkulkGetMaxSpeed(alienUnitSelf, possible) * alienMaxSpeedModifier
				return result
			end)

			local originalHiveGenerateEggSpawns
			originalHiveGenerateEggSpawns = TGNS.ReplaceClassMethod("Hive", "GenerateEggSpawns", function(hiveSelf, hiveLocationName)
				if hiveLocationName ~= hillLocationName then
					originalHiveGenerateEggSpawns(hiveSelf, hiveLocationName)
				-- else
				-- 	debug("skipping GenerateEggSpawns for Pit hive...")
				end
			end)

			local originalSkulkGetIsWallWalkingPossible
			originalSkulkGetIsWallWalkingPossible = TGNS.ReplaceClassMethod("Skulk", "GetIsWallWalkingPossible", function(skulkSelf)
				local result = originalSkulkGetIsWallWalkingPossible(skulkSelf)
				local client = TGNS.GetClient(skulkSelf)
				if TGNS.GetIsClientVirtual(client) then
					result = isWallWalkingPossible[client] == nil or isWallWalkingPossible[client] == true
				end
				return result
			end)

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
				embryoSelf.gestationTime = 0.75
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
				if TGNS.IsClientReadyRoom(client) then
					message =           "This map is a work in progress. It takes a \"king of the hill\" format, where you control a central, contested area to win.\n"
					message = message .. string.format("On this map, that area is a central platform in %s, and you win by standing on this platform to drive down the points\n", Shine.Plugins.siegehelper:GetHillLocationName())
					Shine.ScreenText.Add(68, {X = 0.2, Y = 0.75, Text = message, Duration = 120, R = rgb.R, G = rgb.G, B = rgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, client)
					message = "\n\nof the other team. Meanwhile, they're doing the same thing! The first team to drive the other team to zero points wins!"
					Shine.ScreenText.Add(69, {X = 0.2, Y = 0.75, Text = message, Duration = 120, R = rgb.R, G = rgb.G, B = rgb.B, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, client)
				else
					Shine:RemoveText(client, { ID = 68 } )
					Shine:RemoveText(client, { ID = 69 } )
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
				showHelpText(client)
			end)

			TGNS.RegisterEventHook("ClientConfirmConnect", function(client)
				showHelpText(client)
			end)

			local originalCommandStationGetCanRecycleOverride
			originalCommandStationGetCanRecycleOverride = TGNS.ReplaceClassMethod("CommandStation", "GetCanRecycleOverride", function(commandStationSelf)
				return false
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
				local playingClients = TGNS.GetPlayingClients(playerList)
				local playingPlayers = TGNS.GetPlayers(playingClients)
				local teamNumberToHarm
				if TGNS.IsGameInProgress() then
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
			   					TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.HILL_SOUND, {i=soundIndex})
			   				end
			   				if gameDurationInSeconds < PRE_GAME_DURATION_IN_SECONDS + 10 then
								local message = string.format("%s is OPEN!", hillLocationName)
								showTeleporterText(message, c, 3)
			   				end
			   			end
			   			if TGNS.GetClientLocationName(c) == "tube" then
			   				local currentTubeOrigin = p:GetOrigin()
			   				if lastTubeOrigin[c] == currentTubeOrigin then
				   				local bottomFloorTele = TGNS.GetFirst(TGNS.GetEntitiesByName("TeleportTrigger", "bottomfloortele"))
				   				bottomFloorTele:OnTriggerEntered(p, bottomFloorTele)
			   				end
			   				lastTubeOrigin[c] = currentTubeOrigin
			   			end
					end)

--[[
					local gameDurationInSeconds = TGNS.RoundPositiveNumberDown(TGNS.GetCurrentGameDurationInSeconds())
		   			if gameDurationInSeconds >= PRE_GAME_DURATION_IN_SECONDS and not playersAreAllowedOutOfBase then
		   				playersAreAllowedOutOfBase = true
		   				TGNS.DoFor(playingPlayers, function(p)
		   					local soundIndex = TGNS.PlayerIsMarine(p) and 11 or 12
		   					TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.HILL_SOUND, {i=soundIndex})
		   				end)
		   			end

					if gameDurationInSeconds < PRE_GAME_DURATION_IN_SECONDS then
						TGNS.DoFor(playingClients, function(c)
							local secondsUntilTeleportersComeOnline = PRE_GAME_DURATION_IN_SECONDS - gameDurationInSeconds
							-- local message = string.format("%s opens in %s. Tech up and/or plan your initial strategy!\nNiether team may drop a Command Structure in %s until it opens!", hillLocationName, Pluralize(secondsUntilTeleportersComeOnline, "second"), hillLocationName)
							local message = string.format("%s opens in %s. Tech up and/or plan your initial strategy!", hillLocationName, Pluralize(secondsUntilTeleportersComeOnline, "second"))
							showTeleporterText(message, c, 3)
						end)
					elseif gameDurationInSeconds < PRE_GAME_DURATION_IN_SECONDS + 10 then
						TGNS.DoFor(playingClients, function(c)
							local message = string.format("%s is OPEN!", hillLocationName)
							showTeleporterText(message, c, 3)
						end)
					else
						Shine:RemoveText(nil, { ID = 64 } )
					end

					-- local hillTechPoint = TGNS.GetFirst(TGNS.Where(TGNS.GetTechPoints(), function(t) return TGNS.GetEntityLocationName(t) == hillLocationName end))
					-- hillTechPoint:SetIsVisible(gameDurationInSeconds >= PRE_GAME_DURATION_IN_SECONDS)
]]

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
						if TGNS.IsGameInProgress() then
							local shouldDamage = teamNumber == teamNumberToHarm
							local damageRate = 4.0
							local maximumTeamPoints = pointsMax[teamNumber]
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
										TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.HILL_SOUND, {i=level})
									end)
								end
							end

							points = points - damageAmount
							points = points >= 0 and points or 0
							points = points <= maximumTeamPoints and points or maximumTeamPoints
						end

						table.insert(hillTextMessageDatas, {m=string.format("%s%s: %s (%s %s)", teamNumber == kAlienTeamType and "\n" or "", TGNS.GetTeamName(teamNumber), math.ceil(points), onHillCount, (teamNumberToHarm ~= nil and teamNumberToHarm ~= teamNumber) and "controlling" or "gathered"),t=teamNumber})

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
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("siegehelper", Plugin )