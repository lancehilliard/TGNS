// greet new players

if kDAKConfig and kDAKConfig.Greetings then
	Script.Load("lua/TGNSCommon.lua")
	
	local VERY_LOW_PRIORITY = 1000
	
	local GAMES_TO_PLAY_BEFORE_GREETINGS = 3
	local GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS = 7
	local GAMES_TO_PLAY_BEFORE_NO_MORE_GREETINGS = 10
	
	local function GreetingsOnTeamJoin(self, player, newTeamNumber, force)
		local cancel = false
		if newTeamNumber ~= kTeamReadyRoom and Balance then
			local totalGames = TGNS.ClientAction(player, function(c) return Balance.GetTotalGamesPlayed(c) end)
			if totalGames >= GAMES_TO_PLAY_BEFORE_GREETINGS and totalGames <= GAMES_TO_PLAY_BEFORE_NO_MORE_GREETINGS then
				TGNS.ScheduleAction(3, function()
					if totalGames >= GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS then
						TGNS.SendChatMessage(player, "Enjoying the server? Say hello at tacticalgamer.com/natural-selection", "Welcome")
						TGNS.SendAdminChat(string.format("GREETING sent to %s", TGNS.GetPlayerName(player)), "DEBUG")
					end
					local teamClients = TGNS.GetTeamClients(newTeamNumber, TGNS.GetPlayerList())
					DoFor(teamClients, function(c)
						if not TGNS.IsClientStranger(c) then
							local chatMessage = string.format("Welcome: %s (%s games)", TGNS.GetPlayerName(player), totalGames)
							TGNS.PlayerAction(c, function(p) TGNS.SendChatMessage(p, chatMessage, "Greetings") end)
						end
					end)
				end)
			end
		end
		return cancel
	end
	DAKRegisterEventHook("kDAKOnTeamJoin", GreetingsOnTeamJoin, VERY_LOW_PRIORITY)
end

Shared.Message("Greetings Loading Complete")