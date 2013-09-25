local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	TGNS.ReplaceClassMethod("PlayerRanking", "GetTrackServer", function()
		return not GetServerContainsBots()
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("uweranking", Plugin )