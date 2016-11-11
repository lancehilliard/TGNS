Plugin.HasConfig = false
-- Plugin.ConfigName = "restartwhenempty.json"
local clientConnected

function Plugin:ClientConfirmConnect(client)
	clientConnected = true
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

    TGNS.ScheduleAction(5, function()
	    TGNS.ScheduleAction(TGNS.ConvertMinutesToSeconds(Shine.Plugins.mapvote.MapCycle.time - 1), function()
			if not clientConnected and TGNS.ConvertSecondsToHours(TGNS.GetSecondsSinceServerProcessStarted()) > 2 then
				TGNS.RestartServerProcess()
			end
	    end)
    end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end