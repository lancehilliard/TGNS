Script.Load("lua/TGNSCommon.lua")

local GAMES_TO_PLAY_BEFORE_GREETINGS = 3
local GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS = 7
local GAMES_TO_PLAY_BEFORE_NO_MORE_GREETINGS = 10

local function GreetingsOnTeamJoin(self, player, newTeamNumber, force)
	local cancel = false
	if Balance and TGNS.IsGameplayTeam(newTeamNumber) then
		local totalGames = TGNS.ClientAction(player, function(c) return Balance.GetTotalGamesPlayed(c) end)
		local playerName = TGNS.GetPlayerName(player)
		TGNS.SendAdminConsoles(string.format("%s joined a team with %s games completed.", playerName, totalGames), "GREETINGSDEBUG")
		if totalGames >= GAMES_TO_PLAY_BEFORE_GREETINGS and totalGames <= GAMES_TO_PLAY_BEFORE_NO_MORE_GREETINGS then
			if totalGames >= GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS then
				TGNS.SendChatMessage(player, "Enjoying the server? Say hello at tacticalgamer.com/natural-selection", "Welcome")
				//TGNS.SendAdminChat(string.format("FORUM REMINDER sent to %s", playerName), "DEBUG")
			end
			local teamClients = TGNS.GetTeamClients(newTeamNumber, TGNS.GetPlayerList())
			TGNS.DoFor(teamClients, function(c)
				if not TGNS.IsClientStranger(c) then
					local chatMessage = string.format("Welcome: %s (%s games)", playerName, totalGames)
					TGNS.PlayerAction(c, function(p) TGNS.SendChatMessage(p, chatMessage, "Greetings") end)
				end
			end)
			//TGNS.SendAdminChat(string.format("GREETING sent to team for %s", playerName), "DEBUG")
		end
	end
	return cancel
end
TGNS.RegisterEventHook("OnTeamJoin", GreetingsOnTeamJoin, TGNS.LOWEST_EVENT_HANDLER_PRIORITY)
