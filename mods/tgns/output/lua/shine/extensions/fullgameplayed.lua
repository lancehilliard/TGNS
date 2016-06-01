local steamIdsWhichStartedGameAsPlayers = {}
local steamIdsWhichStartedGameAsSpectators = {}
local steamIdsWhichStartedGameAsCommanders = {}
local gameStartTimeInSeconds = 0

local function getRecentCommanderClients()
	local result = TGNS.Where(TGNS.GetClientList(), function(c) return Shine.Plugins.communityslots and Shine.Plugins.communityslots.IsClientRecentCommander and Shine.Plugins.communityslots:IsClientRecentCommander(c) end)
	return result
end

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
		steamIdsWhichStartedGameAsPlayers = {}
		steamIdsWhichStartedGameAsSpectators = {}
		steamIdsWhichStartedGameAsCommanders = {}
		gameStartTimeInSeconds = secondsSinceEpoch
		local playerList = TGNS.GetPlayerList()
		TGNS.DoFor(TGNS.GetPlayingClients(playerList), function(c) table.insert(steamIdsWhichStartedGameAsPlayers, TGNS.GetClientSteamId(c)) end)
		TGNS.DoFor(TGNS.GetSpectatorClients(playerList), function(c) table.insert(steamIdsWhichStartedGameAsSpectators, TGNS.GetClientSteamId(c)) end)
		TGNS.ScheduleAction(15, function()
			TGNS.DoFor(getRecentCommanderClients(), function(c) table.insert(steamIdsWhichStartedGameAsCommanders, TGNS.GetClientSteamId(c)) end)
		end)


	end)
    return true
end

function Plugin:EndGame(gamerules, winningTeam)
	local playerList = TGNS.GetPlayerList()
	local clientsWhichWereInTheGameAsPlayersAtStartAndEnd = {}
	local currentGameDurationInSeconds = TGNS.GetCurrentGameDurationInSeconds()
	TGNS.DoForClientsWithId(TGNS.GetPlayingClients(playerList), function(c, steamId)
		if TGNS.Has(steamIdsWhichStartedGameAsPlayers, steamId) then
			table.insert(clientsWhichWereInTheGameAsPlayersAtStartAndEnd, c)
		end
	end)
	TGNS.ExecuteEventHooks("FullGamePlayed", clientsWhichWereInTheGameAsPlayersAtStartAndEnd, winningTeam, currentGameDurationInSeconds, gameStartTimeInSeconds)

	local clientsWhichWereInTheGameAsSpectatorsAtStartAndEnd = {}
	TGNS.DoForClientsWithId(TGNS.GetSpectatorClients(playerList), function(c, steamId)
		if TGNS.Has(steamIdsWhichStartedGameAsSpectators, steamId) then
			table.insert(clientsWhichWereInTheGameAsSpectatorsAtStartAndEnd, c)
		end
	end)
	TGNS.ExecuteEventHooks("FullGameSpectated", clientsWhichWereInTheGameAsSpectatorsAtStartAndEnd, currentGameDurationInSeconds, gameStartTimeInSeconds)

	local clientsWhichWereInTheGameAsCommandersAtStartAndEnd = {}
	TGNS.DoForClientsWithId(getRecentCommanderClients(), function(c, steamId)
		if TGNS.Has(steamIdsWhichStartedGameAsCommanders, steamId) then
			table.insert(clientsWhichWereInTheGameAsCommandersAtStartAndEnd, c)
		end
	end)
	TGNS.ExecuteEventHooks("FullGameCommanded", clientsWhichWereInTheGameAsCommandersAtStartAndEnd, currentGameDurationInSeconds, gameStartTimeInSeconds)
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("fullgameplayed", Plugin )