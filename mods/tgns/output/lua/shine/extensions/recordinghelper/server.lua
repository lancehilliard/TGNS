Plugin.HasConfig = false
-- Plugin.ConfigName = "recordinghelper.json"

local function sendRecordingBoundaryToPlayer(player, duration, boundaryName, secondsSinceEpoch)
	if not TGNS.GetIsPlayerVirtual(player) then
		TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.recordinghelper.RECORDING_BOUNDARY, {b=boundaryName,d=duration,t=TGNS.GetPlayerTeamName(player),p=TGNS.GetPlayerName(player),s=secondsSinceEpoch})
	end
end

function Plugin:ClientConnect(client)
	sendRecordingBoundaryToPlayer(TGNS.GetPlayer(client), 0, "prep")
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

	TGNS.RegisterEventHook("GameCountdownStarted", function(secondsSinceEpoch)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p) sendRecordingBoundaryToPlayer(p, 0, "start", secondsSinceEpoch) end)
	end)

 	TGNS.RegisterEventHook("FullGamePlayed", function(clients, winningTeam, gameDurationInSeconds, gameStartTimeInSeconds)
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM - 1, function()
			TGNS.DoFor(TGNS.GetPlayerList(), function(p) sendRecordingBoundaryToPlayer(p, gameDurationInSeconds, "end", gameStartTimeInSeconds) end)
		end)
 	end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end