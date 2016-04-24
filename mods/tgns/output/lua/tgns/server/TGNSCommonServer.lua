TGNS = TGNS or {}
local scheduledActions = {}
local scheduledActionsErrorCounts = {}
local scheduledRequests = {}
local CHAT_MESSAGE_SENDER = "Admin"
local AFK_IDLE_THRESHOLD_SECONDS = 15
TGNS.ShouldProcessHttpRequests = false
local numberOfHttpRequestsMade = 0

Event.Hook("MapPostLoad", function()
	TGNS.ShouldProcessHttpRequests = true
end)

TGNS.Config = {}
TGNS.PRIMER_GAMES_THRESHOLD = 10
TGNS.LogHttp = false

-- beginnings of function GetLocationIdByName...
	-- 	TGNS.DoForPairs(GetLocations(), function(index, location)
	-- 		Shared.Message(string.format("%s: %s", index, location:GetName()))
	-- 	end)

function TGNS.GetEntityLocationName(entity) PROFILE("TGNS.GetEntityLocationName")
	local result = entity:GetLocationName()
	return result
end

function TGNS.GetTeamCommandStructures(teamNumber) PROFILE("TGNS.GetTeamCommandStructures")
	local result = TGNS.GetEntitiesForTeam("CommandStructure", teamNumber)
	return result
end

function TGNS.Karma(target, deltaName) PROFILE("TGNS.Karma")
	local result
	if target then
		local karmaPlugin = Shine.Plugins.karma
		if karmaPlugin and karmaPlugin.Enabled then
			if deltaName then
				karmaPlugin:AddKarma(target, deltaName)
			else
				result = karmaPlugin:GetKarma(target)
			end
		end
	end
	return result or 0
end

function TGNS.GetStopWatchTime(seconds) PROFILE("TGNS.GetStopWatchTime")
	local integralSeconds, fractionalSeconds = math.modf(seconds)
	local milliseconds = math.floor(1000 * fractionalSeconds)
	local result = string.format("%s:%03d", string.DigitalTime(seconds), milliseconds)
	return result
end

function TGNS.IsPlayerExo(player) PROFILE("TGNS.IsPlayerExo")
	local result = player:isa("Exo")
	return result
end

function TGNS.GetClientIndex(client) PROFILE("TGNS.GetClientIndex")
	local result = TGNS.GetPlayer(client):GetClientIndex()
	return result
end

function TGNS.GetNumberOfConnectingPlayers() PROFILE("TGNS.GetNumberOfConnectingPlayers")
	local result = Server.GetNumPlayersTotal() - #TGNS.GetClientList(function(c) return not TGNS.GetIsClientVirtual(c) end)
	return result
end

function TGNS.GetAbbreviatedDayOfWeek(useUtcTime) PROFILE("TGNS.GetAbbreviatedDayOfWeek")
	local result = os.date((useUtcTime and "!" or "") .. "%a")
	return result
end

function TGNS.GetCurrentHour(useUtcTime) PROFILE("TGNS.GetCurrentHour")
	local result = os.date((useUtcTime and "!" or "") .. "*t").hour
	return result
end

function TGNS.GetCurrentMinute() PROFILE("TGNS.GetCurrentMinute")
	local result = os.date("*t").min
	return result
end

function TGNS.GetEntityHealth(entity) PROFILE("TGNS.GetEntityHealth")
	local result = entity:GetHealth()
	return result
end

function TGNS.SetEntityHealth(entity, health) PROFILE("TGNS.SetEntityHealth")
	local result = entity:SetHealth(health)
	return result
end

function TGNS.GetEntityArmor(entity) PROFILE("TGNS.GetEntityArmor")
	local result = entity:GetArmor()
	return result
end

function TGNS.SetEntityArmor(entity, armor) PROFILE("TGNS.SetEntityArmor")
	local result = entity:SetArmor(armor)
	return result
end

function TGNS.RemoveMarinePlayerJetpack(player) PROFILE("TGNS.RemoveMarinePlayerJetpack")
	if TGNS.ClientIsMarine(TGNS.GetClient(player)) then
	    local activeWeapon = player:GetActiveWeapon()
	    local activeWeaponMapName = nil
	    local health = player:GetHealth()
	    
	    if activeWeapon ~= nil then
	        activeWeaponMapName = activeWeapon:GetMapName()
	    end
	    
	    local marine = player:Replace(Marine.kMapName, player:GetTeamNumber(), true, Vector(player:GetOrigin()))
	    
	    marine:SetActiveWeapon(activeWeaponMapName)
	    marine:SetHealth(health)
	end
end

function TGNS.GiveMarinePlayerJetpack(player) PROFILE("TGNS.GiveMarinePlayerJetpack")
	if TGNS.ClientIsMarine(TGNS.GetClient(player)) and TGNS.IsPlayerAlive(player) and not TGNS.IsPlayerExo(player) then
		player:GiveJetpack()
	end
end

function TGNS.AlertApplicationIconForPlayer(player) PROFILE("TGNS.AlertApplicationIconForPlayer")
	Shine.Plugins.scoreboard:AlertApplicationIconForPlayer(player)
end

function TGNS.GetTwoLists(values) PROFILE("TGNS.GetTwoLists")
	local list1 = {}
	local list2 = {}
	TGNS.DoFor(values, function(n, index)
		if index % 2 ~= 0 then
			table.insert(list1, n)
		else
			table.insert(list2, n)
		end
	end)
	return list1, list2
end

function TGNS.GetClientHiveSkillRank(client) PROFILE("TGNS.GetClientHiveSkillRank")
	local result = TGNS.PlayerAction(client, TGNS.GetPlayerHiveSkillRank)
	return result
end

function TGNS.GetPlayerHiveSkillRank(player) PROFILE("TGNS.GetPlayerHiveSkillRank")
	local result = player.GetPlayerSkill and player:GetPlayerSkill() or 0
	return result
end

