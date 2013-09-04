TGNS = TGNS or {}
local scheduledActions = {}
local scheduledActionsErrorCount = 0

local CHAT_MESSAGE_SENDER = "Admin"

function TGNS.GetVoteableMapNames()
	local result = {}
	local mapCycleMapNames = TGNS.GetMapCycleMapNames()
	if Shine.Plugins.mapvote and Shine.Plugins.mapvote.Enabled and not Shine.Plugins.mapvote.Config.GetMapsFromMapCycle then
		TGNS.DoForPairs(Shine.Plugins.mapvote.Config.Maps, function(mapName, enabled)
			if TGNS.Has(mapCycleMapNames, mapName) and enabled then
				table.insert(result, mapName)
			end
		end)
	else
		result = mapCycleMapNames
	end
	TGNS.SortAscending(result)
	return result
end

function TGNS.GetMapCycleMapNames()
	local result = {}
	local mapCycle = (MapCycle_GetMapCycle and MapCycle_GetMapCycle()) or TGNSJsonFileTranscoder.DecodeFromFile("config://MapCycle.json")
	TGNS.DoFor(mapCycle.maps, function(m, i)
		local mapName = type(m) == "table" and m.map or m
		table.insert(result, mapName)
	end)
	TGNS.SortAscending(result)
	return result
end

function TGNS.GetPlayerId(player)
	local result = player:GetId()
	return result
end

function TGNS.GetPlayerGameId(player)
	local client = TGNS.GetClient(player)
	local result = Shine.GameIDs[client]
	return result
end

function TGNS.SendNetworkMessageToPlayer(player, messageName, variables)
	variables = variables or {}
	Server.SendNetworkMessage(player, messageName, variables, true)
end

function TGNS.GetPlayerById(id)
	local result = TGNS.GetFirst(TGNS.Where(TGNS.GetPlayerList(), function(p) return p:GetId() == id end))
	return result
end

function TGNS.ExecuteClientCommand(client, command)
	Server.ClientCommand(TGNS.GetPlayer(client), command)
end

function TGNS.ExecuteServerCommand(command)
	Shared.ConsoleCommand(command)
end

function TGNS.StructureIsBuilt(structure)
	local result = structure:GetIsBuilt()
	return result
end

function TGNS.StructureIsAlive(structure)
	local result = structure:GetIsAlive()
	return result
end

function TGNS.CommandStructureIsBuiltAndAlive(commandStructure)
	local result = TGNS.StructureIsBuilt(commandStructure) and TGNS.StructureIsAlive(commandStructure)
	return result
end

function TGNS.GetNumberOfWorkingInfantryPortals(commandStation)
	local infantryPortalsWithinRangeOfTheCommandStation = GetEntitiesForTeamWithinRange("InfantryPortal", kMarineTeamType, commandStation:GetOrigin(), 15)
	local builtAndPoweredInfantryPortalsWithinRangeOfTheCommandStation = TGNS.Where(infantryPortalsWithinRangeOfTheCommandStation, function(p) return p:GetIsBuilt() and p:GetIsPowered() end)
	local result = #builtAndPoweredInfantryPortalsWithinRangeOfTheCommandStation
	return result
end

function TGNS.CommandStructureHasCommander(commandStructure)
	local result = commandStructure:GetCommander() ~= nil
	return result
end

function TGNS.Ban(client, targetClient, durationInMinutes, reason)
	local targetSteamId = TGNS.GetClientSteamId(targetClient)
	local targetName = TGNS.GetClientName(client)
	local bannedBy = TGNS.GetClientNameSteamIdCombo(client)
	Shine.Plugins.ban:AddBan(targetSteamId, targetName, durationInMinutes * 60, bannedBy, reason)
end

function TGNS.IsPlayerAlive(player)
	local result = player:GetIsAlive()
	return result
end

function TGNS.IsNumberWithNonZeroPositiveValue(candidate)
	local result = type(candidate) == "number" and candidate > 0
	return result
end

function TGNS.InsertDistinctly(elements, element)
	if not TGNS.Has(elements, element) then
		table.insert(elements, element)
	end
end

