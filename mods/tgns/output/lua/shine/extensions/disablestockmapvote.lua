local md

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create()
    TGNS.ScheduleAction(5, function()
		Server.HookNetworkMessage("VoteChangeMap", function(client)
			local player = TGNS.GetPlayer(client)
			md:ToPlayerNotifyError(player, "Built-in mapvoting is available when server mods fail to load.")
			md:ToPlayerNotifyError(player, "Server mods loaded successfully, so vote starts are automated.")
		end)
    end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("disablestockmapvote", Plugin )