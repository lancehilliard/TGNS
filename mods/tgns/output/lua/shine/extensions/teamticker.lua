-- local md

-- local Plugin = {}

-- function Plugin:Initialise()
--     self.Enabled = true
--     md = TGNSMessageDisplayer.Create("TEAM")
-- 	TGNS.RegisterEventHook("PlayerLocationChanged", function(player, locationName)
-- 		md:ToTeamTickerInfo(TGNS.GetPlayerTeamNumber(player), string.format("%s -> %s", TGNS.GetPlayerName(player), locationName))
-- 	end)

--     return true
-- end

-- function Plugin:Cleanup()
--     --Cleanup your extra stuff like timers, data etc.
--     self.BaseClass.Cleanup( self )
-- end

-- Shine:RegisterExtension("teamticker", Plugin )