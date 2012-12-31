if kDAKConfig and kDAKConfig.Captains then
	// Constants
	local CHAT_TAG = "[CAPTAINS]"
	local NOTE_MAX_LENGTH = 20
	local PLAYNAME_MAX_LENGTH = 39
	
	local NOTECOMMAND = "/note"
	local NOTESCOMMAND = "/notes"
	local CAPTAINCOMMAND = "/captain"
	
	// Misc variables and tables
	// local allowAttack = true // Is this needed, the noattackpregame plugin should handle this
	local allowNotesDisplay = true
	local captain1id = -1
	local captain2id = -1
	local notes = {}
	local captainsEnabled = false;

/******************************************
	THESE SHOULD BE PUT IN A COMMON FILE
*******************************************/

	local function GetPlayerList()

		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
		return playerList
		
	end

	/**
	 * Iterates over all players sorted in alphabetically calling the passed in function.
	 */
	 
	local function AllPlayers(doThis)

		return function(client)
		
			local playerList = GetPlayerList()
			for p = 1, #playerList do
			
				local player = playerList[p]
				doThis(player, client, p)
				
			end
			
		end
		
	end

	local function GetPlayerMatchingSteamId(steamId)

		assert(type(steamId) == "number")
		
		local match = nil
		
		local function Matches(player)
		
			local playerClient = Server.GetOwner(player)
			if playerClient and playerClient:GetUserId() == steamId then
				match = player
			end
			
		end
		AllPlayers(Matches)()
		
		return match

	end

	local function GetPlayerMatchingName(name)

		assert(type(name) == "string")
		
		local nameMatchCount = 0
		local match = nil
		
		local function Matches(player)
			if nameMatchCount == -1 then
				return // exact match found, skip others to avoid further partial matches
			end
			local playerName =  player:GetName()
			if player:GetName() == name then // exact match
				match = player
				nameMatchCount = -1
			else
				local index = string.find(string.lower(playerName), string.lower(name)) // partial match
				if index ~= nil then
					match = player
					nameMatchCount = nameMatchCount + 1
				end
			end
			
		end
		AllPlayers(Matches)()
		
		if nameMatchCount > 1 then
			match = nil
		end
		
		return match

	end

	local function GetPlayerMatching(id)

		local idNum = tonumber(id)
		if idNum then
			return GetPlayerMatchingGameId(idNum) or GetPlayerMatchingSteamId(idNum)
		elseif type(id) == "string" then
			return GetPlayerMatchingName(id)
		end

	end

	local function isCommand(message, command)
		index, _, match = string.find(message, "(/%a+)")
		if index == 1 and match == command then
			return true
		end
		return false
	end

	local function getArgs(message, command)
		index, _, match, args = string.find(message, "(/%a+) (.*)")
		if index == 1 and match == command then
			return args
		end
		return nil
	end

