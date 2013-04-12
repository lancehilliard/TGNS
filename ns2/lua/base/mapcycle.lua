//DAK loader/Base Config

DAK.mapcycle = { }

local mapCycleFileName = "config://MapCycle.json"
	
local function LoadMapCycle()

	local defaultConfig = { maps = { "ns2_docking", "ns2_descent", "ns2_summit", "ns2_tram", "ns2_veil" }, time = 30, mode = "order", mods = { "5f4f178" } }
	DAK:WriteDefaultConfigFile(mapCycleFileName, defaultConfig)
	DAK.mapcycle = DAK:LoadConfigFile(mapCycleFileName) or defaultConfig
	assert(type(DAK.mapcycle.time) == 'number')
	assert(type(DAK.mapcycle.maps) == 'table')
	
end

LoadMapCycle()

local function SaveMapCycle()
	DAK:SaveConfigFile(mapCycleFileName, DAK.mapcycle)
end	

local function GetMapName(map)
	if type(map) == "table" and map.map ~= nil then
		return map.map
	end
	return map
end

function MapCycle_GetMapMeetsPlayerRequirements(map)
	local CurPlayers = Server.GetNumPlayers()
	for i = #DAK.mapcycle.maps, 1, -1 do
		if GetMapName(DAK.mapcycle.maps[i]) == map then
			if (tonumber(DAK.mapcycle.maps[i].minPlayers) or 0) <= CurPlayers and
				(tonumber(DAK.mapcycle.maps[i].maxPlayers) or 99) >= CurPlayers then
				return true
			end
			break
		end
	end
	if DAK.mapcycle.votemaps ~= nil and #DAK.mapcycle.votemaps > 0 then
		for i = #DAK.mapcycle.votemaps, 1, -1 do
			if GetMapName(DAK.mapcycle.votemaps[i]) == map then
				if (tonumber(DAK.mapcycle.votemaps[i].minPlayers) or 0) <= CurPlayers and
					(tonumber(DAK.mapcycle.votemaps[i].maxPlayers) or 99) >= CurPlayers then
					return true
				end
				break
			end
		end
	end
	return false
end

function MapCycle_VerifyMapInCycle(mapName)
	if DAK.mapcycle and DAK.mapcycle.maps and mapName then
		for i = 1, #DAK.mapcycle.maps do
			if GetMapName(DAK.mapcycle.maps[i]):upper() == mapName:upper() then
				return true
			end
		end
	end
	if DAK.mapcycle and DAK.mapcycle.votemaps and mapName then
		for i = 1, #DAK.mapcycle.votemaps do
			if GetMapName(DAK.mapcycle.votemaps[i]):upper() == mapName:upper() then
				return true
			end
		end
	end
	return false
end

function MapCycle_GetMapCycleTime()
	return DAK.mapcycle.time
end

function MapCycle_GetMapCycleArray()
	return DAK.mapcycle.maps or nil
end

function MapCycle_GetVoteMapCycleArray()
	return DAK.mapcycle.votemaps or nil
end

function MapCycle_VerifyMapName(mapName)
	local matchingFiles = { }
	Shared.GetMatchingFileNames("maps/*.level", false, matchingFiles)

	if mapName ~= nil then
		for _, mapFile in pairs(matchingFiles) do
			local _, _, filename = string.find(mapFile, "maps/(.*).level")
			if mapName:upper() == string.format(filename):upper() then
				return true
			end
		end
	end
	
	//Map file not available currently, check mapcycle for map and corresponding mod.  If no mod, dont change
	
	for i = #DAK.mapcycle.maps, 1, -1 do
		if GetMapName(DAK.mapcycle.maps[i]) == mapName then
			if type(DAK.mapcycle.maps[i]) == "table" and type(DAK.mapcycle.maps[i].mods) == "table" then
				//Mods table is set, map is probably valid
				return true
			end
			break
		end
	end
	assert(false)
	return false
end

function MapCycle_GetMapCycle()
	return DAK.mapcycle
end

function MapCycle_SetMapCycle(newCycle)
	DAK.mapcycle = newCycle
	SaveMapCycle()
end

