Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSMessageDisplayer.lua")

local NEXTMAP_CHECK_INTERVAL_IN_SECONDS = 90
local ADVISORY_INTERVAL_IN_MINUTES = 1
local MAPCHANGE_ANNOUNCEMENT_INTERVAL_IN_SECONDS = 4
local MAPCHANGE_DELAY_IN_SECONDS = 15
local ADVISORY_INTERVAL_IN_SECONDS = TGNS.ConvertMinutesToSeconds(ADVISORY_INTERVAL_IN_MINUTES)

local msg
local mapName

local function MapIsNsMap(mapName)
	local result = not (TGNS.Contains(mapName, "_co_") or TGNS.Contains(mapName, "_ls_"))
	return result
end

local function AnnounceMapChange(nextMapName)
	msg:ToAllChat("The server will now change to an NS map (NSi is out preferred gameplay mode).")
	TGNS.ScheduleAction(MAPCHANGE_ANNOUNCEMENT_INTERVAL_IN_SECONDS, AnnounceMapChange)
end

local function CheckNextMap()
	TGNS.ScheduleAction(NEXTMAP_CHECK_INTERVAL_IN_SECONDS, CheckNextMap)
	local nextMapName = TGNS.GetNextMapName()
	if MapIsNsMap(nextMapName) then
		AnnounceMapChange(nextMapName)
		TGNS.ScheduleAction(MAPCHANGE_DELAY_IN_SECONDS, function() TGNS.SwitchToMap(nextMapName) end)
	end
end

local function AdvisePlayers()
	TGNS.ScheduleAction(ADVISORY_INTERVAL_IN_SECONDS, AdvisePlayers)
	local message = string.format("This server changes immediately to NS when enough players join.")
	msg:ToAllChat(message)
end

TGNS.RegisterEventHook("OnPluginInitialized", function()
	msg = TGNSMessageDisplayer.Create()
	mapName = TGNS.ToLower(TGNS.GetCurrentMapName())
	if not MapIsNsMap(mapName) then
		TGNS.ScheduleAction(ADVISORY_INTERVAL_IN_SECONDS, AdvisePlayers)
		TGNS.ScheduleAction(NEXTMAP_CHECK_INTERVAL_IN_SECONDS, CheckNextMap)
	end
end)