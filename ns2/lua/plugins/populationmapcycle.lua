Script.Load("lua/TGNSCommon.lua")

local autoMapChangeDelayInSeconds = 30
local minimumMapDurationInMinutes = 30
local minimumMapDurationInSeconds = minimumMapDurationInMinutes * 60
local mapDatas = {}
//table.insert(mapDatas, { name = "ns2_eclipse_beta", min = 16 })
//table.insert(mapDatas, { name = "ns2_tanith_beta", min = 16 })
table.insert(mapDatas, { name = "ns2_turtle", min = 16 })
table.insert(mapDatas, { name = "ns2_descent", min = 14 })
table.insert(mapDatas, { name = "ns2_jambi", min = 14 })
table.insert(mapDatas, { name = "ns2_mineshaft", min = 14 })
table.insert(mapDatas, { name = "ns2_docking", min = 12 })
table.insert(mapDatas, { name = "ns2_refinery", min = 12 })
table.insert(mapDatas, { name = "ns2_summit", min = 0 })
table.insert(mapDatas, { name = "ns2_tram", min = 0 })
table.insert(mapDatas, { name = "ns2_veil", min = 0 })
//table.insert(mapDatas, { name = "ns2_last_stand", max = 12 })

PopulationMapCycle = {}

local function GetNextMapData()
	local result = TGNS.GetFirst(mapDatas)
	TGNS.DoForReverse(mapDatas, function(mapData, index)
		if mapData.name == Shared.GetMapName() then
			return true
		else
			local minPlayers = mapData.min ~= nil and mapData.min or 0
			local maxPlayers = mapData.max ~= nil and mapData.max or math.huge
			local playersCount = Server.GetNumPlayers()
			if playersCount >= minPlayers and playersCount < maxPlayers then
				result = mapData
			end
		end
	end)
	return result
end

local function RotateMap()
	local nextMapData = GetNextMapData()
	MapCycle_ChangeToMap(nextMapData.name)
end
TGNS.ScheduleAction(minimumMapDurationInSeconds, function() if not TGNS.IsGameInProgress() then RotateMap() end end)

local function OnGameEnd(self, winningTeam)
	if Shared.GetTime() >= minimumMapDurationInSeconds then
		TGNS.ScheduleAction(autoMapChangeDelayInSeconds, RotateMap)
	end
end
TGNS.RegisterEventHook("OnGameEnd", OnGameEnd)

function PopulationMapCycle.GetMinimumMapDurationInMinutes()
	return minimumMapDurationInMinutes
end

function PopulationMapCycle.GetNextMapName()
	local nextMapData = GetNextMapData()
	local result = nextMapData.name
	return result
end

TGNS.RegisterCommandHook("Console_sv_rotatemap", RotateMap, "Advance the map to the next in the cycle.")
