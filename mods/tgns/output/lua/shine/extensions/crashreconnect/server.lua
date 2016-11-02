Plugin.HasConfig = false
-- Plugin.ConfigName = "crashreconnect.json"

function Plugin:ClientConfirmConnect(client)
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end