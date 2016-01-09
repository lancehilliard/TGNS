local Plugin = {}
local md = TGNSMessageDisplayer.Create()

function Plugin:CreateCommands()
	local sh_loghttp = self:BindCommand( "sh_loghttp", nil, function(client)
		TGNS.LogHttp = not TGNS.LogHttp
		md:ToClientConsole(client, string.format("TGNS.LogHttp: %s", TGNS.LogHttp == true))
	end)
	sh_loghttp:Help( "Log HTTP requests for map duration. Expensive." )
end


function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()
    TGNS.ScheduleAction(5, function()
    	if TGNS.GetSecondsSinceServerProcessStarted() < 30 then
    		TGNS.SwitchToMap(TGNS.GetCurrentMapName())
    	end
    end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("hidefullmodlist", Plugin )