function TGNS.ShowPanel(values, renderClients, titleMessageId, column1MessageId, column2MessageId, titleY, titleText, titleSumText, duration, emptyText) PROFILE("TGNS.ShowPanel")
	local columnsY = titleY + 0.05
	local list1, list2 = TGNS.GetTwoLists(values)
	if #list1 == 0 and emptyText then table.insert(list1, emptyText) end
	local columnYDelta = 0.10
	titleText = TGNS.HasNonEmptyValue(titleText) and string.format("%s (%s)", titleText, titleSumText) or ""
	TGNS.DoFor(renderClients, function(c)
		-- Shine:SendText(c, Shine.BuildScreenMessage( titleMessageId, 0.75, titleY, titleText, duration, 0, 255, 0, 0, 2, 0 ) )
		Shine.ScreenText.Add(titleMessageId, {X = 0.75, Y = titleY, Text = titleText, Duration = duration, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
		local column1Message = TGNS.Join(list1, '\n')
		-- Shine:SendText(c, Shine.BuildScreenMessage( column1MessageId, 0.75, columnsY, column1Message, duration, 0, 255, 0, 0, 1, 0 ) )
		Shine.ScreenText.Add(column1MessageId, {X = 0.75, Y = columnsY, Text = column1Message, Duration = duration, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 1, FadeIn = 0, IgnoreFormat = true}, c)
		local column2Message = TGNS.Join(list2, '\n')
		-- Shine:SendText(c, Shine.BuildScreenMessage( column2MessageId, 0.75 + columnYDelta, columnsY, column2Message, duration, 0, 255, 0, 0, 1, 0 ) )
		Shine.ScreenText.Add(column2MessageId, {X = 0.75 + columnYDelta, Y = columnsY, Text = column2Message, Duration = duration, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 1, FadeIn = 0, IgnoreFormat = true}, c)
	end)
end

function TGNS.IsPlayerHallucination(player) PROFILE("TGNS.IsPlayerHallucination")
	local result = player and (player.isHallucination or player:isa("Hallucination"))
	return result
end

function TGNS.DebugPrint(message) PROFILE("TGNS.DebugPrint")
	local stamp = os.date("[%m/%d/%Y %H:%M:%S]")
	local messageWithStamp = string.format("%s %s", stamp, message)
	Shine:DebugPrint(messageWithStamp)
end

function TGNS.GetPlayerDeaths(player) PROFILE("TGNS.GetPlayerDeaths")
	local result = player:GetDeaths()
	return result
end

function TGNS.GetPlayerAssists(player) PROFILE("TGNS.GetPlayerAssists")
	local result = player:GetAssistKills()
	return result
end

function TGNS.GetPlayerKills(player) PROFILE("TGNS.GetPlayerKills")
	local result = player:GetKills()
	return result
end

function TGNS.PrintTable(t, tableDescription, printAction) PROFILE("TGNS.PrintTable")
	printAction = printAction and printAction or function(x) Shared.Message(x) end
	local keys = {}
	for key,value in pairs(t) do table.insert(keys, key) end
	TGNS.SortAscending(keys, function(k) return tostring(k) end)
	TGNS.DoFor(keys, function(k)
		printAction(string.format("%s.%s: %s", tableDescription, k, t[k]))
	end)
end

function TGNS.GetTeamCommandStructureCommonName(teamNumber) PROFILE("TGNS.GetTeamCommandStructureCommonName")
	local result = teamNumber == kMarineTeamType and "Chair" or "Hive"
	return result
end

function TGNS.GetReadableSteamIdFromNs2Id(ns2id) PROFILE("TGNS.GetReadableSteamIdFromNs2Id")
	local result = GetReadableSteamId(ns2id)
	return result
end

function TGNS.GetReadyRoomCommandParameters() PROFILE("TGNS.GetReadyRoomCommandParameters")
	local result = TGNS.Select(TGNS.GetPlayers(TGNS.Where(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c) return not TGNS.GetIsClientVirtual(c) end)), function(p) return {name=TGNS.GetPlayerName(p), value=TGNS.GetPlayerGameId(p)} end)
	table.insert(result, {name="All Players (*)", value="*"})
	table.insert(result, {name="Marines (@marine)", value="@marine"})
	table.insert(result, {name="Aliens (@alien)", value="@alien"})
	table.insert(result, {name="Strangers (%guest)", value="%guest"})
	return result
end

function TGNS.GetSteamCommunityProfileIdFromReadableSteamId(readableSteamId) PROFILE("TGNS.GetSteamCommunityProfileIdFromReadableSteamId")
	local parts = TGNS.Split( ':', string.sub(readableSteamId,7) )
	local id_64 = (1197960265728 + tonumber(parts[2])) + (tonumber(parts[3]) * 2)
	local str = string.format('%f',id_64)
	local result = '7656'..string.sub( str, 1, string.find(str,'.',1,true)-1 )
	return result
end

function TGNS.GetSteamCommunityProfileIdFromNs2Id(ns2id) PROFILE("TGNS.GetSteamCommunityProfileIdFromNs2Id")
	local readableSteamId = TGNS.GetReadableSteamIdFromNs2Id(ns2id)
	local result = TGNS.GetSteamCommunityProfileIdFromReadableSteamId(readableSteamId)
	return result
end

function TGNS.GetSteamCommunityProfileUrlFromNs2Id(ns2id) PROFILE("TGNS.GetSteamCommunityProfileUrlFromNs2Id")
	local steamCommunityProfileId = TGNS.GetSteamCommunityProfileIdFromNs2Id(ns2id)
	local result = string.format("http://steamcommunity.com/profiles/%s", steamCommunityProfileId)
	return result
end

function TGNS.GetSteamApiProfileUrlFromNs2Id(ns2id) PROFILE("TGNS.GetSteamApiProfileUrlFromNs2Id")
	local steamCommunityProfileId = TGNS.GetSteamCommunityProfileIdFromNs2Id(ns2id)
	local result = string.format("http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s", TGNS.Config.SteamApiKey, steamCommunityProfileId)
	return result
end

function TGNS.GetTechPoints() PROFILE("TGNS.GetTechPoints")
	local result = TGNS.GetEntitiesWithClassName("TechPoint")
	return result
end

function TGNS.GetCommandStructures() PROFILE("TGNS.GetCommandStructures")
	local result = TGNS.GetEntitiesWithClassName("CommandStructure")
	return result
end

function TGNS.GetTechPointLocationNames() PROFILE("TGNS.GetTechPointLocationNames")
	local result = TGNS.Select(TGNS.GetTechPoints(), function(t) return t:GetLocationName() end)
	return result
end

function TGNS.GetCount(elements) PROFILE("TGNS.GetCount")
	return #elements
end

function TGNS.AtLeastOneElementExists(elements) PROFILE("TGNS.AtLeastOneElementExists")
	local result = elements ~= nil and #elements > 0
	return result
end

function TGNS.GetVoteableMapNames(restrictToCurrentGroup) PROFILE("TGNS.GetVoteableMapNames")
	local result = {}
	local numberOfPlayers = Server.GetNumPlayersTotal()
	local mapCycleMapNames = TGNS.SelectMapCycleMapNames(function(m)
		local mapMin
		if type(m) == "table" then
			mapMin = m.min and m.min or 0
		else
			mapMin = 0
		end
		return mapMin <= numberOfPlayers
	end)
	if Shine.Plugins.mapvote and Shine.Plugins.mapvote.Enabled and not Shine.Plugins.mapvote.Config.GetMapsFromMapCycle then
		TGNS.DoForPairs(Shine.Plugins.mapvote.Config.Maps, function(mapName, enabled)
			if TGNS.Has(mapCycleMapNames, mapName) and enabled then
				table.insert(result, mapName)
			end
		end)
	else
		result = mapCycleMapNames
	end
	local mapGroup = Shine.Plugins.mapvote:GetMapGroup()
	if mapGroup and mapGroup.maps and restrictToCurrentGroup then
		TGNS.DoForReverse(result, function(r, i)
			if not TGNS.Has(mapGroup.maps, r) then
				table.remove(result, i)
			end
		end)
	end
	TGNS.SortAscending(result)
	return result
end

function TGNS.SelectMapCycleMapNames(predicate) PROFILE("TGNS.SelectMapCycleMapNames")
	local result = {}
	local mapCycle = (MapCycle_GetMapCycle and MapCycle_GetMapCycle()) or TGNSJsonFileTranscoder.DecodeFromFile("config://MapCycle.json")
	TGNS.DoFor(mapCycle.maps, function(m, i)
		if predicate == nil or predicate(m) then
			local mapName = type(m) == "table" and m.map or m
			table.insert(result, mapName)
		end
	end)
	TGNS.SortAscending(result)
	return result
end

function TGNS.GetMapCycleModMapNames() PROFILE("TGNS.GetMapCycleModMapNames")
	local result = TGNS.SelectMapCycleMapNames(function(m)
		return m.mods and #m.mods > 0
	end)
	return result
end

function TGNS.GetMapCycleStockMapNames() PROFILE("TGNS.GetMapCycleStockMapNames")
	local result = TGNS.SelectMapCycleMapNames(function(m)
		return m.mods == nil or #m.mods == 0
	end)
	return result
end

function TGNS.GetMapCycleMapNames() PROFILE("TGNS.GetMapCycleMapNames")
	local result = TGNS.SelectMapCycleMapNames()
	return result
end

function TGNS.GetPlayerId(player) PROFILE("TGNS.GetPlayerId")
	local result = player:GetId()
	return result
end

function TGNS.GetClientId(client) PROFILE("TGNS.GetClientId")
	local result = client:GetId()
	return result
end

function TGNS.GetPlayerGameId(player) PROFILE("TGNS.GetPlayerGameId")
	local client = TGNS.GetClient(player)
	local result = Shine.GameIDs:Get(client)
	return result
end

function TGNS.SendNetworkMessageToPlayer(player, messageName, variables) PROFILE("TGNS.SendNetworkMessageToPlayer")
	variables = variables or {}
	Server.SendNetworkMessage(player, messageName, variables, true)
end

function TGNS.GetPlayerById(id) PROFILE("TGNS.GetPlayerById")
	local result = TGNS.GetFirst(TGNS.Where(TGNS.GetPlayerList(), function(p) return p:GetId() == id end))
	return result
end

function TGNS.ExecuteClientCommand(client, command) PROFILE("TGNS.ExecuteClientCommand")
	local player = TGNS.GetPlayer(client)
	if player then
		Server.ClientCommand(player, command)
	end
end

function TGNS.SendClientCommand(client, command) PROFILE("TGNS.SendClientCommand")
	local player = TGNS.GetPlayer(client)
	if player then
		Server.SendCommand(player, command)
	end
end

function TGNS.ExecuteServerCommand(command) PROFILE("TGNS.ExecuteServerCommand")
	Shared.ConsoleCommand(command)
end

function TGNS.StructureIsBuilt(structure) PROFILE("TGNS.StructureIsBuilt")
	local result = structure:GetIsBuilt()
	return result
end

function TGNS.StructureIsAlive(structure) PROFILE("TGNS.StructureIsAlive")
	local result = structure:GetIsAlive()
	return result
end

function TGNS.CommandStructureIsBuiltAndAlive(commandStructure) PROFILE("TGNS.CommandStructureIsBuiltAndAlive")
	local result = TGNS.StructureIsBuilt(commandStructure) and TGNS.StructureIsAlive(commandStructure)
	return result
end

function TGNS.GetNumberOfWorkingInfantryPortals(commandStation) PROFILE("TGNS.GetNumberOfWorkingInfantryPortals")
	local infantryPortalsWithinRangeOfTheCommandStation = GetEntitiesForTeamWithinRange("InfantryPortal", kMarineTeamType, commandStation:GetOrigin(), 15)
	local builtAndPoweredInfantryPortalsWithinRangeOfTheCommandStation = TGNS.Where(infantryPortalsWithinRangeOfTheCommandStation, function(p) return p:GetIsBuilt() and p:GetIsPowered() end)
	local result = #builtAndPoweredInfantryPortalsWithinRangeOfTheCommandStation
	return result
end

function TGNS.CommandStructureHasCommander(commandStructure) PROFILE("TGNS.CommandStructureHasCommander")
	local result = commandStructure:GetCommander() ~= nil
	return result
end

function TGNS.Ban(client, targetClient, durationInMinutes, reason) PROFILE("TGNS.Ban")
	local targetSteamId = TGNS.GetClientSteamId(targetClient)
	local targetName = TGNS.GetClientName(targetClient)
	local bannedBy = TGNS.GetClientNameSteamIdCombo(client)
	local banningId = TGNS.GetClientSteamId(client)
	Shine.Plugins.ban:AddBan(targetSteamId, targetName, durationInMinutes * 60, bannedBy, banningId, reason)
end

function TGNS.IsPlayerAlive(player) PROFILE("TGNS.IsPlayerAlive")
	local result = player.GetIsAlive and player:GetIsAlive()
	return result
end

function TGNS.IsClientAlive(client) PROFILE("TGNS.IsClientAlive")
	return TGNS.PlayerAction(client, TGNS.IsPlayerAlive)
end

function TGNS.IsNumberWithNonZeroPositiveValue(candidate) PROFILE("TGNS.IsNumberWithNonZeroPositiveValue")
	candidate = tonumber(candidate)
	local result = candidate and candidate > 0
	return result
end

function TGNS.InsertDistinctly(elements, element) PROFILE("TGNS.InsertDistinctly")
	if not TGNS.Has(elements, element) then
		table.insert(elements, element)
	end
end

function TGNS.PlayerTeamIsOverbalanced(player, playerList) PROFILE("TGNS.PlayerTeamIsOverbalanced")
	local result
	TGNS.DoTeamSizeComparisonAction(player, playerList, function(playerTeamCount, otherTeamCount)
		result = playerTeamCount >= otherTeamCount + 2
	end)
	return result
end

function TGNS.GetOtherPlayingTeamName(teamName) PROFILE("TGNS.GetOtherPlayingTeamName")
	local result
	if teamName and teamName == "Marines" then
		result = "Aliens"
	elseif teamName and teamName == "Aliens" then
		result = "Marines"
	end
	return result
end

function TGNS.DoTeamSizeComparisonAction(player, playerList, action) PROFILE("TGNS.DoTeamSizeComparisonAction")
	local playerTeamCount = #TGNS.GetTeamClients(TGNS.GetPlayerTeamNumber(player), playerList)
	local otherTeamCount = #TGNS.GetPlayersOnOtherPlayingTeam(player, playerList)
	action(playerTeamCount, otherTeamCount)
end

function TGNS.GetOtherPlayingTeamNumber(playingTeamNumber) PROFILE("TGNS.GetOtherPlayingTeamNumber")
	assert(TGNS.IsGameplayTeamNumber(playingTeamNumber), "Input team number is not a playing team number.")
	local result = playingTeamNumber == kMarineTeamType and kAlienTeamType or kMarineTeamType
	return result
end

function TGNS.GetPlayersOnOtherPlayingTeam(player, playerList) PROFILE("TGNS.GetPlayersOnOtherPlayingTeam")
	local playerTeamNumber = TGNS.GetPlayerTeamNumber(player)
	local otherTeamNumber = TGNS.GetOtherPlayingTeamNumber(playerTeamNumber)
	local result = TGNS.GetPlayers(TGNS.GetTeamClients(otherTeamNumber, playerList))
	return result
end

function TGNS.GetPlayerScorePerMinute(player) PROFILE("TGNS.GetPlayerScorePerMinute")
	local result
	local gameDurationInSeconds = TGNS.GetCurrentGameDurationInSeconds()
	if gameDurationInSeconds ~= nil then
		local playerScore = TGNS.GetPlayerScore(player)
		local gameDurationInMinutes = TGNS.ConvertSecondsToMinutes(gameDurationInSeconds)
		result = TGNSAverageCalculator.Calculate(playerScore, gameDurationInMinutes)
	end
	return result
end

function TGNS.GetCurrentGameDurationInSeconds() PROFILE("TGNS.GetCurrentGameDurationInSeconds")
	local result
	local gameStartTime = GetGamerules():GetGameStartTime()
	if gameStartTime > 0 then
		result = Shared.GetTime() - gameStartTime
	end
	return result
end

function TGNS.GetPlayerScore(player) PROFILE("TGNS.GetPlayerScore")
	local result = player:GetScore()
	return result
end

function TGNS.GetHumanClientList(predicate) PROFILE("TGNS.GetHumanClientList")
	local clients = TGNS.GetClientList(predicate)
	local result = TGNS.Where(clients, function(c) return not TGNS.GetIsClientVirtual(c) end)
	return result
end

function TGNS.GetHumanPlayerCount()
	local result = Shine.GetHumanPlayerCount()
	return result
end

function TGNS.GetSimpleServerName() PROFILE("TGNS.GetSimpleServerName")
	return TGNS.Config.ServerSimpleName
end

function TGNS.GetNextMapName() PROFILE("TGNS.GetNextMapName")
	local result = Shine.Plugins.mapvote:GetNextMap()
	return result
end

function TGNS.ToTitle(s) PROFILE("TGNS.ToTitle")
	local result=""
    for word in string.gfind(s, "%S+") do          
        local first = string.sub(word,1,1)
        result = (result .. string.upper(first) .. string.lower(string.sub(word,2)) .. ' ')
    end
    result = StringTrim(result)
    return result
end

function TGNS.SwitchToMap(mapName) PROFILE("TGNS.SwitchToMap")
	MapCycle_ChangeMap(mapName)
end

function TGNS.GetClientList(predicate) PROFILE("TGNS.GetClientList")
	local result = TGNS.GetClients(TGNS.GetPlayerList())
	if predicate ~= nil then
		result = TGNS.Where(result, predicate)
	end
	return result
end

function TGNS.GetPlayerTotalCost(player) PROFILE("TGNS.GetPlayerTotalCost")
	local result = TGNS.GetPlayerClassPurchaseCost(player) + TGNS.GetMarineWeaponsTotalPurchaseCost(player) + TGNS.GetAlienUpgradesPurchaseCost(player) + TGNS.GetPlayerResources(player)
	return result
end

function TGNS.SecondsToClock(sSeconds) PROFILE("TGNS.SecondsToClock")
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

function TGNS.KillPlayer(player) PROFILE("TGNS.KillPlayer")
	player:Kill(nil, nil, player:GetOrigin())
end

function TGNS.GetPlayerClassName(player) PROFILE("TGNS.GetPlayerClassName")
	local result = player:GetClassName()
	return result
end

function TGNS.GetPlayerPointValue(player) PROFILE("TGNS.GetPlayerPointValue")
	local pointValues = {
      ["Marine"] = kMarinePointValue,
      ["JetpackMarine"] = kJetpackPointValue,
      ["Exo"] = kExosuitPointValue,
      ["Skulk"] = kSkulkPointValue,
      ["Gorge"] = kGorgePointValue,
      ["Lerk"] = kLerkPointValue,
      ["Fade"] = kFadePointValue,
      ["Onos"] = kOnosPointValue
    }
    local result = pointValues[TGNS.GetPlayerClassName(player)]
    return result
end

function TGNS.GetMarineWeaponsTotalPurchaseCost(player) PROFILE("TGNS.GetMarineWeaponsTotalPurchaseCost")
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

function TGNS.GetAlienUpgradesPurchaseCost(player) PROFILE("TGNS.GetAlienUpgradesPurchaseCost")
	local alienClassUpgradePurchaseCosts = {
      ["Skulk"] = kSkulkUpgradeCost,
      ["Gorge"] = kGorgeUpgradeCost,
      ["Lerk"] = kLerkUpgradeCost,
      ["Fade"] = kFadeUpgradeCost,
      ["Onos"] = kOnosUpgradeCost
    }
    local playerClassUpgradePurchaseCost = alienClassUpgradePurchaseCosts[TGNS.GetPlayerClassName(player)]
    local playerUpgrades = player.GetUpgrades and player:GetUpgrades()
    local result = (playerUpgrades and playerClassUpgradePurchaseCost) and (playerClassUpgradePurchaseCost * #playerUpgrades) or 0
    return result
end

function TGNS.GetPlayerClassPurchaseCost(player) PROFILE("TGNS.GetPlayerClassPurchaseCost")
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
      ["MinigunMinigun"] = kDualExosuitCost,
      ["RailgunRailgun"] = kDualRailgunExosuitCost
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

function TGNS.IsGameInCountdown() PROFILE("TGNS.IsGameInCountdown")
	local result = TGNS.GetGameState() == kGameState.Countdown
	return result
end

function TGNS.IsGameInProgress() PROFILE("TGNS.IsGameInProgress")
	local result = TGNS.GetGameState() == kGameState.Started
	return result
end

function TGNS.RoundPositiveNumberDown(num, numberOfDecimalPlaces) PROFILE("TGNS.RoundPositiveNumberDown")
	local mult = 10^(numberOfDecimalPlaces or 0)
	local result = math.floor(num * mult + 0.5) / mult
	return result
end

function TGNS.GetPlayerResources(player) PROFILE("TGNS.GetPlayerResources")
	local result = player:GetResources()
	return result
end

function TGNS.GetClientResources(client) PROFILE("TGNS.GetClientResources")
	local player = TGNS.GetPlayer(client)
	return TGNS.GetPlayerResources(player)
end

function TGNS.SetClientResources(client, value) PROFILE("TGNS.SetClientResources")
	local player = TGNS.GetPlayer(client)
	TGNS.SetPlayerResources(player, value)
end

function TGNS.SetPlayerResources(player, value) PROFILE("TGNS.SetPlayerResources")
	player:SetResources(value)
end

function TGNS.AddClientResources(client, value) PROFILE("TGNS.AddClientResources")
	TGNS.SetClientResources(client, TGNS.GetClientResources(client) + value)
end

function TGNS.AddPlayerResources(player, value) PROFILE("TGNS.AddPlayerResources")
	player:SetResources(TGNS.GetPlayerResources(player) + value)
end

function TGNS.RemoveAllMatching(elements, element) PROFILE("TGNS.RemoveAllMatching")
	TGNS.DoForReverse(elements, function(e, index)
		if element == e then
			table.remove(elements, index)
		end
	end)
end

function TGNS.DestroyEntity(entity) PROFILE("TGNS.DestroyEntity")
	DestroyEntity(entity)
end

function TGNS.GetEntitiesByName(className, name) PROFILE("TGNS.GetEntitiesByName")
	local result = {}
	TGNS.DoFor(TGNS.GetEntitiesWithClassName(className), function(entity)
	    local entMT = getmetatable(entity)
	    local _, properties = entMT.__towatch(entity)
	    TGNS.DoForPairs(properties, function(key, value)
	    	if key == "name" and value == name then
	    		table.insert(result, entity)
	    	end
	    end)
	end)
	return result
end

function TGNS.DestroyEntitiesExcept(entities, entityToKeep) PROFILE("TGNS.DestroyEntitiesExcept")
	TGNS.DoFor(entities, function (e)
		if e ~= entityToKeep then
			TGNS.DestroyEntity(e)
		end
	end)
end

function TGNS.GetEntitiesWithClassName(className) PROFILE("TGNS.GetEntitiesWithClassName")
	local result = {}
    for _, entity in ientitylist(Shared.GetEntitiesWithClassname(className)) do
        table.insert(result, entity)
    end
	return result
end

function TGNS.KillTeamEntitiesExcept(className, teamNumber, entityToKeep) PROFILE("TGNS.KillTeamEntitiesExcept")
	local entities = TGNS.GetEntitiesForTeam(className, teamNumber)
	TGNS.DestroyEntitiesExcept(entities, entityToKeep)
end

function TGNS.GetEntitiesForTeam(className, teamNumber) PROFILE("TGNS.GetEntitiesForTeam")
	local result = GetEntitiesForTeam(className, teamNumber)
	return result
end

function TGNS.EntityIsCommandStructure(entity) PROFILE("TGNS.EntityIsCommandStructure")
	local result = false
	if entity ~= nil then
		local entityClassName = entity:GetClassName()
		result = entityClassName == "CommandStation" or entityClassName == "Hive"
	end
	return result
end

function TGNS.DestroyAllEntities(className, teamNumber) PROFILE("TGNS.DestroyAllEntities")
	local entities = TGNS.GetEntitiesForTeam(className, teamNumber)
	TGNS.DoFor(entities, function(e) TGNS.DestroyEntity(e) end)
end

function TGNS.IsTournamentMode() PROFILE("TGNS.IsTournamentMode")
	local result = DAK:GetTournamentMode()
	return result
end

function TGNS.AddTempGroup(client, groupName) PROFILE("TGNS.AddTempGroup")
	Shine.Plugins.tempgroups:AddTempGroup(client, groupName)
	TGNS.ExecuteEventHooks("ClientGroupsChanged", client)
end

function TGNS.RemoveTempGroup(client, groupName) PROFILE("TGNS.RemoveTempGroup")
	Shine.Plugins.tempgroups:RemoveTempGroup(client, groupName)
	TGNS.ExecuteEventHooks("ClientGroupsChanged", client)
end

function TGNS.ClientIsInGroup(client, groupName) PROFILE("TGNS.ClientIsInGroup")
	local result = Shine:IsInGroup(client, groupName)
	return result
end

function TGNS.GetPlayerAfkDurationInSeconds(player) PROFILE("TGNS.GetPlayerAfkDurationInSeconds")
	local result = 0
	local AFKKick = Shine.Plugins.afkkick
    local AFKEnabled = AFKKick and AFKKick.Enabled
    if AFKEnabled then
	    local LastMoveTime = TGNS.ClientAction(player, function(c) return AFKKick:GetLastMoveTime(c) end)
	    result = LastMoveTime and (TGNS.GetSecondsSinceMapLoaded() - LastMoveTime) or 0
    end
    return result
end

function TGNS.MarkPlayerAFK(player) PROFILE("TGNS.MarkPlayerAFK")
	local client = TGNS.GetClient(player)
	if not TGNS.GetIsClientVirtual(client) and Shine.Plugins.afkkick and Shine.Plugins.afkkick.Users then
		local clientAfkData = Shine.Plugins.afkkick.Users[client]
		if clientAfkData then
			local lastMove = Shared.GetTime() - AFK_IDLE_THRESHOLD_SECONDS - 1
			lastMove = lastMove >= 0 and lastMove or 0
			clientAfkData.LastMove = lastMove
		end
	end
end

function TGNS.ClearPlayerAFK(player) PROFILE("TGNS.ClearPlayerAFK")
	local client = TGNS.GetClient(player)
	Shine.Plugins.afkkick:ResetAFKTime(client)
end

function TGNS.IsClientAFK(client) PROFILE("TGNS.IsClientAFK")
	return TGNS.IsPlayerAFK(TGNS.GetPlayer(client))
end

local lastAfkHumanCountQueryWhen = 0
local lastAfkHumanCount = 0
function TGNS.IsPlayerAFK(player) PROFILE("TGNS.IsPlayerAFK")
	-- local result = false
	-- local AFKKick = Shine.Plugins.improvedafkhandler
	-- local AFKEnabled = AFKKick and AFKKick.Enabled
	-- if AFKEnabled then
	-- 	local PlayerAFK = AFKKick:GetPlayerAFK()
	-- 	result = PlayerAFK:IsAFKFor( TGNS.GetClient(player), AFKKick.Config.ConsiderAFKTime )
	-- end
	-- return result
    local result = false
    local AFKKick = Shine.Plugins.afkkick
    local AFKEnabled = AFKKick and AFKKick.Enabled
    if AFKEnabled then
    		if lastAfkHumanCountQueryWhen + 3 < Shared.GetTime() then
    			humanPlayerCount = TGNS.GetHumanPlayerCount()
    			lastAfkHumanCountQueryWhen = Shared.GetTime()
    		end
            if humanPlayerCount < AFKKick.Config.MinPlayers then
                result = false
            else
            	result = TGNS.GetPlayerAfkDurationInSeconds(player) >= AFK_IDLE_THRESHOLD_SECONDS
            end
    end
    return result
end

function TGNS.IsPluginEnabled(pluginName) PROFILE("TGNS.IsPluginEnabled")
	local result = Shine.Plugins[pluginName] and Shine.Plugins[pluginName].Enabled
	return result
end

function TGNS.ClientCanRunCommand(client, command) PROFILE("TGNS.ClientCanRunCommand")
	local result = Shine:GetPermission(client, command) or Shine:HasAccess(client, command)
	return result
end

function TGNS.IsInGroup(client, groupName) PROFILE("TGNS.IsInGroup")
	local result = Shine:IsInGroup(client, groupName)
	return result
end

function TGNS.GetConcatenatedStringOrEmpty(...) PROFILE("TGNS.GetConcatenatedStringOrEmpty")
	local result = ""
	local concatenation = StringConcatArgs(...)
	if concatenation then
		result = concatenation
	end
	return result
end

function TGNS.PlayerIsRookie(player) PROFILE("TGNS.PlayerIsRookie")
	local result = player:GetIsRookie()
	return result
end

function TGNS.GetClientCommunityDesignationCharacter(client) PROFILE("TGNS.GetClientCommunityDesignationCharacter")
	local result
	if TGNS.IsClientSM(client) then
		result = "S"
	elseif TGNS.HasClientSignedPrimerWithGames(client) then
		result = "P"
	else
		result = "?"
	end
	return result
end

function TGNS.RespawnPlayer(player) PROFILE("TGNS.RespawnPlayer")
	GetGamerules():RespawnPlayer(player)
end

function TGNS.GetTeamFromTeamNumber(teamNumber) PROFILE("TGNS.GetTeamFromTeamNumber")
	local result = GetGamerules():GetTeam(teamNumber)
	return result
end

function TGNS.SendToRandomTeam(player) PROFILE("TGNS.SendToRandomTeam")
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

function TGNS.ForcePlayersToReadyRoom(players) PROFILE("TGNS.ForcePlayersToReadyRoom")
	TGNS.DoFor(players, function(p) TGNS.SendToTeam(p, kTeamReadyRoom, true) end)
end

function TGNS.SendToTeam(player, teamNumber, force) PROFILE("TGNS.SendToTeam")
	Shared.Message(string.format("TGNS.SendToTeam: Sending %s to team %s...", TGNS.GetPlayerName(player), teamNumber))
	return GetGamerules():JoinTeam(player, teamNumber, force)
end

function TGNS.GetPlayerTeamName(player) PROFILE("TGNS.GetPlayerTeamName")
	local result = TGNS.GetTeamName(TGNS.GetPlayerTeamNumber(player))
	return result
end

function TGNS.GetClientTeamName(client) PROFILE("TGNS.GetClientTeamName")
	local result = TGNS.GetTeamName(TGNS.GetClientTeamNumber(client))
	return result
end

function TGNS.GetTeam(player) PROFILE("TGNS.GetTeam")
	local result = player:GetTeam()
	return result
end

function TGNS.ClientIsAlien(client) PROFILE("TGNS.ClientIsAlien")
	local result = TGNS.GetClientTeamNumber(client) == kAlienTeamType
	return result
end

function TGNS.PlayerIsMarine(player) PROFILE("TGNS.PlayerIsMarine")
	return TGNS.ClientAction(player, TGNS.ClientIsMarine)
end

function TGNS.PlayerIsAlien(player) PROFILE("TGNS.PlayerIsAlien")
	return TGNS.ClientAction(player, TGNS.ClientIsAlien)
end

function TGNS.ClientIsMarine(client) PROFILE("TGNS.ClientIsMarine")
	local result = TGNS.GetClientTeamNumber(client) == kMarineTeamType
	return result
end

function TGNS.GetClientTeamNumber(client) PROFILE("TGNS.GetClientTeamNumber")
	local result = TGNS.GetPlayerTeamNumber(TGNS.GetPlayer(client))
	return result
end

function TGNS.GetPlayerTeamNumber(player) PROFILE("TGNS.GetPlayerTeamNumber")
	-- local playerTeam = player:GetTeam()
	-- local result = playerTeam:GetTeamNumber()
	-- return result
	local result = player:GetTeamNumber()
	return result
end

function TGNS.GetPlayersOnSameTeam(player) PROFILE("TGNS.GetPlayersOnSameTeam")
	local result = TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.GetPlayerTeamNumber(player) == TGNS.GetPlayerTeamNumber(p) end)
	return result
end

function TGNS.PlayersAreTeammates(player1, player2) PROFILE("TGNS.PlayersAreTeammates")
	local result = TGNS.GetPlayerTeamNumber(player1) == TGNS.GetPlayerTeamNumber(player2)
	return result
end

function TGNS.ClientsAreTeammates(client1, client2) PROFILE("TGNS.ClientsAreTeammates")
	return TGNS.PlayersAreTeammates(TGNS.GetPlayer(client1), TGNS.GetPlayer(client2))
end

function TGNS.ScheduleActionInterval(intervalInSeconds, action) PROFILE("TGNS.ScheduleActionInterval")
	TGNS.ScheduleAction(intervalInSeconds, action)
	TGNS.ScheduleAction(intervalInSeconds, function() TGNS.ScheduleActionInterval(intervalInSeconds, action) end)
end

function TGNS.ScheduleAction(delayInSeconds, action) PROFILE("TGNS.ScheduleAction")
	local scheduledAction = {}
	scheduledAction.when = Shared.GetTime() + delayInSeconds
	scheduledAction.what = action
	table.insert(scheduledActions, scheduledAction)
end

local function ProcessScheduledActions() PROFILE("ProcessScheduledActions")
	TGNS.DoForReverse(scheduledActions, function(scheduledAction, index)
		if scheduledAction.when < Shared.GetTime() then
			local success, result = xpcall(scheduledAction.what, debug.traceback)
			if success then
				table.remove(scheduledActions, index)
			else
				scheduledActionsErrorCount = scheduledActionsErrorCounts[scheduledAction.what] and scheduledActionsErrorCounts[scheduledAction.what] or 1
				if scheduledActionsErrorCount <= 1 then
					local errorTemplate = "ScheduledAction Error (#%s @ %s): %s"
					--TGNS.EnhancedLog(string.format(errorTemplate, scheduledActionsErrorCount, Shared.GetTime(), result))
					TGNS.DebugPrint(string.format(errorTemplate, scheduledActionsErrorCount, Shared.GetTime(), result))
					scheduledActionsErrorCount = scheduledActionsErrorCount + 1
					scheduledActionsErrorCounts[scheduledAction.what] = scheduledActionsErrorCount
				else
					table.remove(scheduledActions, index)
				end
			end
		end
	end)
end

local function ProcessScheduledRequests() PROFILE("ProcessScheduledRequests")
	local waitingCountDebugLogger = function(count)
		-- local httpDebugMd = TGNSMessageDisplayer.Create("TGNSHTTPDEBUG")
		-- httpDebugMd:ToAdminConsole(string.format("Currently waiting: %s", count))
	end


	local unsentRequests = TGNS.Where(scheduledRequests, function(r) return r.sent ~= true end)
	if #unsentRequests > 0 and TGNS.ShouldProcessHttpRequests then
		local unsentScheduledRequests = TGNS.Take(unsentRequests, TGNS.Config and TGNS.Config.HttpRequestsPerSecond or 1)
		TGNS.DoFor(unsentScheduledRequests, function(r)
			r.sent = true
			-- local requestStartTime = Shared.GetTime()
			if TGNS.LogHttp then -- or not TGNS.IsProduction() then
				Shared.Message(string.format("TGNSCommonServer debug> http request #%s: %s", numberOfHttpRequestsMade, r.url))
			end
			numberOfHttpRequestsMade = numberOfHttpRequestsMade + 1
			Shared.SendHTTPRequest(r.url, "GET", function(response)
				-- local requestDuration = Shared.GetTime() - requestStartTime
				TGNS.RemoveAllMatching(scheduledRequests, r)
				if #scheduledRequests == 0 then
					waitingCountDebugLogger(0)
				end
				r.callback(response)
				-- if requestDuration > 1 then
				-- 	local urlWithoutScheme = TGNS.Substring(r.url, 8)
				-- 	local documentBaseIndex = TGNS.IndexOf(urlWithoutScheme, "/")
				-- 	local queryStringBaseIndex = TGNS.IndexOf(urlWithoutScheme, "?") + 1
				-- 	local partialUrl = TGNS.Substring(urlWithoutScheme, documentBaseIndex, queryStringBaseIndex - documentBaseIndex)
				-- 	local partialQuery = TGNS.Substring(urlWithoutScheme, queryStringBaseIndex)
				-- 	if TGNS.IndexOf(r.url, "4155") > 0 then
				-- 		partialQuery = TGNS.Substring(urlWithoutScheme, queryStringBaseIndex + 27)
				-- 		local ampersandIndex = TGNS.IndexOf(partialQuery, "&")
				-- 		partialQuery = TGNS.Substring(partialQuery, ampersandIndex + 1)
				-- 	end
				-- 	local debugUrl = string.format("%s%s", partialUrl, partialQuery)
				-- 	TGNS.DebugPrint(string.format("HTTP Request duration: %s seconds waiting for %s", requestDuration, debugUrl))
				-- end
			end)
		end)
		waitingCountDebugLogger(#unsentRequests)
	end
end
TGNS.RegisterEventHook("OnEverySecond", function()
	ProcessScheduledActions()
	ProcessScheduledRequests()
end)

function TGNS.GetHttpAsync(url, callback) PROFILE("TGNS.GetHttpAsync")
	local scheduledRequest = {}
	scheduledRequest.url = url
	scheduledRequest.callback = callback
	table.insert(scheduledRequests, scheduledRequest)
end

function TGNS.PlayerIsOnTeam(player, team) PROFILE("TGNS.PlayerIsOnTeam")
	local result = player:GetTeam() == team
	return result
end

function TGNS.GetGameState() PROFILE("TGNS.GetGameState")
	local result = GetGamerules():GetGameState()
	return result
end

function TGNS.IsGameStartingState(gameState) PROFILE("TGNS.IsGameStartingState")
	local result = gameState == kGameState.Started
	return result
end

function TGNS.ForceGameStart() PROFILE("TGNS.ForceGameStart")
	local gamerules = GetGamerules()
    gamerules:ResetGame()
    gamerules:SetGameState(kGameState.Countdown)
	TGNS.ResetAllPlayerScores()
    gamerules.countdownTime = kCountDownLength
    gamerules.lastCountdownPlayed = nil
end

function TGNS.ResetAllPlayerScores() PROFILE("TGNS.ResetAllPlayerScores")
    for _, player in ientitylist(Shared.GetEntitiesWithClassname("Player")) do
        if player.ResetScores then
            player:ResetScores()
        end
    end
end

function TGNS.IsGameInPreGame() PROFILE("TGNS.IsGameInPreGame")
	local result = TGNS.GetGameState() == kGameState.PreGame
	return result
end

function TGNS.IsGameWinningState(gameState) PROFILE("TGNS.IsGameWinningState")
	local result = gameState == kGameState.Team1Won or gameState == kGameState.Team2Won
	return result
end

function TGNS.IsGameplayTeamNumber(teamNumber) PROFILE("TGNS.IsGameplayTeamNumber")
	local result = teamNumber == kMarineTeamType or teamNumber == kAlienTeamType
	return result
end

function TGNS.GetTeamName(teamNumber) PROFILE("TGNS.GetTeamName")
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

function TGNS.IsClientReadyRoom(client) PROFILE("TGNS.IsClientReadyRoom")
	return TGNS.PlayerAction(client, TGNS.IsPlayerReadyRoom)
end

function TGNS.IsPlayerReadyRoom(player) PROFILE("TGNS.IsPlayerReadyRoom")
	local result = player:GetTeamNumber() == kTeamReadyRoom
	return result
end

function TGNS.IsTeamNumberSpectator(teamNumber) PROFILE("TGNS.IsTeamNumberSpectator")
	local result = teamNumber == kSpectatorIndex
	return result
end

function TGNS.IsPlayerSpectator(player) PROFILE("TGNS.IsPlayerSpectator")
	local result = TGNS.IsTeamNumberSpectator(player:GetTeamNumber())
	return result
end

function TGNS.IsClientSpectator(client) PROFILE("TGNS.IsClientSpectator")
	local result = TGNS.PlayerAction(client, TGNS.IsPlayerSpectator)
	return result
end

function TGNS.GetNumericValueOrZero(countable) PROFILE("TGNS.GetNumericValueOrZero")
	local result = countable == nil and 0 or countable
	return result
end

function TGNS.GetTeamCommanderClient(teamNumber) PROFILE("TGNS.GetTeamCommanderClient")
	local result = TGNS.GetFirst(TGNS.Where(TGNS.GetTeamClients(teamNumber), TGNS.IsClientCommander))
	return result
end

function TGNS.IsClientCommander(client) PROFILE("TGNS.IsClientCommander")
	local result = false
	if client ~= nil then
		local player = client:GetControllingPlayer()
		if player ~= nil then
			result = player:isa("Commander")
		end
	end
	return result
end

function TGNS.IsClientGuardian(client) PROFILE("TGNS.IsClientGuardian")
	local result = false
	if client ~= nil then
		result = not TGNS.IsClientAdmin(client) and TGNS.IsInGroup(client, "guardian_group")
	end
	return result
end

function TGNS.IsClientTempAdmin(client) PROFILE("TGNS.IsClientTempAdmin")
	local result = false
	if client ~= nil then
		local clientIsAdmin = TGNS.IsClientAdmin(client)
		local clientIsTempAdmin = TGNS.IsInGroup(client, "tempadmin_group")
		result = not clientIsAdmin and clientIsTempAdmin
	end
	return result
end

function TGNS.HasSteamIdSignedPrimerWithGames(steamId) PROFILE("TGNS.HasSteamIdSignedPrimerWithGames")
	local result = TGNS.HasSteamIdSignedPrimer(steamId)
	if result == true and Shine.Plugins.Balance and Shine.Plugins.Balance.GetTotalGamesPlayedBySteamId then
		result = Shine.Plugins.Balance.GetTotalGamesPlayedBySteamId(steamId) >= TGNS.PRIMER_GAMES_THRESHOLD
	end
	return result
end

function TGNS.HasPlayerSignedPrimerWithGames(player) PROFILE("TGNS.HasPlayerSignedPrimerWithGames")
	local client = TGNS.GetClient(player)
	local result = TGNS.HasClientSignedPrimerWithGames(client)
	return result
end

function TGNS.HasClientSignedPrimerWithGames(client) PROFILE("TGNS.HasClientSignedPrimerWithGames")
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.HasSteamIdSignedPrimerWithGames(steamId)
	end
	return result
end

function TGNS.HasSteamIdSignedPrimer(steamId) PROFILE("TGNS.HasSteamIdSignedPrimer")
	local result = Shine.Plugins.permissions:IsSteamIdInGroup(steamId, "primer_group")
	return result
end

function TGNS.HasClientSignedPrimer(client) PROFILE("TGNS.HasClientSignedPrimer")
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.HasSteamIdSignedPrimer(steamId)
	end
	return result
end

function TGNS.IsSteamIdAdmin(steamId) PROFILE("TGNS.IsSteamIdAdmin")
	local result = Shine.Plugins.permissions:IsSteamIdInGroup(steamId, "fulladmin_group")
	return result
end

function TGNS.IsClientAdmin(client) PROFILE("TGNS.IsClientAdmin")
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdAdmin(steamId)
	end
	return result
end

function TGNS.IsSteamIdSM(steamId) PROFILE("TGNS.IsSteamIdSM")
	local result = Shine.Plugins.permissions:IsSteamIdInGroup(steamId, "sm_group")
	return result
end

function TGNS.IsPlayerSM(player) PROFILE("TGNS.IsPlayerSM")
	local client = TGNS.GetClient(player)
	local result = TGNS.IsClientSM(client)
	return result
end

function TGNS.IsClientSM(client) PROFILE("TGNS.IsClientSM")
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdSM(steamId)
	end
	return result
end

function TGNS.IsSteamIdStranger(steamId) PROFILE("TGNS.IsSteamIdStranger")
	local result = not TGNS.IsSteamIdSM(steamId) and not TGNS.HasSteamIdSignedPrimerWithGames(steamId)
	return result
end

function TGNS.IsPlayerStranger(player) PROFILE("TGNS.IsPlayerStranger")
	local client = TGNS.GetClient(player)
	local result = TGNS.IsClientStranger(client)
	return result
end

function TGNS.IsClientStranger(client) PROFILE("TGNS.IsClientStranger")
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdStranger(steamId)
	end
	return result
end

function TGNS.IsSteamIdPrimerOnly(steamId) PROFILE("TGNS.IsSteamIdPrimerOnly")
	local result = TGNS.HasSteamIdSignedPrimerWithGames(steamId) and not TGNS.IsSteamIdSM(steamId)
	return result
end

function TGNS.IsPrimerOnlyPlayer(player) PROFILE("TGNS.IsPrimerOnlyPlayer")
	local client = TGNS.GetClient(player)
	local result = TGNS.IsPrimerOnlyClient(client)
	return result
end

function TGNS.IsPrimerOnlyClient(client) PROFILE("TGNS.IsPrimerOnlyClient")
	local result = false
	if client ~= nil then
		local steamId = TGNS.GetClientSteamId(client)
		result = TGNS.IsSteamIdPrimerOnly(steamId)
	end
	return result
end

function TGNS.PlayerAction(client, action) PROFILE("TGNS.PlayerAction")
	local player = client:GetControllingPlayer()
	return action(player)
end

function TGNS.GetPlayerName(player) PROFILE("TGNS.GetPlayerName")
	local result = (player and player.GetName) and player:GetName() or ""
	return result
end

function TGNS.GetClientName(client) PROFILE("TGNS.GetClientName")
	local result = TGNS.PlayerAction(client, TGNS.GetPlayerName)
	return result
end

function TGNS.ClientAction(player, action) PROFILE("TGNS.ClientAction")
	local client = Server.GetOwner(player)
	if client then
		return action(client)
	end
end

function TGNS.GetClientSteamId(client) PROFILE("TGNS.GetClientSteamId")
	local result = client:GetUserId()
	return result
end

function TGNS.DoForClientsWithId(clients, clientAction) PROFILE("TGNS.DoForClientsWithId")
	TGNS.DoFor(clients, function(c)
		local steamId = TGNS.GetClientSteamId(c)
		if steamId ~= nil then
			clientAction(c, steamId)
		end
	end)
end

function TGNS.GetClientNameSteamIdCombo(client) PROFILE("TGNS.GetClientNameSteamIdCombo")
	local result = string.format("%s (%s)", TGNS.GetClientName(client), TGNS.GetClientSteamId(client))
	return result
end

function TGNS.GetIsClientVirtual(client) PROFILE("TGNS.GetIsClientVirtual")
	local result = client and client.GetIsVirtual and client:GetIsVirtual()
	return result
end

function TGNS.GetIsPlayerVirtual(player) PROFILE("TGNS.GetIsPlayerVirtual")
	local result = TGNS.GetIsClientVirtual(TGNS.GetClient(player))
	return result
end

function TGNS.DisconnectClient(client, reason) PROFILE("TGNS.DisconnectClient")
	pcall(function()
		client.DisconnectReason = reason
		Server.DisconnectClient(client, reason)
	end)
end

function TGNS.ElementIsFoundBeforeIndex(elements, element, index) PROFILE("TGNS.ElementIsFoundBeforeIndex")
	local result = false
	TGNS.DoFor(elements, function(e, i)
		if i <= index and e == element then
			result = true
			return true
		end
	end)
	return result
end

function TGNS.GetPlayerList() PROFILE("TGNS.GetPlayerList")
	local result = Shine.GetAllPlayers()
	TGNS.SortAscending(result, function(p) return p == nil and "" or string.lower(TGNS.GetPlayerName(p)) end)
	return result
end

function TGNS.GetPlayerCount() PROFILE("TGNS.GetPlayerCount")
	local result = Server.GetNumPlayersTotal()
	return result
end

function TGNS.AllPlayers(doThis) PROFILE("TGNS.AllPlayers")
	return function(client)
		local playerList = TGNS.GetPlayerList()
		TGNS.DoFor(playerList, function(p, index)
			doThis(p, client, index)
		end)
	end
end

function TGNS.GetClient(player) PROFILE("TGNS.GetClient")
	local result = Server.GetOwner(player)
	return result
end

function TGNS.GetPlayer(client) PROFILE("TGNS.GetPlayer")
	local result = client:GetControllingPlayer()
	return result
end

function TGNS.GetPlayers(clients) PROFILE("TGNS.GetPlayers")
	local result = {}
	TGNS.DoFor(clients, function(c) table.insert(result, TGNS.GetPlayer(c)) end)
	return result
end

function TGNS.GetClients(players) PROFILE("TGNS.GetClients")
	local result = {}
	TGNS.DoFor(players, function(p) table.insert(result, TGNS.GetClient(p)) end)
	return result
end

function TGNS.GetMatchingClients(playerList, predicate) PROFILE("TGNS.GetMatchingClients")
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

function TGNS.ClientIsOnPlayingTeam(client) PROFILE("TGNS.ClientIsOnPlayingTeam")
	return TGNS.PlayerIsOnPlayingTeam(TGNS.GetPlayer(client))
end

function TGNS.PlayerIsOnPlayingTeam(player) PROFILE("TGNS.PlayerIsOnPlayingTeam")
	local result = TGNS.IsGameplayTeamNumber(TGNS.GetPlayerTeamNumber(player))
	return result
end

function TGNS.GetPlayingClients(playerList) PROFILE("TGNS.GetPlayingClients")
	local result = TGNS.GetMatchingClients(playerList, function(c,p) return TGNS.PlayerIsOnPlayingTeam(p) end)
	return result
end

function TGNS.GetLastMatchingClient(playerList, predicate) PROFILE("TGNS.GetLastMatchingClient")
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

function TGNS.GetTeamClients(teamNumber, playerList) PROFILE("TGNS.GetTeamClients")
	local predicate = function(client, player) return player:GetTeamNumber() == teamNumber end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetSpectatorClients(playerList) PROFILE("TGNS.GetSpectatorClients")
	local predicate = function(client, player) return TGNS.IsPlayerSpectator(player) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetMarineClients(playerList) PROFILE("TGNS.GetMarineClients")
	local result = TGNS.GetTeamClients(kMarineTeamType, playerList)
	return result
end

function TGNS.GetReadyRoomClients(playerList) PROFILE("TGNS.GetReadyRoomClients")
	local result = TGNS.GetTeamClients(kTeamReadyRoom, playerList)
	return result
end

function TGNS.GetAlienClients(playerList) PROFILE("TGNS.GetAlienClients")
	local result = TGNS.GetTeamClients(kAlienTeamType, playerList)
	return result
end

function TGNS.GetReadyRoomPlayers(playerList) PROFILE("TGNS.GetReadyRoomPlayers")
	local result = TGNS.GetPlayers(TGNS.GetReadyRoomClients(playerList))
	return result
end

function TGNS.GetSpectatorPlayers(playerList) PROFILE("TGNS.GetSpectatorPlayers")
	local result = TGNS.GetPlayers(TGNS.GetSpectatorClients(playerList))
	return result
end

function TGNS.GetMarinePlayers(playerList) PROFILE("TGNS.GetMarinePlayers")
	local result = TGNS.GetPlayers(TGNS.GetMarineClients(playerList))
	return result
end

function TGNS.GetAlienPlayers(playerList) PROFILE("TGNS.GetAlienPlayers")
	local result = TGNS.GetPlayers(TGNS.GetAlienClients(playerList))
	return result
end

function TGNS.GetPlayerLocationName(player) PROFILE("TGNS.GetPlayerLocationName")
	local result = player:GetLocationName()
	return result
end

function TGNS.GetClientLocationName(client) PROFILE("TGNS.GetClientLocationName")
	return TGNS.PlayerAction(client, TGNS.GetPlayerLocationName)
end

function TGNS.GetStrangersClients(playerList) PROFILE("TGNS.GetStrangersClients")
	local predicate = function(client, player) return TGNS.IsClientStranger(client) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetPrimerOnlyClients(playerList) PROFILE("TGNS.GetPrimerOnlyClients")
	local predicate = function(client, player) return TGNS.IsPrimerOnlyClient(client) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetPrimerWithGamesClients(playerList) PROFILE("TGNS.GetPrimerWithGamesClients")
	local predicate = function(client, player) return TGNS.HasClientSignedPrimerWithGames(client) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetSmClients(playerList) PROFILE("TGNS.GetSmClients")
	local predicate = function(client, player) return TGNS.IsClientSM(client) end
	local result = TGNS.GetMatchingClients(playerList, predicate)
	return result
end

function TGNS.GetSumFor(numbers) PROFILE("TGNS.GetSumFor")
	local result = 0
	TGNS.DoFor(numbers, function(n) result = result + n end)
	return result
end

function TGNS.GetSum(operand1, operand2) PROFILE("TGNS.GetSum")
	local result = operand1 + operand2
	return result
end

function TGNS.GetSumUpTo(operand1, operand2, sumLimit) PROFILE("TGNS.GetSumUpTo")
	local sum = TGNS.GetSum(operand1, operand2)
	local result = sum <= sumLimit and sum or sumLimit
	return result
end

function TGNS.KickPlayer(player, disconnectReason, onPreKick) PROFILE("TGNS.KickPlayer")
	if player ~= nil then
		TGNS.KickClient(player:GetClient(), disconnectReason, onPreKick)
	end
end

function TGNS.StripWhitespace(s) PROFILE("TGNS.StripWhitespace")
	local result = s:gsub("%s+", "")
	return result
end

function TGNS.StringEqualsCaseInsensitiveAndWhitespaceInsensitive(s1, s2) PROFILE("TGNS.StringEqualsCaseInsensitiveAndWhitespaceInsensitive")
	local result = TGNS.StringEqualsCaseInsensitive(TGNS.StripWhitespace(s1), TGNS.StripWhitespace(s2))
	return result
end

function TGNS.StringEqualsCaseInsensitive(s1, s2) PROFILE("TGNS.StringEqualsCaseInsensitive")
	local result = string.lower(s1) == string.lower(s2)
	return result
end

function TGNS.GetPlayerMatchingName(name, team) PROFILE("TGNS.GetPlayerMatchingName")

	assert(type(name) == "string")

	local nameMatchCount = 0
	local match = nil

	local function Matches(player) PROFILE("Matches")
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
			local index = string.find(string.lower(playerName), string.lower(name), nil, true) // case insensitive partial match without pattern matching
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

function TGNS.GetPlayerMatchingSteamId(steamId, team) PROFILE("TGNS.GetPlayerMatchingSteamId")

	assert(type(steamId) == "number")

	local match = nil

	local function Matches(player) PROFILE("Matches")

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

function TGNS.GetClientByNs2Id(ns2Id) PROFILE("TGNS.GetClientByNs2Id")
	local result = Shine.GetClientByNS2ID(ns2Id)
	return result
end

function TGNS.GetClientById(clientId) PROFILE("TGNS.GetClientById")
	local result = Server.GetClientById(clientId)
	return result
end

function TGNS.GetPlayerByGameId(id, teamNumber) PROFILE("TGNS.GetPlayerByGameId")
	local result
	local client = Shine.GetClientByID(id)
	if client then
		local player = TGNS.GetPlayer(client)
		if teamNumber == nil or TGNS.GetPlayerTeamNumber(player) == teamNumber then
			result = player
		end
	end
	return result
end

function TGNS.GetPlayerMatching(id, team) PROFILE("TGNS.GetPlayerMatching")
	local idNum = tonumber(id)
	if idNum then
		local gameIdPlayer = TGNS.GetPlayerByGameId(idNum, team)
		local steamIdPlayer = TGNS.GetPlayerMatchingSteamId(idNum, team)
		return gameIdPlayer or steamIdPlayer
	elseif type(id) == "string" then
		return TGNS.GetPlayerMatchingName(id, team)
	end
end

function TGNS.GetTitleFromWebPageSource(source) PROFILE("TGNS.GetTitleFromWebPageSource")
	local result = nil
	local openingTag = "<title>"
	local closingTag = "</title>"
	local indexOfOpeningTag = TGNS.IndexOf(source, openingTag)
	if indexOfOpeningTag ~= -1 then
		local modName = TGNS.Substring(source, indexOfOpeningTag + string.len(openingTag))
		local indexOfClosingTag = TGNS.IndexOf(modName, closingTag)
		if indexOfClosingTag ~= -1 then
			modName = TGNS.Substring(modName, 1, indexOfClosingTag - 1)
			modName = StringTrim(modName)
			result = modName
		end
	end
	return result
end

function TGNS.UrlEncode(str) PROFILE("TGNS.UrlEncode")
  if (str) then
    str = string.gsub (str, "\n", "\r\n")
    str = string.gsub (str, "([^%w %-%_%.%~])",
        function (c) return string.format ("%%%02X", string.byte(c)) end)
    str = string.gsub (str, " ", "+")
  end
  return str
end

////////////////////////////////
// Intercept Network Messages //
////////////////////////////////

kTGNSNetworkMessageHooks = {}

function TGNS.RegisterNetworkMessageHook(messageName, func, priority) PROFILE("TGNS.RegisterNetworkMessageHook")
	local eventName = "kTGNSOn" .. messageName
	TGNS.RegisterEventHook(eventName , func, priority)
end

local originalOnNetworkMessage = {}

local function onNetworkMessage(messageName, ...) PROFILE("onNetworkMessage")
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

function TGNS.DisableUweGameReporting()
	ServerSponitor.OnEndMatch = function(serverSponitorSelf, winningTeam) end
	PlayerRanking.GetTrackServer = function(playerRankingSelf) return false end		
end

TGNS.ScheduleAction(1, function()
 	TGNS.Config = TGNSJsonFileTranscoder.DecodeFromFile("config://TGNS.json")
 	TGNS.ExecuteEventHooks("TGNSConfigLoaded")
end)

-- TGNS.ScheduleAction(2, function() Shared.Message(string.format("All: %s", TGNS.Join(TGNS.GetMapCycleMapNames(), ","))) end)
-- TGNS.ScheduleAction(3, function() Shared.Message(string.format("Voteable: %s", TGNS.Join(TGNS.GetVoteableMapNames(), ","))) end)
-- TGNS.ScheduleAction(4, function() Shared.Message(string.format("Mod: %s", TGNS.Join(TGNS.GetMapCycleModMapNames(), ","))) end)
-- TGNS.ScheduleAction(5, function() Shared.Message(string.format("Stock: %s", TGNS.Join(TGNS.GetMapCycleStockMapNames(), ","))) end)