function MapCycle_ChangeToMap(mapName)
	local mods = { }
	
	// Copy the global defined mods.
	if type(DAK.mapcycle.mods) == "table" then
		table.copy(DAK.mapcycle.mods, mods, true)
	end
	
	local map = nil
		
	for i = #DAK.mapcycle.maps, 1, -1 do
		if GetMapName(DAK.mapcycle.maps[i]) == mapName then
			map = DAK.mapcycle.maps[i]
			break
		end
	end
	
	if map == nil and DAK.mapcycle.votemaps ~= nil and #DAK.mapcycle.votemaps > 0 then
		for i = #DAK.mapcycle.votemaps, 1, -1 do
			if GetMapName(DAK.mapcycle.votemaps[i]) == mapName then
				map = DAK.mapcycle.votemaps[i]
				break
			end
		end
	end
	
	if map ~= nil then //Lookup map mods if applic
		if type(map) == "table" and type(map.mods) == "table" then
			table.copy(map.mods, mods, true)
		end
	end
	
	// Verify the map exists on the file system.
	// Need to disable this because of map mods, meh
	local found = MapCycle_VerifyMapName(mapName)

	if found then
		DAK:SaveSettings()
		Server.StartWorld(mods, mapName)
	end
end

function MapCycle_GetNextMapInCycle()
	local currentMap = Shared.GetMapName()
	local numMaps = #DAK.mapcycle.maps
	local map = nil
	
	if numMaps == 0 then
		return map
	end
	
	if DAK.mapcycle.mode == "random" then
	
		// Choose a random map to switch to.
		local mapIndex = math.random(1, numMaps)
		map = DAK.mapcycle.maps[mapIndex]
		
		// Don't change to the map we're currently playing.
		if GetMapName(map) == currentMap then
		
			for i = 1, numMaps do
				mapIndex = mapIndex + 1
				if mapIndex > numMaps then
					mapIndex = 1
				end
				if MapCycle_GetMapMeetsPlayerRequirements(GetMapName(DAK.mapcycle.maps[mapIndex])) then
					map = DAK.mapcycle.maps[mapIndex]
					break
				end
			end
			
		end
		
	else
	
		// Go to the next map in the cycle. We need to search backwards
		// in case the same map has been specified multiple times.
		local mapIndex = 0
		
		for i = #DAK.mapcycle.maps, 1, -1 do
			if GetMapName(DAK.mapcycle.maps[i]) == currentMap then
				mapIndex = i
				break
			end
		end
		
		for i = 1, numMaps do
			mapIndex = mapIndex + 1
			if mapIndex > numMaps then
				mapIndex = 1
			end
			if MapCycle_GetMapMeetsPlayerRequirements(GetMapName(DAK.mapcycle.maps[mapIndex])) then
				map = DAK.mapcycle.maps[mapIndex]
				break
			end
		end
		
	end
	
	return map
end

function MapCycle_CycleMap()

	if DAK:ExecuteEventHooks("OverrideMapChange") then
		return false
	end

	local currentMap = Shared.GetMapName()
	local mapName = GetMapName(MapCycle_GetNextMapInCycle())
	
	if mapName == nil then
		Shared.Message("No maps in the map cycle")
		return false
	end
	
	if mapName ~= currentMap then
		MapCycle_ChangeToMap(mapName)
	end
	
end

function MapCycle_TestCycleMap()

	if DAK:ExecuteEventHooks("CheckMapChange") then
		return false
	end

	// time is stored as minutes so convert to seconds.
	if Shared.GetTime() < (DAK.mapcycle.time * 60) then
		// We haven't been on the current map for long enough.
		return false
	end
	
	return true
	
end

local function OnCommandCycleMap(client)

	if client == nil or client:GetIsLocalClient() then
		MapCycle_CycleMap()
	end
	
end

local function OnCommandChangeMap(client, mapName)
	
	if client == nil or client:GetIsLocalClient() then
		MapCycle_ChangeToMap(mapName)
	end
	
end

Event.Hook("Console_changemap", OnCommandChangeMap)
Event.Hook("Console_cyclemap", OnCommandCycleMap)