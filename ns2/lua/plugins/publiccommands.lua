Script.Load("lua/TGNSCommon.lua")

// constants used to look up command string in DAK.config.publiccommands.Commands table
local TIMELEFTCOMMAND = "timeleft"
local NEXTMAPCOMMAND = "nextmap"

//////////////
// Timeleft //
//////////////

local timeleftThrottle = 0
local function OnCommandTimeleft(client)
	if Shared.GetTime() - timeleftThrottle > DAK.config.publiccommands.Commands[TIMELEFTCOMMAND].throttle then
		timeleftThrottle = Shared.GetTime()
		for _, player in pairs(TGNS.GetPlayerList()) do
			if player ~= nil then
				chatMessage = string.sub(string.format("%.1f Minutes Remaining.", math.max(0,((MapCycle_GetMapCycleTime() * 60) - Shared.GetTime())/60)), 1, kMaxChatLength)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			end
		end
	end
	
end

// This command is already defined by the mapvote plugin.  If mapvote is in the plugin list, don't hook it again.
if DAK.config.publiccommands.Commands[TIMELEFTCOMMAND] and not TGNS.IsPluginEnabled("mapvote") then
	Event.Hook("Console_" .. DAK.config.publiccommands.Commands[TIMELEFTCOMMAND].command,               OnCommandTimeleft)
end

/////////////
// Nextmap //
/////////////

local nextmapThrottle = 0
local function GetMapName(map)
	if type(map) == "table" and map.map ~= nil then
		return map.map
	end
	return map
end

local function OnCommandNextMap(client)

	if Shared.GetTime() - nextmapThrottle > DAK.config.publiccommands.Commands[NEXTMAPCOMMAND].throttle then
		nextmapThrottle = Shared.GetTime()
		for _, player in pairs(TGNS.GetPlayerList()) do
			if player ~= nil then
				local mapname = GetMapName(MapCycle_GetNextMapInCycle())
				if mapname ~= nil then
					chatMessage = string.sub(string.format("Next map: %s", mapname), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
			end
		end
	end
	
end

if DAK.config.publiccommands.Commands[NEXTMAPCOMMAND] then
	Event.Hook("Console_" .. DAK.config.publiccommands.Commands[NEXTMAPCOMMAND].command,               OnCommandNextMap)
end

///////////////////
// Hook for chat //
///////////////////

local function OnChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)

	if client and steamId and steamId ~= 0 then
		// Timeleft
		if DAK.config.publiccommands.Commands[TIMELEFTCOMMAND] and not DAK.config.loader.PluginsList["mapvote"] and
			message == DAK.config.publiccommands.Commands[TIMELEFTCOMMAND].command then
			OnCommandTimeleft(client)
		end
		
		// Nextmap
		if DAK.config.publiccommands.Commands[NEXTMAPCOMMAND] and message == DAK.config.publiccommands.Commands[NEXTMAPCOMMAND].command then
			OnCommandNextMap(client)
		end
	end

end

TGNS.RegisterEventHook("OnClientChatMessage", OnChatMessage)

local function OnGameEnd()
	OnCommandNextMap()
	OnCommandTimeleft()
end
TGNS.RegisterEventHook("OnGameEnd", function() TGNS.ScheduleAction(8, OnGameEnd) end)