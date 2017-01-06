local EMPTY_VALUE = "NULL"
local currentGame
local lastGestationData = {}

local function initCurrentGameObject()
	currentGame = {}
	currentGame["classKillCounts"] = {}
	currentGame["classBuildCounts"] = {}
	currentGame["classBuildCompleteCounts"] = {}
	currentGame["clients"] = {}
	currentGame["WeldHealth"] = {}
	currentGame["HealSpray"] = {}
	currentGame["ClassDurations"] = {}
	currentGame["HarvestersKilled"] = {}
	currentGame["ExtractorsKilled"] = {}
	currentGame["ParasitesInjested"] = {}
	currentGame["ParasitesLanded"] = {}
end

local trackedClassData = { {PlayerDataPropertyName="GorgeSeconds", TechId=kTechId.Gorge}, {PlayerDataPropertyName="LerkSeconds", TechId=kTechId.Lerk}, {PlayerDataPropertyName="FadeSeconds", TechId=kTechId.Fade}, {PlayerDataPropertyName="OnosSeconds", TechId=kTechId.Onos} }

local function addClientClassDuration(client)
	if client and Shine:IsValidClient(client) and not TGNS.GetIsClientVirtual(client) then
		local lastGestation = lastGestationData[client]
		if lastGestation and lastGestation.what and lastGestation.when and currentGame then
			local classDuration = Shared.GetTime() - lastGestation.when
			currentGame["ClassDurations"][client] = currentGame["ClassDurations"][client] or {}
			local currentGameClassSeconds = currentGame["ClassDurations"][client][lastGestation.what.TechId] or 0
			currentGame["ClassDurations"][client][lastGestation.what.TechId] = currentGameClassSeconds + classDuration
			lastGestationData[client] = nil
			-- TGNS.DebugPrint(string.format("addClientClassDuration[%s]: id=%s; techid=%s (%s); addingDuration=%s; totalDuration=%s", currentGame["startTimeSeconds"], TGNS.GetClientSteamId(client), lastGestation.what.PlayerDataPropertyName, lastGestation.what.TechId, classDuration, currentGame["ClassDurations"][client][lastGestation.what.TechId]))
		end
	end
end

local function audit(statementId, data, callback)
	local updateUrl = string.format("%s&v=%s&g=%s&s=%s&n=%s", TGNS.Config.AuditEndpointBaseUrl, TGNS.UrlEncode(json.encode(data)), TGNS.UrlEncode(Shine.GetGamemode()), statementId, TGNS.UrlEncode(TGNS.GetSimpleServerName()))
	-- TGNS.DebugPrint(string.format("Auditing URL: %s", updateUrl))
	TGNS.GetHttpAsync(updateUrl, callback)
end

local function incrementCurrentGameClassKillCounts(killedPlayer)
	local className = TGNS.GetPlayerClassName(killedPlayer)
	currentGame["classKillCounts"][className] = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"][className]) + 1
end

local Plugin = {}

function Plugin:ClientConfirmConnect(client)
end

function Plugin:OnConstructInit(building)
	local className = building:GetClassName()
	if className:lower() ~= "cyst" then
		currentGame["classBuildCounts"][className] = TGNS.GetNumericValueOrZero(currentGame["classBuildCounts"][className]) + 1
		-- Shared.Message("OnConstructInit - className: " .. tostring(className))
		local originalSetConstructionComplete = building.SetConstructionComplete
		building.SetConstructionComplete = function(buildingSelf, builder)
			originalSetConstructionComplete(buildingSelf, builder)
			local builderClient = TGNS.GetClient(builder)
			if builderClient then
				local className = buildingSelf:GetClassName()
				-- Shared.Message("SetConstructionComplete - className: " .. tostring(className))
				currentGame["classBuildCompleteCounts"][builderClient] = currentGame["classBuildCompleteCounts"][builderClient] or {}
				currentGame["classBuildCompleteCounts"][builderClient][className] = TGNS.GetNumericValueOrZero(currentGame["classBuildCompleteCounts"][builderClient][className]) + 1
			end
		end


	end
end