function TGNS.PlayerTeamIsOverbalanced(player, playerList)
	local result
	TGNS.DoTeamSizeComparisonAction(player, playerList, function(playerTeamCount, otherTeamCount)
		result = playerTeamCount >= otherTeamCount + 2
	end)
	return result
end

function TGNS.DoTeamSizeComparisonAction(player, playerList, action)
	local playerTeamCount = #TGNS.GetTeamClients(TGNS.GetPlayerTeamNumber(player), playerList)
	local otherTeamCount = #TGNS.GetPlayersOnOtherPlayingTeam(player, playerList)
	action(playerTeamCount, otherTeamCount)
end

function TGNS.GetOtherPlayingTeamNumber(playingTeamNumber)
	assert(TGNS.IsGameplayTeam(playingTeamNumber), "Input team number is not a playing team number.")
	local result = playingTeamNumber == kMarineTeamType and kAlienTeamType or kMarineTeamType
	return result
end

function TGNS.GetPlayersOnOtherPlayingTeam(player, playerList)
	local playerTeamNumber = TGNS.GetPlayerTeamNumber(player)
	local otherTeamNumber = TGNS.GetOtherPlayingTeamNumber(playerTeamNumber)
	local result = TGNS.GetPlayers(TGNS.GetTeamClients(otherTeamNumber, playerList))
	return result
end

function TGNS.Select(elements, projector)
	local result = {}
	TGNS.DoFor(elements, function(e)
		table.insert(result, projector(e))
	end)
	return result
end

function TGNS.GetPlayerScorePerMinute(player)
	local result
	local gameDurationInSeconds = TGNS.GetCurrentGameDurationInSeconds()
	if gameDurationInSeconds ~= nil then
		local playerScore = TGNS.GetPlayerScore(player)
		local gameDurationInMinutes = TGNS.ConvertSecondsToMinutes(gameDurationInSeconds)
		result = TGNSAverageCalculator.Calculate(playerScore, gameDurationInMinutes)
	end
	return result
end

function TGNS.GetCurrentGameDurationInSeconds()
	local result
	local gameStartTime = GetGamerules():GetGameStartTime()
	if gameStartTime > 0 then
		result = Shared.GetTime() - gameStartTime
	end
	return result
end

function TGNS.GetPlayerScore(player)
	local result = player:GetScore()
	return result
end

function TGNS.GetSimpleServerName()
	local tacticalGamerServerNamePrefix = "TacticalGamer.com - "
	local result = Server.GetName()
	if TGNS.Contains(result, tacticalGamerServerNamePrefix) then
		result = TGNS.Substring(result, string.len(tacticalGamerServerNamePrefix) + 1)
	end
	local indexOfFirstSpaceCharacter = string.find(result, "%s")
	if indexOfFirstSpaceCharacter then
		result = TGNS.Substring(result, 1, indexOfFirstSpaceCharacter - 1)
	end
	return result
end

function TGNS.ReplaceClassMethod(className, methodName, method)
	return Shine.ReplaceClassMethod(className, methodName, method)
end

function TGNS.Replace(original, pattern, replace)
	local result = string.gsub(original, pattern, replace)
	return result
end

function TGNS.GetNextMapName()
	local result = MapCycle_GetNextMapInCycle().map
	return result
end

function TGNS.Substring(s, startIndex, length)
	local endIndex = length ~= nil and startIndex + length - 1 or nil
	local result = string.sub(s, startIndex, endIndex)
	return result
end

function TGNS.Truncate(s, length)
	local result = TGNS.Substring(s, 1, length)
	return result
end

function TGNS.ToLower(s)
	local result = string.lower(s)
	return result
end

function TGNS.ConvertSecondsToMinutes(seconds)
	local result = seconds / 60
	return result
end

function TGNS.ConvertMinutesToSeconds(minutes)
	local result = minutes * 60
	return result
end

function TGNS.SwitchToMap(mapName)
	MapCycle_ChangeMap(mapName)
end

function TGNS.GetClientList(predicate)
	local result = TGNS.GetClients(TGNS.GetPlayerList())
	if predicate ~= nil then
		result = TGNS.Where(result, predicate)
	end
	return result
