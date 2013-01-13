//DAK Loader/Base Config

if Server then

	Script.Load("lua/dkjson.lua")

	local mapCycleFileName = "config://MapCycle.json"
		
    local function LoadMapCycle()
    
        Shared.Message("Loading " .. mapCycleFileName)
		
		local configFile = io.open(mapCycleFileName, "r")
        if configFile then
            local fileContents = configFile:read("*all")
            kDAKMapCycle = json.decode(fileContents) or { maps = { "ns2_docking", "ns2_summit", "ns2_tram", "ns2_veil" }, time = 30, mode = "order", mods = { "5f4f178" } }
			io.close(configFile)
		else
		    local defaultConfig = { maps = { "ns2_docking", "ns2_summit", "ns2_tram", "ns2_veil" }, time = 30, mode = "order", mods = { "5f4f178" } }
			kDAKMapCycle = defaultConfig
        end
		assert(type(kDAKMapCycle.time) == 'number')
		assert(type(kDAKMapCycle.maps) == 'table')
        
    end
	
	LoadMapCycle()
	
	local function SaveMapCycle()
		local configFile = io.open(mapCycleFileName, "w+")
		configFile:write(json.encode(kDAKMapCycle, { indent = true, level = 1 }))
		io.close(configFile)
	end	
	
	local function GetMapName(map)
		if type(map) == "table" and map.map ~= nil then
			return map.map
		end
		return map
	end
	
	function MapCycle_MeetsPlayerRequirements(map)
		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		for i = #kDAKMapCycle.maps, 1, -1 do
			if GetMapName(kDAKMapCycle.maps[i]) == map then
				if (tonumber(kDAKMapCycle.maps[i].minPlayers) or 0) <= playerRecords:GetSize() and
					(tonumber(kDAKMapCycle.maps[i].maxPlayers) or 99) >= playerRecords:GetSize() then
					return true
				end
				break
			end
		end
		if kDAKMapCycle.votemaps ~= nil and #kDAKMapCycle.votemaps > 0 then
			for i = #kDAKMapCycle.votemaps, 1, -1 do
				if GetMapName(kDAKMapCycle.votemaps[i]) == map then
					if (tonumber(kDAKMapCycle.votemaps[i].minPlayers) or 0) <= playerRecords:GetSize() and
						(tonumber(kDAKMapCycle.votemaps[i].maxPlayers) or 99) >= playerRecords:GetSize() then
						return true
					end
					break
				end
			end
		end
		return false
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
		
		for i = #kDAKMapCycle.maps, 1, -1 do
			if GetMapName(kDAKMapCycle.maps[i]) == mapName then
				if type(kDAKMapCycle.maps[i]) == "table" and type(kDAKMapCycle.maps[i].mods) == "table" then
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
		return kDAKMapCycle
	end
	
	function MapCycle_SetMapCycle(newCycle)
		kDAKMapCycle = newCycle
		SaveMapCycle()
	end
	
	function MapCycle_ChangeToMap(mapName)
		local mods = { }
		
		// Copy the global defined mods.
		if type(kDAKMapCycle.mods) == "table" then
			table.copy(kDAKMapCycle.mods, mods, true)
		end
		
		local map = nil
			
		for i = #kDAKMapCycle.maps, 1, -1 do
			if GetMapName(kDAKMapCycle.maps[i]) == mapName then
				map = kDAKMapCycle.maps[i]
				break
			end
		end
		
		if map == nil and kDAKMapCycle.votemaps ~= nil and #kDAKMapCycle.votemaps > 0 then
			for i = #kDAKMapCycle.votemaps, 1, -1 do
				if GetMapName(kDAKMapCycle.votemaps[i]) == mapName then
					map = kDAKMapCycle.votemaps[i]
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
		local numMaps = #kDAKMapCycle.maps
		local map = nil
		
		if numMaps == 0 then
			return map
		end
		
		if kDAKMapCycle.mode == "random" then
		
			// Choose a random map to switch to.
			local mapIndex = math.random(1, numMaps)
			map = kDAKMapCycle.maps[mapIndex]
			
			// Don't change to the map we're currently playing.
			if GetMapName(map) == currentMap then
			
				for i = 1, numMaps do
					mapIndex = mapIndex + 1
					if mapIndex > numMaps then
						mapIndex = 1
					end
					if MapCycle_MeetsPlayerRequirements(GetMapName(kDAKMapCycle.maps[mapIndex])) then
						map = kDAKMapCycle.maps[mapIndex]
						break
					end
				end
				
			end
			
		else
		
			// Go to the next map in the cycle. We need to search backwards
			// in case the same map has been specified multiple times.
			local mapIndex = 0
			
			for i = #kDAKMapCycle.maps, 1, -1 do
				if GetMapName(kDAKMapCycle.maps[i]) == currentMap then
					mapIndex = i
					break
				end
			end
			
			for i = 1, numMaps do
				mapIndex = mapIndex + 1
				if mapIndex > numMaps then
					mapIndex = 1
				end
				if MapCycle_MeetsPlayerRequirements(GetMapName(kDAKMapCycle.maps[mapIndex])) then
					map = kDAKMapCycle.maps[mapIndex]
					break
				end
			end
			
		end
		
		return map
	end
	
	function MapCycle_CycleMap()

		if DAKExecuteEventHooks(kDAKOverrideMapChange) then
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
	
		if DAKExecuteEventHooks(kDAKCheckMapChange) then
			return false
		end

		// time is stored as minutes so convert to seconds.
		if Shared.GetTime() < (kDAKMapCycle.time * 60) then
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