function Plugin:OnEntityKilled(gamerules, victim, attacker, inflictor, point, dir)
	if attacker and inflictor and victim then
		local victimClassName = victim:GetClassName()
		if victimClassName == "Marine" then
			local primaryWeapon = victim.GetWeaponInHUDSlot and victim:GetWeaponInHUDSlot(1)
			if primaryWeapon then
				if primaryWeapon:isa("Shotgun") then
					victimClassName = "ShotgunMarine"
				elseif primaryWeapon:isa("Flamethrower") then
					victimClassName = "FlamethrowerMarine"
				elseif primaryWeapon:isa("GrenadeLauncher") then
					victimClassName = "GranadeLauncherMarine"
				end
			end
		elseif victimClassName == "Exo" then
			victimClassName = victim.layout
		end
		currentGame["classKillCounts"][victimClassName] = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"][victimClassName]) + 1

		local attackerClient = TGNS.GetClient(attacker)
		if attackerClient then
			local currentGamePersonalCounterToIncrement
			if victim:isa("Harvester") then
				currentGamePersonalCounterToIncrement = "HarvestersKilled"
			elseif victim:isa("Extractor") then
				currentGamePersonalCounterToIncrement = "ExtractorsKilled"
			end
			if currentGamePersonalCounterToIncrement then
				currentGame[currentGamePersonalCounterToIncrement][attackerClient] = currentGame[currentGamePersonalCounterToIncrement][attackerClient] or 0
				currentGame[currentGamePersonalCounterToIncrement][attackerClient] = currentGame[currentGamePersonalCounterToIncrement][attackerClient] + 1
			end
		end
	end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
	if TGNS.IsGameplayTeamNumber(newTeamNumber) then
		if TGNS.GetIsClientVirtual(client) then
			currentGame["includedBots"] = true
		else
			table.insertunique(currentGame["clients"], client)
		end
	end
	addClientClassDuration(client)
end

function Plugin:ClientDisconnect(client)
	addClientClassDuration(client)
end