end

function TGNS.GetPlayerTotalCost(player)
	local result = TGNS.GetPlayerClassPurchaseCost(player) + TGNS.GetMarineWeaponsTotalPurchaseCost(player) + TGNS.GetPlayerResources(player)
	return result
end

function TGNS.SecondsToClock(sSeconds)
	local result = "00:00:00"
	local nSeconds = tonumber(sSeconds)
	if nSeconds ~= 0 then
		nHours = string.format("%02.f", math.floor(nSeconds/3600));
		nMins = string.format("%02.f", math.floor(nSeconds/60 - (nHours*60)));
		nSecs = string.format("%02.f", math.floor(nSeconds - nHours*3600 - nMins *60));
		result = nHours..":"..nMins..":"..nSecs
	end
	return result
end

function TGNS.KillPlayer(player)
	player:Kill(nil, nil, player:GetOrigin())
end

function TGNS.GetPlayerClassName(player)
	local result = player:GetClassName()
	return result
end

function TGNS.GetMarineWeaponsTotalPurchaseCost(player)
	local marineWeaponPurchaseCosts = {
      [Welder.kMapName] = kWelderCost,
      [LayMines.kMapName] = kMineCost,
      [Shotgun.kMapName] = kShotgunCost,
      [GrenadeLauncher.kMapName] = kGrenadeLauncherCost,
      [Flamethrower.kMapName] = kFlamethrowerCost
    }
	local result = 0
	TGNS.DoForPairs(marineWeaponPurchaseCosts, function(key,value)
		if player:GetWeapon(key) then
			result = result + value
		end
	end)
	return result
end

function TGNS.GetPlayerClassPurchaseCost(player)
	local playerClassNamePurchaseCosts = {
      ["JetpackMarine"] = kJetpackCost,
      ["Onos"] = kOnosCost,
      ["Fade"] = kFadeCost,
      ["Lerk"] = kLerkCost,
      ["Gorge"] = kGorgeCost
    }
	local exoLayoutNamePurchaseCosts = {
      ["ClawMinigun"] = kExosuitCost,
      ["ClawRailgun"] = kClawRailgunExosuitCost,
      ["MinigunMinigun"] = kDualExosuitCost
    }
	local playerClassNameResCost
	if (player.layout) then
		playerClassNameResCost = exoLayoutNamePurchaseCosts[player.layout]
	else
		playerClassNameResCost = playerClassNamePurchaseCosts[TGNS.GetPlayerClassName(player)]
	end
	local result = playerClassNameResCost ~= nil and playerClassNameResCost or 0
	return result
end

function TGNS.IsGameInCountdown()
	local result = TGNS.GetGameState() == kGameState.Countdown
	return result
end

function TGNS.IsGameInProgress()
	local result = TGNS.GetGameState() == kGameState.Started
	return result
end

function TGNS.RoundPositiveNumber(num, numberOfDecimalPlaces)
	local mult = 10^(numberOfDecimalPlaces or 0)
	local result = math.floor(num * mult + 0.5) / mult
	return result
end

function TGNS.GetPlayerResources(player)
	local result = player:GetResources()
	return result
end

function TGNS.SetPlayerResources(player, value)
	player:SetResources(value)
end

function TGNS.RemoveAllMatching(elements, element)
	TGNS.DoForReverse(elements, function(e, index)
		if element == e then
			table.remove(elements, index)
		end
	end)
end

function TGNS.DestroyEntity(entity)
	DestroyEntity(entity)
end

function TGNS.DestroyEntitiesExcept(entities, entityToKeep)
	TGNS.DoFor(entities, function (e)
		if e ~= entityToKeep then
			TGNS.DestroyEntity(e)
		end
	end)
end

function TGNS.KillTeamEntitiesExcept(className, teamNumber, entityToKeep)
	local entities = TGNS.GetEntitiesForTeam(className, teamNumber)
	TGNS.DestroyEntitiesExcept(entities, entityToKeep)
end

function TGNS.GetEntitiesForTeam(className, teamNumber)
	local result = GetEntitiesForTeam(className, teamNumber)
	return result
end

