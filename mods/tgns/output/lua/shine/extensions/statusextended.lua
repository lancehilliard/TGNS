local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	TGNS.ScheduleAction(10, function()
		local originalStatusFunc = Shine.Commands.sh_status and Shine.Commands.sh_status.Func or nil
		if originalStatusFunc then
			Shine.Commands.sh_status.Func = function(client)
				originalStatusFunc(client)
				ServerAdminPrint(client, string.format("Server address: %s", TGNS.Config.ServerAddress))
				ServerAdminPrint(client, "This is a TacticalGamer.com server. http://rr.tacticalgamer.com/Community")
			end
		end
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("statusextended", Plugin )