/******************************************
	End common functions
*******************************************/

	local function DisplayMessage(player, message)

		chatMessage = string.sub(message, 1, kMaxChatLength)
		Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, CHAT_TAG, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)

	end

	local function DisplayMessageAll(message)

		chatMessage = string.sub(message, 1, kMaxChatLength)
		Server.SendNetworkMessage("Chat", BuildChatMessage(false, CHAT_TAG, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)

	end

	local function StartCaptains()
		if kDAKConfig and kDAKConfig.TournamentMode then
			local tournamentMode = GetTournamentMode()
			//allowAttack = false
			captainsEnabled = true;
			captain1id = -1
			captain2id = -1
			notes = {}
			DisplayMessageAll("Captains game starting.  Return to the readyroom to pick teams.")
			
			// TODO: Modify tournament mode settings to require 'ready'
			// TODO: Adjust server settings (time limit, others?)
				// server_cmd("mp_timelimit 45")
			if Server then
				Shared.ConsoleCommand("sv_tournamentmode 1 0 0")
			end
			//todo: make sure pubmode gets reset after a map change
			kDAKConfig.TournamentMode.kTournamentModePubMode = false
		end
	end

	DAKCreateServerAdminCommand("Console_captains", StartCaptains, "configures the server for Captains Games")

	local function OnCaptainsChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
		if client and steamId and steamId ~= 0 and isCaptainsMode() then
			if isCommand(message, NOTECOMMAND) then
				local args = getArgs(message, NOTECOMMAND)
				if args ~= nil then
					local firstspace = string.find(args, " ")
					if firstspace ~= nil then
						local playername = string.sub(args, 1, firstspace - 1)
						local note = string.sub(args, firstspace + 1)
						assignNote(steamId, playername, note)
					end
				end
			elseif isCommand(message, CAPTAINCOMMAND) then
				makeCaptain(steamId)
			elseif isCommand(message, NOTESCOMMAND) then
				showTeamNotes(GetPlayerMatchingSteamId(steamId))
			end
		end
	end

	table.insert(kDAKOnClientChatMessage, function(message, playerName, steamId, teamNumber, teamOnly, client) return OnCaptainsChatMessage(message, playerName, steamId, teamNumber, teamOnly, client) end)

	function assignNote(steamId, targetName, note)
		if isCaptainsMode() then
			local sourcePlayer = GetPlayerMatchingSteamId(steamId)
			if sourcePlayer and sourcePlayer:GetTeamNumber() ~= kTeamReadyRoom then
				local targetPlayer = GetPlayerMatching(targetName)
				if targetPlayer ~= nil then
					local targetSteamId = Server.GetOwner(targetPlayer):GetUserId()
					if steamId == targetSteamId or isCaptain(steamId) then
						if sourcePlayer:GetTeamNumber() == targetPlayer:GetTeamNumber() then
							notes[targetSteamId] = string.sub(note, 1, NOTE_MAX_LENGTH)
							showNotes()
						else
							DisplayMessage(sourcePlayer, "You may only set notes for players on your own team.")
						end
					else
						DisplayMessage(sourcePlayer, "Only captains may set others' notes.  You may only set your own.")
					end
				else
					DisplayMessage(sourcePlayer, string.format("'%s' does not uniquely match a teammate.  Try again.", targetName))
				end
				
			else
				DisplayMessage(sourcePlayer, "You must be on a team to use this command.")
			end
		else
			DisplayMessage(sourcePlayer, "Captains mode is not enabled.")
		end
	end

	function makeCaptain(id)
		local player = GetPlayerMatchingSteamId(id)
		if isCaptainsMode() then
			if player:GetTeamNumber() == kTeamReadyRoom then
				if isCaptain(id) then
					DisplayMessage(player, "You are already a captain.")
				else
					if captain1id  == -1 then
						captain1id = id
					elseif captain2id  == -1 then
						captain2id = id
					end
					if isCaptain(id) then
						local name = string.sub(player:GetName(), 1, PLAYNAME_MAX_LENGTH)
						DisplayMessageAll(string.format("%s is a captain.", name))
					else
						DisplayMessage(player, "Two captains already exist.  You are not a captain.")
					end
				end
			else
				DisplayMessage(player, "This command must be used from the readyroom")
			end
		else
			DisplayMessage(player, "Captains mode is not enabled.")
		end
	end

	function isCaptain(id)
		return captain1id == id or captain2id == id
	end

// Is this needed?
/*
	function attack_allow()
		allowAttack = true
	end

	function attack_disallow()
		allowAttack = false
	end
*/

	local function onGameStateChange(self, state, currentstate)

		if state ~= currentstate then
			if state == kGameState.Started then
				do_roundbegin()
			elseif state == kGameState.Team1Won or
				   state == kGameState.Team2Won or
				   state == kGameState.Draw then
				do_roundend()
			end
		end
		
	end

	table.insert(kDAKOnSetGameState, function(self, state, currentstate) return onGameStateChange(self, state, currentstate) end)
	
	function do_roundbegin()
		// allowAttack = true
		if isCaptainsMode() then
			allowNotesDisplay = false
			hideNotes()
		end
	end

	function do_roundend()
		// todo: when round ends, show notes again
		//set_task(float(DISPLAY_FREQ),"showNotes",taskId,_,_,"b")
		//allowAttack = false
		if isCaptainsMode() then
			allowNotesDisplay = true
		end
	end

	function client_putinserver(client)
		if isCaptainsMode() then
			DisplayMessage(client:GetControllingPlayer(), "You're joining a captains game.  Please ASK FOR ORDERS when you join a team.")
		end
		return true
	end
	
	table.insert(kDAKOnClientDelayedConnect, function(client) return client_putinserver(client) end)

	function client_disconnect(client)
		if client ~= nil and VerifyClient(client) ~= nil then
			if isCaptainsMode() then
				local id = client:GetUserId()
				local team = client:GetControllingPlayer():GetTeamNumber()
				if team ~= kTeamReadyRoom then
					for _, player in pairs(GetPlayerList()) do
						if team == player:GetTeamNumber() and notes[id] ~= nil and string.len(notes[id]) > 0 then
							DisplayMessage(player, string.format("Teammate with note '%s' has left the server.", notes[id]))
						end
					end
				end
				notes[id] = nil // remove note from table
				if (captain1id == id) then
					captain1id = -1
					announceCaptDisc()
				elseif (captain2id == id) then
					captain2id = -1
					announceCaptDisc()
				end
			end
		end
		return true
	end

	table.insert(kDAKOnClientDisconnect, function(client) return client_disconnect(client) end)

	function announceCaptDisc()
		DisplayMessageAll("A captain has left the server.")
	end

	local function CaptainsJoinTeam(player, newTeamNumber, force)
		if isCaptainsMode() then
			client = Server.GetOwner(player)
			if client ~= nil then
				local steamId = client:GetUserId()
				//if isCaptain(steamId) and newTeamNumber ~= kTeamReadyRoom and GetGamerules():GetGameState() == kGameState.PreGame then
				//	allowNotesDisplay = true
				//end
				if notes[steamId] ~= nil then
					notes[steamId] = "" // clear the note when a player changes teams
				end
			end
		end
		return true
	end

	table.insert(kDAKOnTeamJoin, function(player, newTeamNumber, force) return CaptainsJoinTeam(player, newTeamNumber, force) end)

	function isCaptainsMode()
		return captainsEnabled
	end

	function buildTeamNotes(team)
		local notesString = ""
		local playername
		local notesLine
		for _, player in pairs(GetPlayerList()) do
			local steamId = Server.GetOwner(player):GetUserId()
			local playername = player:GetName()
			if player:GetTeamNumber() == team then
				if isCaptain(steamId) then
					playername = playername .. "*"
				end
				local note = ""
				if notes[steamId] ~= nil and string.len(notes[steamId]) > 0 then
					note = notes[steamId]
					notesLine = string.format("%s: %s\n", playername, note)
					notesString = notesString .. notesLine
				end
			end
		end
		return notesString
	end

	function showTeamNotes(player)
		local team = player:GetTeamNumber()
		if team ~= kTeamReadyRoom then
			local notes = buildTeamNotes(team)
			if notes ~= nil and string.len(notes) > 0 then
				DisplayMessage(player, notes)
			end
		end
	end

	function showNotes()
		if allowNotesDisplay == true and isCaptainsMode() then
			for _, player in pairs(GetPlayerList()) do
				if player:GetTeamNumber() ~= kTeamReadyRoom then
					showTeamNotes(player)
				end
			end
		end
	end

	function hideNotes()
		for _, player in pairs(GetPlayerList()) do
			DisplayMessage(player, "Say /notes to view the captain's notes.")
		end
	end

end

Shared.Message("Captains Loading Complete")