function TGNS.EntityIsCommandStructure(entity)
	local result = false
	if entity ~= nil then
		local entityClassName = entity:GetClassName()
		result = entityClassName == "CommandStation" or entityClassName == "Hive"
	end
	return result
end

function TGNS.DestroyAllEntities(className, teamNumber)
	local entities = TGNS.GetEntitiesForTeam(className, teamNumber)
	TGNS.DoFor(entities, function(e) TGNS.DestroyEntity(e) end)
end

function TGNS.IsTournamentMode()
	local result = DAK:GetTournamentMode()
	return result
end

function TGNS.AddTempGroup(client, groupName)
	Shine:AddTempGroup(client, groupName)
end

function TGNS.RemoveTempGroup(client, groupName)
	Shine:RemoveTempGroup(client, groupName)
end

function TGNS.ClientIsInGroup(client, groupName)
	local result = Shine:IsInGroup(client, groupName)
	return result
end

function TGNS.IsPlayerAFK(player)
	local result = false
	local AFKKick = Shine.Plugins.afkkick
	local AFKEnabled = AFKKick and AFKKick.Enabled
	if AFKEnabled then
		local LastMove = TGNS.ClientAction(player, function(c) AFKKick:GetLastMoveTime(c) end)
		result = LastMove and Shared.GetTime() - LastMove > 30
	end
	return result
end

function TGNS.IsPluginEnabled(pluginName)
	local result = Shine.Plugins[pluginName] and Shine.Plugins[pluginName].Enabled
	return result
end

function TGNS.ClientCanRunCommand(client, command)
	local result = Shine:GetPermission(client, command)
	return result
end

function TGNS.IsInGroup(client, groupName)
	local result = Shine:IsInGroup(client, groupName)
	return result
end

function TGNS.GetConcatenatedStringOrEmpty(...)
	local result = ""
	local concatenation = StringConcatArgs(...)
	if concatenation then
		result = concatenation
	end
	return result
end

function TGNS.PlayerIsRookie(player)
	local result = player:GetIsRookie()
	return result
end

function TGNS.GetClientCommunityDesignationCharacter(client)
	local result
	if TGNS.IsClientSM(client) then
		result = "S"
	elseif TGNS.IsPrimerOnlyClient(client) then
		result = "P"
	else
		result = "?"
	end
	return result
end

function TGNS.Contains(s, part)
	return s:find(part)
end

function TGNS.StartsWith(s,part)
   return string.sub(s,1,string.len(part))==part
end

function TGNS.EndsWith(s, part)
	return #s >= #part and s:find(part, #s-#part+1, true) and true or false
end

function TGNS.RespawnPlayer(player)
	GetGamerules():RespawnPlayer(player)
end

function TGNS.SendToRandomTeam(player)
	local playerList = TGNS.GetPlayerList()
	local marinesCount = #TGNS.GetMarineClients(playerList)
	local aliensCount = #TGNS.GetAlienClients(playerList)
	local teamNumber
	if marinesCount == aliensCount then
		teamNumber = math.random(1,2)
	else
		teamNumber = marinesCount < aliensCount and 1 or 2
	end
	TGNS.SendToTeam(player, teamNumber)
end

function TGNS.ForcePlayersToReadyRoom(players)
	TGNS.DoFor(players, function(p) TGNS.SendToTeam(p, kTeamReadyRoom, true) end)
end

function TGNS.SendToTeam(player, teamNumber, force)
	GetGamerules():JoinTeam(player, teamNumber, force)
end

function TGNS.Join(list, delimiter)
	local result = ""
	TGNS.DoFor(list, function(item, index)
		result = string.format("%s%s%s", result, index > 1 and delimiter or "", item)
	end)
	return result
end

function TGNS.GetPlayerTeamName(player)
	local result = TGNS.GetTeamName(TGNS.GetPlayerTeamNumber(player))
	return result
end

function TGNS.GetTeam(player)
	local result = player:GetTeam()
	return result
end

function TGNS.GetPlayerTeamNumber(player)
	local playerTeam = player:GetTeam()
	local result = playerTeam:GetTeamNumber()
	return result
end

