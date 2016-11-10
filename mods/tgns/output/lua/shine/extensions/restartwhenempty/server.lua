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
				local serverName = TGNS.Config.ServerSimpleName
				local url = string.format("%s&s=%s&c=%s&t=1&a=false", TGNS.Config.ServerCommandEndpointBaseUrl, TGNS.UrlEncode(serverName), TGNS.UrlEncode("sh_warnrestart"))
				TGNS.DebugPrint("restart url: " .. tostring(url))
				TGNS.GetHttpAsync(url, function(responseJson)
					local response = json.decode(responseJson) or {}
					if not response.success then
						TGNS.DebugPrint(string.format("restartwhenempty ERROR: Unable to request restart. msg: %s | response: %s | stacktrace: %s | url: %s", response.msg, responseJson, response.stacktrace, url))
					end
				end)
			end
	    end)
    end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end