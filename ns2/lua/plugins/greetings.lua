Script.Load("lua/TGNSCommon.lua")

local GAMES_TO_PLAY_BEFORE_GREETINGS = 1
local GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS = 2
local GAMES_COUNT_TO_NOTIFY_TEAMMATES = 15
local STRANGER_MESSAGE_CODE = 421 // this is month and day of last message modification
local PRIMERONLY_MESSAGE_CODE = 421 // this is month and day of last message modification
local STRANGER_EXTENDED_WELCOME_LINES = { ""
                               , " === TACTICAL GAMER NATURAL SELECTION 2 SERVER WELCOME MESSAGE === "
							   , "This server requires mature teamwork and communication. If that's how you like to play,"
							   , "then please play here often. Our forums have full information about getting reserved slots."
							   , "Browse to our forums (see website address below), read the 'Required Reading' thread,"
							   , "and then, if you find everything agreeable, READ AND 'SIGN' the 'TGNS Primer' thread."
							   , "Signing the TGNS Primer lets you join the full server when it's full of strangers (and prevents this message)."
							   , "You can read more in our forums, and we're happy to answer any questions you have."
							   , ""
							   , "Website:"
							   , " TacticalGamer.com/natural-selection"
							   , ""
							   , "Enjoy your time here, and thank you for taking the time to read this message! :)"
							   , "" }

local PRIMERONLY_EXTENDED_WELCOME_LINES = { ""
                               , " === TACTICAL GAMER NATURAL SELECTION 2: USING YOUR RESERVED SLOT === "
							   , "Thank you for signing the TGNS Primer. Did you know that you NOW have a reserved"
							   , "slot on this server? You can join this full server anytime more than two Strangers*"
							   , "are playing. So bookmark us and play with a server full of regulars!"
							   , ""
							   , "* Stranger = player who hasn't signed the TGNS Primer and isn't a Supporting Member"	
							   , ""
							   , "If you want to show MORE support for what Tactical Gamer offers -- and/or if you'd"
							   , "like a more powerful reserved slot -- consider becoming a Supporting Member! You"
							   , "can read more about that in our forums. Speaking of which: how long has it been"
							   , "since you checked in on our forums to see what people were saying there?"
							   , ""
							   , "Website:"
							   , " TacticalGamer.com/natural-selection"
							   , ""
							   , "Enjoy your time here, and thank you for contributing to this community! :)"
							   , "" }


local function GreetingsOnTeamJoin(self, player, newTeamNumber, force)
	local cancel = false
	if Balance and TGNS.IsGameplayTeam(newTeamNumber) then
		local client = TGNS.GetClient(player)
		local totalGames = Balance.GetTotalGamesPlayed(client)
		if totalGames >= GAMES_TO_PLAY_BEFORE_GREETINGS then
			if TGNS.IsClientStranger(client) and totalGames >= GAMES_TO_PLAY_BEFORE_FORUM_REMINDERS and not TGNS.IsGameInProgress() then
				TGNS.SendChatMessage(player, string.format("There's a message for you in your console (%s). Press ` to read it.", "Welcome!", STRANGER_MESSAGE_CODE))
				TGNS.DoFor(STRANGER_EXTENDED_WELCOME_LINES, function(l)
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
			if TGNS.IsPrimerOnlyClient(client) then
				TGNS.SendChatMessage(player, string.format("There's a message for you in your console (%s). Press ` to read it.", "Welcome!", PRIMERONLY_MESSAGE_CODE))
				TGNS.DoFor(PRIMERONLY_EXTENDED_WELCOME_LINES, function(l)
					TGNS.ConsolePrint(client, l, "TacticalGamer.com")
				end)
			end
		end
	end
	return cancel
end
TGNS.RegisterEventHook("OnTeamJoin", GreetingsOnTeamJoin, TGNS.LOWEST_EVENT_HANDLER_PRIORITY)