function TGNS.GetPlayersOnSameTeam(player)
	local result = TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.GetPlayerTeamNumber(player) == TGNS.GetPlayerTeamNumber(p) end)
	return result
end

function TGNS.PlayersAreTeammates(player1, player2)
	local result = TGNS.GetPlayerTeamNumber(player1) == TGNS.GetPlayerTeamNumber(player2)
	return result
end

function TGNS.TableValueCount(tt, item)
	local result = 0
	TGNS.DoForPairs(tt, function(key, value)
		if item == value then
			result = result + 1
		end
	end)
	return result
end

function TGNS.TableUnique(tt)
	local result = {}
	TGNS.DoForPairs(tt, function(key, value)
		if TGNS.TableValueCount(result, value) == 0 then
			result[#result+1] = value
		end
	end)
	return result
end

function TGNS.ScheduleActionInterval(intervalInSeconds, action)
	TGNS.ScheduleAction(intervalInSeconds, action)
	TGNS.ScheduleAction(intervalInSeconds, function() TGNS.ScheduleActionInterval(intervalInSeconds, action) end)
end

function TGNS.ScheduleAction(delayInSeconds, action)
	local scheduledAction = {}
	scheduledAction.when = Shared.GetTime() + delayInSeconds
	scheduledAction.what = action
	table.insert(scheduledActions, scheduledAction)
end

local function ProcessScheduledActions()
	TGNS.DoForReverse(scheduledActions, function(scheduledAction, index)
		if scheduledAction.when < Shared.GetTime() then
			local success, result = xpcall(scheduledAction.what, debug.traceback)
			if success then
				table.remove(scheduledActions, index)
			else
				scheduledActionsErrorCount = scheduledActionsErrorCount + 1
				if scheduledActionsErrorCount < 1 then
					local errorMessage = string.format("ScheduledAction Error (%s, %s): %s", scheduledActionsErrorCount, Shared.GetTime(), result)
					Shared.Message(errorMessage)
					TGNS.EnhancedLog(errorMessage)
				else
					table.remove(scheduledActions, index)
				end
			end
		end
	end)
end

local function CommonOnServerUpdate(deltatime)
	ProcessScheduledActions()
end
TGNS.RegisterEventHook("Think", CommonOnServerUpdate)

function TGNS.PlayerIsOnTeam(player, team)
	local result = player:GetTeam() == team
	return result
end

function TGNS.GetGameState()
	local result = GetGamerules():GetGameState()
	return result
end

function TGNS.IsGameStartingState(gameState)
	local result = gameState == kGameState.Started
	return result
end

function TGNS.IsGameInPreGame()
	local result = TGNS.GetGameState() == kGameState.PreGame
	return result
end

function TGNS.IsGameWinningState(gameState)
	local result = gameState == kGameState.Team1Won or gameState == kGameState.Team2Won
	return result
end

function TGNS.IsGameplayTeam(teamNumber)
	local result = teamNumber == kMarineTeamType or teamNumber == kAlienTeamType
	return result
end

function TGNS.GetTeamName(teamNumber)
	local result
	if teamNumber == kTeamReadyRoom then
		result = "Ready Room"
	elseif teamNumber == kMarineTeamType then
		result = "Marines"
	elseif teamNumber == kAlienTeamType then
		result = "Aliens"
	elseif teamNumber == kSpectatorIndex then
		result = "Spectator"
	end
	return result
end

function TGNS.IsPlayerReadyRoom(player)
	local result = player:GetTeamNumber() == kTeamReadyRoom
	return result
end

function TGNS.IsTeamNumberSpectator(teamNumber)
	local result = teamNumber == kSpectatorIndex
	return result
end

function TGNS.IsPlayerSpectator(player)
	local result = player:isa("Spectator") and TGNS.IsTeamNumberSpectator(player:GetTeamNumber())
	return result
end

function TGNS.GetNumericValueOrZero(countable)
	local result = countable == nil and 0 or countable
	return result
end

function TGNS.IsClientCommander(client)
	local result = false
	if client ~= nil then
		local player = client:GetControllingPlayer()
		if player ~= nil then
			result = player:GetIsCommander()
		end
	end
	return result	
end

function TGNS.IsClientGuardian(client)
	local result = false
	if client ~= nil then
		result = not TGNS.IsClientAdmin(client) and TGNS.IsInGroup(client, "guardian_group")
	end
	return result
end

function TGNS.IsClientTempAdmin(client)
	local result = false
	if client ~= nil then
		local clientIsAdmin = TGNS.IsClientAdmin(client)
		local clientIsTempAdmin = TGNS.IsInGroup(client, "tempadmin_group")
		result = not clientIsAdmin and clientIsTempAdmin
	end
	return result
end

function TGNS.HasSteamIdSignedPrimer(steamId)
	local result = Shine.Plugins.permissions:IsSteamIdInGroup(steamId, "primer_group")
	return result
end

function TGNS.HasClientSignedPrimer(client)
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.HasSteamIdSignedPrimer(steamId)
	end
	return result
end

function TGNS.IsSteamIdAdmin(steamId)
	local result = Shine.Plugins.permissions:IsSteamIdInGroup(steamId, "admin_group")
	return result
end

function TGNS.IsClientAdmin(client)
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdAdmin(steamId)
	end
	return result
end

function TGNS.IsSteamIdSM(steamId)
	local result = Shine.Plugins.permissions:IsSteamIdInGroup(steamId, "sm_group")
	return result
end

function TGNS.IsClientSM(client)
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdSM(steamId)
	end
	return result
end

function TGNS.IsSteamIdStranger(steamId)
	local result = not TGNS.IsSteamIdSM(steamId) and not TGNS.HasSteamIdSignedPrimer(steamId)
	return result
end

function TGNS.IsClientStranger(client)
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdStranger(steamId)
	end
	return result
end

function TGNS.IsSteamIdPrimerOnly(steamId)
	local result = TGNS.HasSteamIdSignedPrimer(steamId) and not TGNS.IsSteamIdSM(steamId)
	return result
end

function TGNS.IsPrimerOnlyClient(client)
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdPrimerOnly(steamId)
	end
	return result
end

function TGNS.PlayerAction(client, action)
	local player = client:GetControllingPlayer()
	return action(player)
end

function TGNS.GetPlayerName(player)
	return player:GetName()
end

function TGNS.GetClientName(client)
	local result = TGNS.PlayerAction(client, TGNS.GetPlayerName)
	return result
end

function TGNS.ClientAction(player, action)
	local client = Server.GetOwner(player)
	if client then
		return action(client)
	end
end

function TGNS.GetClientSteamId(client)
	result = client:GetUserId()
	return result
end

function TGNS.DoForClientsWithId(clients, clientAction)
	TGNS.DoFor(clients, function(c)
		local steamId = TGNS.GetClientSteamId(c)
		if steamId ~= nil then
			clientAction(c, steamId)
		end
	end)
end

function TGNS.GetClientNameSteamIdCombo(client)
	local result = string.format("%s (%s)", TGNS.GetClientName(client), TGNS.GetClientSteamId(client))
	return result	
end

function TGNS.GetIsClientVirtual(client)
	local result = client:GetIsVirtual()
	return result
end

function TGNS.DisconnectClient(client, reason)
	pcall(function()
		client.disconnectreason = reason
		Server.DisconnectClient(client)
	end)
end

function TGNS.RemoveAll(elements)
	TGNS.DoForReverse(elements, function(e, index)
		table.remove(elements, index)
	end)
end

function TGNS.TableReverse(elements)
	local temp = {}
	TGNS.DoFor(elements, function(e) table.insert(temp, e) end)
	TGNS.RemoveAll(elements)
	TGNS.DoForReverse(temp, function(e) table.insert(elements, e) end)
end

function TGNS.SortDescending(elements, sortFunction)
	TGNS.SortAscending(elements, sortFunction)
	TGNS.TableReverse(elements)
end

function TGNS.SortAscending(elements, sortFunction)
	sortFunction = sortFunction or function(x) return x end
	table.sort(elements, function(e1, e2)
		return sortFunction(e1) < sortFunction(e2)
	end)
end

function TGNS.GetLast(elements)
	local result = elements[#elements]
	return result
end

function TGNS.GetFirst(elements)
	local result = elements[1]
	return result
end

function TGNS.ElementIsFoundBeforeIndex(elements, element, index)
	local result = false
	TGNS.DoFor(elements, function(e, i)
		if i <= index and e == element then
			result = true
			return true
		end
	end)
	return result
end

function TGNS.GetPlayerList()
	local result = Shine.GetAllPlayers()
	TGNS.SortAscending(result, function(p) return p == nil and "" or string.lower(TGNS.GetPlayerName(p)) end)
	return result
end

function TGNS.GetPlayerCount() 
	local result = #TGNS.GetPlayerList()
	return result
end

function TGNS.AllPlayers(doThis)
	return function(client)
		local playerList = TGNS.GetPlayerList()
		TGNS.DoFor(playerList, function(p, index)
			doThis(p, client, index)
		end)
	end
end

function TGNS.Has(elements, element)
	local result = TGNS.Any(elements, function(e) return element == e end)
	return result
end

function TGNS.GetClient(player)
	local result = Server.GetOwner(player)
	return result
end

function TGNS.GetPlayer(client)
	local result = client:GetControllingPlayer()
	return result
end

function TGNS.GetPlayers(clients)
	local result = {}
	TGNS.DoFor(clients, function(c) table.insert(result, TGNS.GetPlayer(c)) end)
	return result
end

function TGNS.GetClients(players)
	local result = {}
	TGNS.DoFor(players, function(p) table.insert(result, TGNS.GetClient(p)) end)
	return result
end

function TGNS.GetMatchingClients(playerList, predicate)
	local result = {}
	playerList = playerList == nil and TGNS.GetPlayerList() or playerList
	TGNS.DoForReverse(playerList, function(p)
		local c = TGNS.GetClient(p)
		if c ~= nil then
			if predicate(c,p) then
				table.insert(result, c)
			end
		end
	end)
	return result
end

function TGNS.PlayerIsOnPlayingTeam(player)
	local result = TGNS.IsGameplayTeam(TGNS.GetPlayerTeamNumber(player))
	return result
end

function TGNS.GetPlayingClients(playerList)
	local result = TGNS.GetMatchingClients(playerList, function(c,p) return TGNS.PlayerIsOnPlayingTeam(p) end)
	return result
end

function TGNS.GetLastMatchingClient(playerList, predicate)
	local result = nil
	local playerList = playerList == nil and TGNS.GetPlayerList() or playerList
	TGNS.DoFor(playerList, function(p)
		local c = TGNS.GetClient(p)
		if c ~= nil then
			if predicate(c, p) then
				result = c
			end
		end
	end)
	return result
end

function TGNS.UpdateScoreboard(player)
	player:SetScoreboardChanged(true)
end

function TGNS.UpdateAllScoreboards()
	TGNS.DoFor(TGNS.GetPlayerList(), TGNS.UpdateScoreboard)
end

function TGNS.GetTeamClients(teamNumber, playerList)
	local predicate = function(client, player) return player:GetTeamNumber() == teamNumber end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetSpectatorClients(playerList)
	local predicate = function(client, player) return TGNS.IsPlayerSpectator(player) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetMarineClients(playerList)
	local result = TGNS.GetTeamClients(kMarineTeamType, playerList)
	return result
end

function TGNS.GetReadyRoomClients(playerList)
	local result = TGNS.GetTeamClients(kTeamReadyRoom, playerList)
	return result
end

function TGNS.GetAlienClients(playerList)
	local result = TGNS.GetTeamClients(kAlienTeamType, playerList)
	return result
end

function TGNS.GetReadyRoomPlayers(playerList)
	local result = TGNS.GetPlayers(TGNS.GetReadyRoomClients(playerList))
	return result
end

function TGNS.GetMarinePlayers(playerList)
	local result = TGNS.GetPlayers(TGNS.GetMarineClients(playerList))
	return result
end

function TGNS.GetAlienPlayers(playerList)
	local result = TGNS.GetPlayers(TGNS.GetAlienClients(playerList))
	return result
end

function TGNS.GetStrangersClients(playerList)
	local predicate = function(client, player) return TGNS.IsClientStranger(client) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetPrimerOnlyClients(playerList)
	local predicate = function(client, player) return TGNS.IsPrimerOnlyClient(client) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetSmClients(playerList)
	local predicate = function(client, player) return TGNS.IsClientSM(client) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetSumUpTo(operand1, operand2, sumLimit)
	local sum = operand1 + operand2
	local result = sum <= sumLimit and sum or sumLimit
	return result
end

function TGNS.KickPlayer(player, disconnectReason, onPreKick)
	if player ~= nil then
		TGNS.KickClient(player:GetClient(), disconnectReason, onPreKick)
	end
end

function TGNS.StringEqualsCaseInsensitive(s1, s2)
	local result = string.lower(s1) == string.lower(s2)
	return result
end

function TGNS.GetPlayerMatchingName(name, team)

	assert(type(name) == "string")
	
	local nameMatchCount = 0
	local match = nil
	
	local function Matches(player)
		if nameMatchCount == -1 then
			return // exact match found, skip others to avoid further partial matches
		end
		local playerName =  player:GetName()
		if player:GetName() == name then // exact match
			if team == nil or team == -1 or team == player:GetTeamNumber() then
				match = player
				nameMatchCount = -1
			end
		else
			local index = string.find(string.lower(playerName), string.lower(name)) // case insensitive partial match
			if index ~= nil then
				if team == nil or team == -1 or team == player:GetTeamNumber() then
					match = player
					nameMatchCount = nameMatchCount + 1
				end
			end
		end
		
	end
	TGNS.AllPlayers(Matches)()
	
	if nameMatchCount > 1 then
		match = nil // if partial match is not unique, clear the match
	end
	
	return match

end

function TGNS.GetPlayerMatchingSteamId(steamId, team)

	assert(type(steamId) == "number")
	
	local match = nil
	
	local function Matches(player)
	
		local playerClient = Server.GetOwner(player)
		if playerClient and playerClient:GetUserId() == steamId then
			if team == nil or team == -1 or team == player:GetTeamNumber() then
				match = player
			end
		end
		
	end
	TGNS.AllPlayers(Matches)()
	
	return match

end

function TGNS.GetPlayerByGameId(id, teamNumber)
	Shared.Message("TGNS.GetPlayerByGameId id: " .. id)
	local result
	local client = Shine.GetClientByID(id)
	if client then
		local player = TGNS.GetPlayer(client)
		if teamNumber == nil or TGNS.GetPlayerTeamNumber(player) == teamNumber then
			Shared.Message("TGNS.GetPlayerByGameId returning " .. TGNS.GetPlayerName(player))
			result = player
		end
	end
	return result
end

function TGNS.GetPlayerMatching(id, team)
	local idNum = tonumber(id)
	if idNum then
		local gameIdPlayer = TGNS.GetPlayerByGameId(idNum, team)
		local steamIdPlayer = TGNS.GetPlayerMatchingSteamId(idNum, team)
		return gameIdPlayer or steamIdPlayer
	elseif type(id) == "string" then
		return TGNS.GetPlayerMatchingName(id, team)
	end
end

////////////////////////////////
// Intercept Network Messages //
////////////////////////////////

kTGNSNetworkMessageHooks = {}

function TGNS.RegisterNetworkMessageHook(messageName, func, priority)
	local eventName = "kTGNSOn" .. messageName
	TGNS.RegisterEventHook(eventName , func, priority)
end

local originalOnNetworkMessage = {}

local function onNetworkMessage(messageName, ...)
	local eventName = "kTGNSOn" .. messageName
	if not Shine.Hook.Call(eventName, ... ) then
		originalOnNetworkMessage[messageName](...)
	end
end

local originalHookNetworkMessage = Server.HookNetworkMessage

Server.HookNetworkMessage = function(messageName, callback)

	//Print("TGNS Hooking: %s", messageName)
	originalOnNetworkMessage[messageName] = callback
	callback = function(...) onNetworkMessage(messageName, ...) end
	kTGNSNetworkMessageHooks[messageName] = callback

	originalHookNetworkMessage(messageName, callback)

end