local steamIdsWhichStartedGame = {}

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("GameStarted", function()
		steamIdsWhichStartedGame = {}
		TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c) table.insert(steamIdsWhichStartedGame, TGNS.GetClientSteamId(c)) end)
	end)
    return true
end

function Plugin:EndGame(gamerules, winningTeam)
	local clientsWhichWereInTheGameAtStartAndEnd = {}
	TGNS.DoForClientsWithId(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c, steamId)
		if TGNS.Has(steamIdsWhichStartedGame, steamId) then
			table.insert(clientsWhichWereInTheGameAtStartAndEnd, c)
		end
	end)
	TGNS.ExecuteEventHooks("FullGamePlayed", clientsWhichWereInTheGameAtStartAndEnd, winningTeam)
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("fullgameplayed", Plugin )