function Plugin:Initialise()
    self.Enabled = true
    initCurrentGameObject()
	TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
		initCurrentGameObject()
		currentGame["startTimeSeconds"] = secondsSinceEpoch
		currentGame["isCaptainsMode"] = Shine.Plugins.captains and Shine.Plugins.captains.IsCaptainsModeEnabled and Shine.Plugins.captains:IsCaptainsModeEnabled()
		currentGame["includedBots"] = TGNS.Any(TGNS.GetClientList(), TGNS.GetIsClientVirtual)
		TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c)
			table.insertunique(currentGame["clients"], c)
		end)
		lastGestationData = {}
	end)
	TGNS.RegisterEventHook("WinOrLoseCalled", function(teamNumber)
		currentGame["surrenderTeamNumber"] = teamNumber
	end)
	TGNS.RegisterEventHook("WinOrLoseCountdownChanged", function(countdownValue)
		currentGame["winOrLoseEndGameCountdownValue"] = countdownValue
	end)
	TGNS.RegisterEventHook("FullGamePlayed", function(clients, winningTeam, gameDurationInSeconds)
		TGNS.DoFor(clients, addClientClassDuration)
		local gamerules = GetGamerules()
    	local gameData = {}
    	gameData.StartTimeSeconds = currentGame["startTimeSeconds"]
    	gameData.DurationInSeconds = gameDurationInSeconds
    	gameData.WinningTeamNumber = winningTeam and winningTeam:GetTeamNumber() or 0
    	gameData.TotalPlayerCount = #currentGame["clients"]
    	gameData.FullGameSupportingMemberCount = #TGNS.Where(clients, TGNS.IsClientSM)
    	gameData.FullGamePrimerWithGamesCount = #TGNS.Where(clients, TGNS.HasClientSignedPrimerWithGames)
    	gameData.FullGameStrangerCount = #TGNS.Where(clients, TGNS.IsClientStranger)
		gameData.SkulksKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Skulk"])
		gameData.GorgesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Gorge"])
		gameData.LerksKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Lerk"])
		gameData.FadesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Fade"])
		gameData.OnosKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Onos"])
		gameData.RifleMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Marine"])
		gameData.JetpackMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["JetpackMarine"])
		gameData.ClawMinigunMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["ClawMinigun"])
		gameData.ClawRailgunMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["ClawRailgun"])
		gameData.MinigunMinigunMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["MinigunMinigun"])
		gameData.RailgunRailgunMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["RailgunRailgun"])
		gameData.ShotgunMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["ShotgunMarine"])
		gameData.FlamethrowerMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["FlamethrowerMarine"])
		gameData.GrenadeLauncherMarinesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["GranadeLauncherMarine"])
		gameData.HivesKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Hive"])
		gameData.ChairsKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["CommandStation"])
		gameData.HarvestersKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Harvester"])
		gameData.ExtractorsKilled = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"]["Extractor"])
		gameData.CaptainsMode = currentGame["isCaptainsMode"] == true
		gameData.SurrenderTeamNumber = currentGame["surrenderTeamNumber"] or EMPTY_VALUE
		gameData.WinOrLoseEndGameCountdownValue = currentGame["winOrLoseEndGameCountdownValue"] or EMPTY_VALUE
		gameData.MarineTeamResourcesTotal = gamerules.team1:GetTotalTeamResources()
		gameData.AlienTeamResourcesTotal = gamerules.team2:GetTotalTeamResources()
		gameData.MarineStartLocationName = gamerules.startingLocationNameTeam1 or EMPTY_VALUE
		gameData.AlienStartLocationName = gamerules.startingLocationNameTeam2 or EMPTY_VALUE
		gameData.StartingLocationsPathDistance = gamerules.startingLocationsPathDistance or EMPTY_VALUE
		gameData.MarineBonusResourcesAwarded = (Shine.Plugins.tf_comeback and Shine.Plugins.tf_comeback.Enabled and Shine.Plugins.tf_comeback.GetBonusResourcesAwardedSoFar) and Shine.Plugins.tf_comeback:GetBonusResourcesAwardedSoFar(1) or 0
		gameData.AlienBonusResourcesAwarded = (Shine.Plugins.tf_comeback and Shine.Plugins.tf_comeback.Enabled and Shine.Plugins.tf_comeback.GetBonusResourcesAwardedSoFar) and Shine.Plugins.tf_comeback:GetBonusResourcesAwardedSoFar(2) or 0
		gameData.StartingLocationsPathDistance = gamerules.startingLocationsPathDistance or EMPTY_VALUE
		gameData.BuildNumber = Shared.GetBuildNumber()
		gameData.MapName = TGNS.GetCurrentMapName()
		gameData.IncludedBots = currentGame["includedBots"]

		audit(382, gameData, function(gameDataAuditResponseJson)
			local gameDataAuditResponse = json.decode(gameDataAuditResponseJson) or {}
			if gameDataAuditResponse.success then
		    	TGNS.DoFor(clients, function(c)
		    		if Shine:IsValidClient(c) and not TGNS.GetIsClientVirtual(c) then
		    			TGNS.ScheduleAction(0, function()
		    				if Shine:IsValidClient(c) then
				    			local p = TGNS.GetPlayer(c)
					    		local playerData = {}
					    		playerData.StartTimeSeconds = gameData.StartTimeSeconds
					    		playerData.PlayerId = TGNS.GetClientSteamId(c)
					    		playerData.MarineSeconds = p:GetMarinePlayTime()
					    		playerData.AlienSeconds = p:GetAlienPlayTime()
					    		playerData.CommanderSeconds = p:GetCommanderTime()
					    		playerData.EndGameCommander = Shine.Plugins.communityslots.IsClientRecentCommander and Shine.Plugins.communityslots:IsClientRecentCommander(c)
					    		playerData.Captain = Shine.Plugins.captains.IsClientCaptain and Shine.Plugins.captains:IsClientCaptain(c)
					    		playerData.Score = TGNS.GetPlayerScore(p)
					    		playerData.Kills = TGNS.GetPlayerKills(p)
					    		playerData.Assists = TGNS.GetPlayerAssists(p)
					    		playerData.Deaths = TGNS.GetPlayerDeaths(p)
					    		playerData.SupportingMember = TGNS.IsClientSM(c)
					    		playerData.PrimerSignerWithGames = TGNS.HasClientSignedPrimerWithGames(c)
					    		playerData.Stranger = TGNS.IsClientStranger(c)
					    		playerData.WeldGave = TGNS.GetNumericValueOrZero(currentGame["WeldHealth"][c])
					    		playerData.HealSprayGave = TGNS.GetNumericValueOrZero(currentGame["HealSpray"][c])
					    		playerData.HarvestersKilled = TGNS.GetNumericValueOrZero(currentGame["HarvestersKilled"][c])
					    		playerData.ExtractorsKilled = TGNS.GetNumericValueOrZero(currentGame["ExtractorsKilled"][c])
					    		playerData.ParasitesInjested = TGNS.GetNumericValueOrZero(currentGame["ParasitesInjested"][c])
					    		playerData.ParasitesLanded = TGNS.GetNumericValueOrZero(currentGame["ParasitesLanded"][c])

					    		currentGame["ClassDurations"][c] = currentGame["ClassDurations"][c] or {}
					    		TGNS.DoFor(trackedClassData, function(d)
					    			playerData[d.PlayerDataPropertyName] = currentGame["ClassDurations"][c][d.TechId] or 0
					    		end)

					    		playerData.GorgeSeconds = currentGame["ClassDurations"][c][kTechId.Gorge] or 0
					    		playerData.LerkSeconds = currentGame["ClassDurations"][c][kTechId.Lerk] or 0
					    		playerData.FadeSeconds = currentGame["ClassDurations"][c][kTechId.Fade] or 0
					    		playerData.OnosSeconds = currentGame["ClassDurations"][c][kTechId.Onos] or 0

					    		playerData.StructuresBuilt = 0
					    		playerData.HarvestersBuilt = 0
					    		playerData.ExtractorsBuilt = 0
					    		TGNS.DoForPairs(currentGame["classBuildCompleteCounts"][c], function(className, count)
					    			playerData.StructuresBuilt = playerData.StructuresBuilt + 1
					    			if className == "Harvester" then
					    				playerData.HarvestersBuilt = playerData.HarvestersBuilt + 1
					    			elseif className == "Extractor" then
					    				playerData.ExtractorsBuilt = playerData.ExtractorsBuilt + 1
					    			end

					    		end)
					    		playerData.IPV4 = IPAddressToString(Server.GetClientAddress(c))

					    		audit(718, playerData, function(playerDataAuditResponseJson)
					    			local playerDataAuditResponse = json.decode(playerDataAuditResponseJson) or {}
					    			if playerDataAuditResponse.success then
					    				if gameData.TotalPlayerCount >= 8 then
						    				if playerData.CommanderSeconds > (gameData.DurationInSeconds / 2) and not gameData.IncludedBots then
						    					TGNS.Karma(playerData.PlayerId, "Commanding")
						    				end
						    				if playerData.Captain then
						    					TGNS.Karma(playerData.PlayerId, "BeingCaptain")
						    				end
					    				end
					    			else
					    				TGNS.DebugPrint(string.format("audit ERROR: Unable to audit playerData. msg: %s | stacktrace: %s", playerDataAuditResponse.msg, playerDataAuditResponse.stacktrace))
					    				TGNS.PrintTable(playerData, "playerData", function(x) TGNS.DebugPrint(x) end)
					    			end
					    		end)
		    				end
		    			end)
		    		end
		    	end)
			else
				TGNS.DebugPrint(string.format("audit ERROR: Unable to audit gameData. msg: %s | stacktrace: %s", gameDataAuditResponse.msg, gameDataAuditResponse.stacktrace), false, "audit")
				TGNS.PrintTable(gameData, "gameData", function(x) TGNS.DebugPrint(x) end)
			end
		end)
    end, TGNS.HIGHEST_EVENT_HANDLER_PRIORITY)

	local originalAddContinuousScore
	originalAddContinuousScore = TGNS.ReplaceClassMethod("ScoringMixin", "AddContinuousScore", function(self, name, addAmount, amountNeededToScore, pointsGivenOnScore)
		originalAddContinuousScore(self, name, addAmount, amountNeededToScore, pointsGivenOnScore)
		local client = TGNS.GetClient(self)
		if client then
			currentGame[name][client] = TGNS.GetNumericValueOrZero(currentGame[name][client]) + addAmount
		end
	end)

	local originalParasiteMixinSetParasited = ParasiteMixin.SetParasited
	ParasiteMixin.SetParasited = function(parasiteMixinSelf, fromPlayer, durationOverride)
		local wasParasited = parasiteMixinSelf.parasited
		originalParasiteMixinSetParasited(parasiteMixinSelf, fromPlayer, durationOverride)
		if (durationOverride or kParasiteDuration) == kParasiteDuration and not wasParasited then
			local victimClient = TGNS.GetClient(parasiteMixinSelf)
			if victimClient then
				currentGame["ParasitesInjested"][victimClient] = currentGame["ParasitesInjested"][victimClient] or 0
				currentGame["ParasitesInjested"][victimClient] = currentGame["ParasitesInjested"][victimClient] + 1
			end
			local fromClient = TGNS.GetClient(fromPlayer)
			if fromClient then
				currentGame["ParasitesLanded"][fromClient] = currentGame["ParasitesLanded"][fromClient] or 0
				currentGame["ParasitesLanded"][fromClient] = currentGame["ParasitesLanded"][fromClient] + 1
			end
		end
	end

	local originalEmbryoSetGestationData = Embryo.SetGestationData
	Embryo.SetGestationData = function(embryoSelf, techIds, previousTechId, healthScalar, armorScalar)
		originalEmbryoSetGestationData(embryoSelf, techIds, previousTechId, healthScalar, armorScalar)
		local client = TGNS.GetClient(embryoSelf)
		addClientClassDuration(client)
		local trackedClass = TGNS.FirstOrNil(trackedClassData, function(d) return TGNS.Has(techIds, d.TechId) end)
		if trackedClass then
			lastGestationData[client] = {when=Shared.GetTime(),what=trackedClass}
		end
	end

	local originalPlayerOnKill = Player.OnKill
	Player.OnKill = function(playerSelf, killer, doer, point, direction)
		originalPlayerOnKill(playerSelf, killer, doer, point, direction)
		local client = TGNS.GetClient(playerSelf)
		addClientClassDuration(client)
	end

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("audit", Plugin )