Plugin.HasConfig = false
-- Plugin.ConfigName = "gorgetunnelhelper.json"

function Plugin:Initialise()
    self.Enabled = true

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end