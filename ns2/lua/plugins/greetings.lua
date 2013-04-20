Script.Load("lua/TGNSCommon.lua")

local GAMES_TO_PLAY_BEFORE_GREETINGS = 1
local GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS = 2
local GAMES_COUNT_TO_NOTIFY_TEAMMATES = 15
local EXTENDED_WELCOME_LINES = { ""
                               , " === TACTICAL GAMER NATURAL SELECTION 2 SERVER WELCOME MESSAGE === "
							   , "This server requires mature teamwork and communication. If that's how you like to play,"
							   , "then please play here often. Our forums have full information about getting reserved slots."
							   , "Browse to our forums (see website address below), read the 'Required Reading' thread,"
							   , "and then, if you find everything agreeable, READ AND 'SIGN' the 'TGNS Primer' thread/document."
							   , "Signing that thread lets you join the full server when it's full of strangers (and prevents this message)."
							   , "You can read more in our forums, and we're happy to answer any questions you have."
							   , ""
							   , "Website:"
							   , " TacticalGamer.com/natural-selection"
							   , ""
							   , "Enjoy your time here, and thank you for taking the time to read this message! :)"
							   , "" }


local function GreetingsOnTeamJoin(self, player, newTeamNumber, force)
	local cancel = false
	if Balance and TGNS.IsGameplayTeam(newTeamNumber) then
		local client = TGNS.GetClient(player)
		local totalGames = Balance.GetTotalGamesPlayed(client)
		if totalGames >= GAMES_TO_PLAY_BEFORE_GREETINGS then
			if TGNS.IsClientStranger(client) and totalGames >= GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS and not TGNS.IsGameInProgress() then
				TGNS.SendChatMessage(player, "There's a message for you in your console. Press ` to read it.", "Welcome!")
				TGNS.DoFor(EXTENDED_WELCOME_LINES, function(l)
					TGNS.ConsolePrint(client, l, "TacticalGamer.com")
				end)
			end
			if totalGames <= GAMES_COUNT_TO_NOTIFY_TEAMMATES then
				local teamClients = TGNS.GetTeamClients(newTeamNumber, TGNS.GetPlayerList())
				TGNS.DoFor(teamClients, function(c)
					if not (TGNS.IsClientStranger(c) or c == client) then
						local chatMessage = string.format("%s (%s games so far)", TGNS.GetPlayerName(player), totalGames)
						TGNS.PlayerAction(c, function(p) TGNS.SendChatMessage(p, chatMessage, "WelcomeBack!") end)
					end
				end)
			end
		end
	end
	return cancel
end
TGNS.RegisterEventHook("OnTeamJoin", GreetingsOnTeamJoin, TGNS.LOWEST_EVENT_HANDLER_PRIORITY)
