//DAK Loader/Base Config

if Server then

	Script.Load("lua/dkjson.lua")

	local mapCycleFileName = "config://MapCycle.json"
	local DAKMapCycle = { }
		
    local function LoadMapCycle()
    
        Shared.Message("Loading " .. mapCycleFileName)
		
		local configFile = io.open(mapCycleFileName, "r")
        if configFile then
            local fileContents = configFile:read("*all")
            DAKMapCycle = json.decode(fileContents) or { maps = { "ns2_docking", "ns2_summit", "ns2_tram", "ns2_veil" }, time = 30, mode = "order", mods = { "5f4f178" } }
			io.close(configFile)
		else
		    local defaultConfig = { maps = { "ns2_docking", "ns2_summit", "ns2_tram", "ns2_veil" }, time = 30, mode = "order", mods = { "5f4f178" } }
			DAKMapCycle = defaultConfig
        end
		assert(type(DAKMapCycle.time) == 'number')
		assert(type(DAKMapCycle.maps) == 'table')
        
    end
	
	LoadMapCycle()
	
	local function SaveMapCycle()
		local configFile = io.open(mapCycleFileName, "w+")
		configFile:write(json.encode(DAKMapCycle, { indent = true, level = 1 }))
		io.close(configFile)
	end	
	
	local function GetMapName(map)
		if type(map) == "table" and map.map ~= nil then
			return map.map
		end
		return map
	end
	
	function MapCycle_MeetsPlayerRequirements(map)
		local CurPlayers = Server.GetNumPlayers()
		for i = #DAKMapCycle.maps, 1, -1 do
			if GetMapName(DAKMapCycle.maps[i]) == map then
				if (tonumber(DAKMapCycle.maps[i].minPlayers) or 0) <= CurPlayers and
					(tonumber(DAKMapCycle.maps[i].maxPlayers) or 99) >= CurPlayers then
					return true
				end
				break
			end
		end
		if DAKMapCycle.votemaps ~= nil and #DAKMapCycle.votemaps > 0 then
			for i = #DAKMapCycle.votemaps, 1, -1 do
				if GetMapName(DAKMapCycle.votemaps[i]) == map then
					if (tonumber(DAKMapCycle.votemaps[i].minPlayers) or 0) <= CurPlayers and
						(tonumber(DAKMapCycle.votemaps[i].maxPlayers) or 99) >= CurPlayers then
						return true
					end
					break
				end
			end
		end
		return false
	end
	
	function MapCycle_VerifyMapInCycle(mapName)
		if DAKMapCycle and DAKMapCycle.maps and mapName then
			for i = 1, #DAKMapCycle.maps do
				if GetMapName(DAKMapCycle.maps[i]):upper() == mapName:upper() then
					return true
				end
			end
		end
		if DAKMapCycle and DAKMapCycle.votemaps and mapName then
			for i = 1, #DAKMapCycle.votemaps do
				if GetMapName(DAKMapCycle.votemaps[i]):upper() == mapName:upper() then
					return true
				end
			end
		end
		return false
	end
	
	function MapCycle_GetMapCycleTime()
		return DAKMapCycle.time
	end
	
	function MapCycle_GetMapCycleArray()
		return DAKMapCycle.maps or nil
	end
	
	function MapCycle_GetVoteMapCycleArray()
		return DAKMapCycle.votemaps or nil
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
		
		for i = #DAKMapCycle.maps, 1, -1 do
			if GetMapName(DAKMapCycle.maps[i]) == mapName then
				if type(DAKMapCycle.maps[i]) == "table" and type(DAKMapCycle.maps[i].mods) == "table" then
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
		return DAKMapCycle
	end
	
	function MapCycle_SetMapCycle(newCycle)
		DAKMapCycle = newCycle
		SaveMapCycle()
	end
	
	function MapCycle_ChangeToMap(mapName)
		local mods = { }
		
		// Copy the global defined mods.
		if type(DAKMapCycle.mods) == "table" then
			table.copy(DAKMapCycle.mods, mods, true)
		end
		
		local map = nil
			
		for i = #DAKMapCycle.maps, 1, -1 do
			if GetMapName(DAKMapCycle.maps[i]) == mapName then
				map = DAKMapCycle.maps[i]
				break
			end
		end
		
		if map == nil and DAKMapCycle.votemaps ~= nil and #DAKMapCycle.votemaps > 0 then
			for i = #DAKMapCycle.votemaps, 1, -1 do
				if GetMapName(DAKMapCycle.votemaps[i]) == mapName then
					map = DAKMapCycle.votemaps[i]
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
			Server.StartWorld(mods, mapName)
		end
	end
	
	function MapCycle_GetNextMapInCycle()
		local currentMap = Shared.GetMapName()
		local numMaps = #DAKMapCycle.maps
		local map = nil
		
		if numMaps == 0 then
			return map
		end
		
		if DAKMapCycle.mode == "random" then
		
			// Choose a random map to switch to.
			local mapIndex = math.random(1, numMaps)
			map = DAKMapCycle.maps[mapIndex]
			
			// Don't change to the map we're currently playing.
			if GetMapName(map) == currentMap then
			
				for i = 1, numMaps do
					mapIndex = mapIndex + 1
					if mapIndex > numMaps then
						mapIndex = 1
					end
					if MapCycle_MeetsPlayerRequirements(GetMapName(DAKMapCycle.maps[mapIndex])) then
						map = DAKMapCycle.maps[mapIndex]
						break
					end
				end
				
			end
			
		else
		
			// Go to the next map in the cycle. We need to search backwards
			// in case the same map has been specified multiple times.
			local mapIndex = 0
			
			for i = #DAKMapCycle.maps, 1, -1 do
				if GetMapName(DAKMapCycle.maps[i]) == currentMap then
					mapIndex = i
					break
				end
			end
			
			for i = 1, numMaps do
				mapIndex = mapIndex + 1
				if mapIndex > numMaps then
					mapIndex = 1
				end
				if MapCycle_MeetsPlayerRequirements(GetMapName(DAKMapCycle.maps[mapIndex])) then
					map = DAKMapCycle.maps[mapIndex]
					break
				end
			end
			
		end
		
		return map
	end
	
	function MapCycle_CycleMap()

		if DAKExecuteEventHooks("kDAKOverrideMapChange") then
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
	
		if DAKExecuteEventHooks("kDAKCheckMapChange") then
			return false
		end

		// time is stored as minutes so convert to seconds.
		if Shared.GetTime() < (DAKMapCycle.time * 60) then
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
	
end