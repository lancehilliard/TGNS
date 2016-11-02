Plugin.HasConfig = false
-- Plugin.ConfigName = "everysecond.json"

function Plugin:Initialise()
    self.Enabled = true

    -- self:CreateCommands()
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end