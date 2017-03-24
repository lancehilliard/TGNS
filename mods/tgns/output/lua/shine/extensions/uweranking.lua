local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
 --    local originalPlayerRankingGetTrackServer
	-- originalPlayerRankingGetTrackServer = TGNS.ReplaceClassMethod("PlayerRanking", "GetTrackServer", function(playerRankingSelf)
	-- 	return originalPlayerRankingGetTrackServer(playerRankingSelf) and not GetServerContainsBots()
	-- end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("uweranking", Plugin )