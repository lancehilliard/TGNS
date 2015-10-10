local EMPTY_VALUE = "NULL"
local currentGame

local function initCurrentGameObject()
	currentGame = {}
	currentGame["classKillCounts"] = {}
	currentGame["classBuildCounts"] = {}
	currentGame["clients"] = {}
	currentGame["WeldHealth"] = {}
	currentGame["HealSpray"] = {}
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
	local originalOnConstruct = building.OnConstruct
	building.OnConstruct = function(self, builder, newFraction, oldFraction)
		if oldFraction == 0 and newFraction > 0 then
			local className = building:GetClassName()
			currentGame["classBuildCounts"][className] = TGNS.GetNumericValueOrZero(currentGame["classBuildCounts"][className]) + 1
		end
		if originalOnConstruct then
			originalOnConstruct(self, builder, newFraction, oldFraction)
		end
	end
end

function Plugin:OnEntityKilled(gamerules, victim, attacker, inflictor, point, dir)
	if attacker and inflictor and victim then
		local className = victim:GetClassName()
		if className == "Marine" then
			local primaryWeapon = victim.GetWeaponInHUDSlot and victim:GetWeaponInHUDSlot(1)
			if primaryWeapon then
				if primaryWeapon:isa("Shotgun") then
					className = "ShotgunMarine"
				elseif primaryWeapon:isa("Flamethrower") then
					className = "FlamethrowerMarine"
				elseif primaryWeapon:isa("GrenadeLauncher") then
					className = "GranadeLauncherMarine"
				end
			end
		elseif className == "Exo" then
			className = victim.layout
		end
		currentGame["classKillCounts"][className] = TGNS.GetNumericValueOrZero(currentGame["classKillCounts"][className]) + 1
	end
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	if TGNS.IsGameplayTeamNumber(newTeamNumber) then
		local client = TGNS.GetClient(player)
		if TGNS.GetIsClientVirtual(client) then
			currentGame["includedBots"] = true
		else
			table.insertunique(currentGame["clients"], client)
		end
	end
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
	end)
	TGNS.RegisterEventHook("WinOrLoseCalled", function(teamNumber)
		currentGame["surrenderTeamNumber"] = teamNumber
	end)
	TGNS.RegisterEventHook("WinOrLoseCountdownChanged", function(countdownValue)
		currentGame["winOrLoseEndGameCountdownValue"] = countdownValue
	end)
	TGNS.RegisterEventHook("FullGamePlayed", function(clients, winningTeam, gameDurationInSeconds)
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
		gameData.CaptainsMode = currentGame["isCaptainsMode"] == true
		gameData.SurrenderTeamNumber = currentGame["surrenderTeamNumber"] or EMPTY_VALUE
		gameData.WinOrLoseEndGameCountdownValue = currentGame["winOrLoseEndGameCountdownValue"] or EMPTY_VALUE
		gameData.MarineTeamResourcesTotal = gamerules.team1:GetTotalTeamResources()
		gameData.AlienTeamResourcesTotal = gamerules.team2:GetTotalTeamResources()
		gameData.MarineStartLocationName = gamerules.startingLocationNameTeam1
		gameData.AlienStartLocationName = gamerules.startingLocationNameTeam2
		gameData.StartingLocationsPathDistance = gamerules.startingLocationsPathDistance
		gameData.BuildNumber = Shared.GetBuildNumber()
		gameData.MapName = TGNS.GetCurrentMapName()
		gameData.IncludedBots = currentGame["includedBots"]

		audit(382, gameData, function(gameDataAuditResponseJson)
			local gameDataAuditResponse = json.decode(gameDataAuditResponseJson) or {}
			if gameDataAuditResponse.success then
		    	TGNS.DoFor(clients, function(c)
		    		if not TGNS.GetIsClientVirtual(c) then
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
				TGNS.DebugPrint(string.format("audit ERROR: Unable to audit gameData. msg: %s | stacktrace: %s", gameDataAuditResponse.msg, gameDataAuditResponse.stacktrace))
				TGNS.PrintTable(gameData, "gameData", function(x) TGNS.DebugPrint(x) end)
			end
		end)
    end)

	local originalAddContinuousScore
	originalAddContinuousScore = TGNS.ReplaceClassMethod("ScoringMixin", "AddContinuousScore", function(self, name, addAmount, amountNeededToScore, pointsGivenOnScore)
		originalAddContinuousScore(self, name, addAmount, amountNeededToScore, pointsGivenOnScore)
		local client = TGNS.GetClient(self)
		if client then
			currentGame[name][client] = TGNS.GetNumericValueOrZero(currentGame[name][client]) + addAmount
		end
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("audit", Plugin )