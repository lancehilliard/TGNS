local TEMPBAN_DURATION_IN_MINUTES = 15
local AFFIRM_PLAYTIME_DELTA_IN_SECONDS = 43200
local startTimeSeconds
local approvedClients = {}
local approveReceivedTotal = {}
local approveSentTotal = {}
local vrConfirmedWhen = {}

local function CreateCommand(consoleCommandName, chatCommandName, messageChannel, isValidTargetClient, isNotValidTargetTemplate, onInputValidated, isReasonRequired, helpText)
	local result = {}
	result.consoleCommandName = consoleCommandName
	result.chatCommandName = chatCommandName
	result.messageChannel = messageChannel
	result.isNotValidTargetTemplate = isNotValidTargetTemplate
	result.isReasonRequired = isReasonRequired
	result.helpText = helpText
	function result:OnInputValidated(client, targetClient, reason, md) return onInputValidated(self, client, targetClient, reason, md) end
	function result.IsValidTargetClient(client)
		if isValidTargetClient == nil then
			return true
		else
			return isValidTargetClient(client)
		end
	end
	return result
end

local log = function(client, targetClient, commandName, reason)
	local logMessage = string.format("%s executed %s against %s. Reason: %s", TGNS.GetClientNameSteamIdCombo(client), commandName, TGNS.GetClientNameSteamIdCombo(targetClient), reason)
	TGNS.EnhancedLog(logMessage)
end

local function showApproval(sourceClient, targetClient, displayMessage, md)
	if sourceClient and targetClient and Shine:IsValidClient(sourceClient) and Shine:IsValidClient(targetClient) then
		local sourcePlayer = TGNS.GetPlayer(sourceClient)
		local targetPlayer = TGNS.GetPlayer(targetClient)
		TGNS.DoFor(TGNS.GetClientList(), function(c)
			if TGNS.IsClientAdmin(c) then
				md:ToClientConsole(c, string.format("%s: %s", TGNS.GetClientNameSteamIdCombo(sourceClient), displayMessage))
			end

			local p = TGNS.GetPlayer(c)
			if TGNS.PlayersAreTeammates(p, sourcePlayer) or TGNS.PlayersAreTeammates(p, targetPlayer) or TGNS.IsPlayerSpectator(p) or TGNS.IsClientAdmin(c) then
				local modifiedDisplayMessage = string.format("\n   %s", displayMessage)
				Shine:SendText(c, Shine.BuildScreenMessage(81, 0.05, 0.95, modifiedDisplayMessage, 15, 255, 255, 255, 0, 1, 0 ) )
			end
		end)
	end
end

local function approve(sourceClient, sourcePlayer, sourceSteamId, targetClient, targetClientIndex, targetSteamId, targetClientName, md, reason)
	if sourceClient ~= targetClient then
		if targetClient and Shine:IsValidClient(targetClient) then
			if vrConfirmedWhen[targetClient] == nil or TGNS.GetSecondsSinceMapLoaded() - vrConfirmedWhen[targetClient] > 5 then
				if not TGNS.GetIsClientVirtual(targetClient) then
					approvedClients[sourceSteamId] = approvedClients[sourceSteamId] or {}
					if approvedClients[sourceSteamId][targetSteamId] == nil then
						if reason == nil or string.len(reason) <= 20 then
							local approveUrl = string.format("%s&i=%s&a=%s&s=%s&t=%s&re=%s", TGNS.Config.ApproveEndpointBaseUrl, sourceSteamId, targetSteamId, TGNS.GetSimpleServerName(), startTimeSeconds or TGNS.GetSecondsSinceEpoch(), TGNS.UrlEncode(reason or ""))
							TGNS.GetHttpAsync(approveUrl, function(approveResponseJson)
								local approveResponse = json.decode(approveResponseJson) or {}
								if approveResponse.success then
									if Shine:IsValidClient(sourceClient) then
										approvedClients[sourceSteamId][targetSteamId] = true
										approveSentTotal[sourceSteamId] = TGNS.GetNumericValueOrZero(approveSentTotal[sourceSteamId])
										approveSentTotal[sourceSteamId] = approveSentTotal[sourceSteamId] + 1
										TGNS.SendNetworkMessageToPlayer(sourcePlayer, Shine.Plugins.scoreboard.APPROVE_SENT_TOTAL, {t=approveSentTotal[sourceSteamId]})
										if Shine:IsValidClient(targetClient) then
											-- if (TGNS.IsClientStranger(targetClient) and Balance.GetTotalGamesPlayed(targetClient) < TGNS.PRIMER_GAMES_THRESHOLD) and Shine.Plugins.targetedcommands and Shine.Plugins.targetedcommands.Enabled and Shine.Plugins.targetedcommands.Affirm then
											-- 	Shine.Plugins.targetedcommands:Affirm(sourceClient, targetClient, md)
											-- end
											approveReceivedTotal[targetSteamId] = TGNS.GetNumericValueOrZero(approveReceivedTotal[targetSteamId])
											approveReceivedTotal[targetSteamId] = approveReceivedTotal[targetSteamId] + 1
											TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(targetClient), Shine.Plugins.scoreboard.APPROVE_RECEIVED_TOTAL, {t=approveReceivedTotal[targetSteamId]})
											local displayMessage = string.format("^ %s%s", TGNS.GetClientName(targetClient), TGNS.HasNonEmptyValue(reason) and string.format(" (%s)", reason) or "")
											showApproval(sourceClient, targetClient, displayMessage, md)
											md:ToClientConsole(targetClient, displayMessage)
											if not TGNS.HasNonEmptyValue(reason) and math.random() <= 0.10 then
												md:ToPlayerNotifyInfo(sourcePlayer, "Chat with '^' to Approve with a Reason. Details in console. Chat Example: '^ NSPla Great job!'")
												md:ToClientConsole(sourceClient, " ")
												md:ToClientConsole(sourceClient, "Players love knowing why you Approved them!")
												md:ToClientConsole(sourceClient, " ")
												md:ToClientConsole(sourceClient, "You can specify a reason (up to 20 chars) when you Approve someone. Use chat or your console:")
												md:ToClientConsole(sourceClient, " ")
												md:ToClientConsole(sourceClient, "Start Team Chat with a caret character: ^ NSPla great leadership!")
												md:ToClientConsole(sourceClient, "-or-")
												md:ToClientConsole(sourceClient, "Use the console command: sh_approve NSPla great leadership!")
												md:ToClientConsole(sourceClient, " ")
												md:ToClientConsole(sourceClient, "In addition to the scoreboard, you can use chat and console /without/ a reason, too.")
												md:ToClientConsole(sourceClient, " ")
											end
										end
									end
								else
									if approveResponse.msg == "Too many recent approvals for this player." then
										md:ToPlayerNotifyError(sourcePlayer, string.format("You must Approve some other players before %s.", targetClientName))
										TGNS.SendNetworkMessageToPlayer(sourcePlayer, Shine.Plugins.scoreboard.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
									elseif approveResponse.msg == "Too many recent approvals." then
										md:ToPlayerNotifyError(sourcePlayer, "You have Approved too many players in the last 24 hours.")
										TGNS.SendNetworkMessageToPlayer(sourcePlayer, Shine.Plugins.scoreboard.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
									else
										TGNS.DebugPrint(string.format("scoreboard ERROR: Unable to approve NS2ID %s. msg: %s | response: %s | stacktrace: %s", targetSteamId, approveResponse.msg, approveResponseJson, approveResponse.stacktrace))
										if approvedClients[sourceSteamId][targetSteamId] == nil then
											md:ToPlayerNotifyError(sourcePlayer, string.format("There was a problem approving %s.", targetClientName))
											TGNS.SendNetworkMessageToPlayer(sourcePlayer, Shine.Plugins.scoreboard.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
										end
									end
								end
							end)
						else
							md:ToPlayerNotifyError(sourcePlayer, "Reasons are optional and may not exceed 20 characters.")
						end
					else
						md:ToPlayerNotifyError(sourcePlayer, string.format("You may Approve %s only once per game.", targetClientName))
					end
				else
					md:ToPlayerNotifyError(sourcePlayer, "Don't encourage the bots.")
				end
			else
				md:ToPlayerNotifyError(sourcePlayer, string.format("Click again to Approve %s.", TGNS.GetClientName(targetClient)))
			end
		else
			md:ToPlayerNotifyError(sourcePlayer, "There was a problem approving.")
			TGNS.SendNetworkMessageToPlayer(sourcePlayer, Shine.Plugins.scoreboard.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
		end
	else
		md:ToPlayerNotifyError(sourcePlayer, "Your modesty knows no bounds.")
	end
end

local function affirm(client, targetClient, md, commandName)
	if TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(targetClient) < AFFIRM_PLAYTIME_DELTA_IN_SECONDS then
		TGNSConnectedTimesTracker.AddToPlayTime(targetClient, AFFIRM_PLAYTIME_DELTA_IN_SECONDS)
	end
	md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), string.format("Thanks for affirming %s!", TGNS.GetClientName(targetClient)))
	log(client, targetClient, commandName or "sh_affirm")
end

local commands = { CreateCommand(
		"sh_affirm"
		, "affirm"
		, "AFFIRM"
		, function(client) return TGNS.IsClientStranger(client) and Balance.GetTotalGamesPlayed(client) < TGNS.PRIMER_GAMES_THRESHOLD end
		, string.format("'%%s' is not a stranger with fewer than %s games.", TGNS.PRIMER_GAMES_THRESHOLD)
		, function(self, client, targetClient, reason, md)
			affirm(client, targetClient, md, self.consoleCommandName)
		end
		, false
		, "<player> Make a stranger less vulnerable to reserved slots."
	), CreateCommand(
		"sh_approve"
		, nil
		, "APPROVE"
		, nil
		, nil
		, function(self, client, targetClient, reason, md)
			Shine.Plugins.targetedcommands:Approve(client, targetClient, reason, md)
		end
		, false
		, "<player> <reason> Tell someone they're doing well!"
	), CreateCommand(
		"sh_gb"
		, "gb"
		, "GOODBYE"
		, function(client) return TGNS.IsClientStranger(client) end
		, "'%s' is not a stranger."
		, function(self, client, targetClient, reason, md)
			TGNSClientKicker.Kick(targetClient, reason, nil, nil, true)
			md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), string.format("%s removed for '%s'.", TGNS.GetClientName(targetClient), reason))
			log(client, targetClient, self.consoleCommandName, reason)
		end
		, true
		, "<player> <reason> Remove strangers misaligned with our rules/tenets."
	), CreateCommand(
		"sh_afkrr"
		, "afkrr"
		, "PREGAMEAFK"
		, function(client) return TGNS.PlayerAction(client, TGNS.IsPlayerAFK) and TGNS.ClientIsOnPlayingTeam(client) and not TGNS.IsGameInProgress() and not TGNS.IsGameInCountdown() end
		, "%s must be AFK and on a playing team, and a game must not be in progress."
		, function(self, client, targetClient, reason, md)
			if TGNS.PlayersAreTeammates(TGNS.GetPlayer(client), TGNS.GetPlayer(targetClient)) then
				TGNS.SendToTeam(TGNS.GetPlayer(targetClient), kTeamReadyRoom, true)
				md:ToAllNotifyInfo(string.format("%s sent %s (AFK) to ReadyRoom. Learn more in console: sh_help %s", TGNS.GetClientName(client), TGNS.GetClientName(targetClient), self.consoleCommandName))
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Note: Always attempt to communicate with your target before using this command.")
				log(client, targetClient, self.consoleCommandName)
			else
				md:ToPlayerNotifyError(TGNS.GetPlayer(client), string.format("You are not on the same team as %s.", TGNS.GetClientName(targetClient)))
			end
		end
		, false
		, "<player> Send an AFK pre-game teammate to ReadyRoom."
	), CreateCommand(
		"sh_tempban"
		, "tempban"
		, "TEMPBAN"
		, nil
		, nil
		, function(self, client, targetClient, reason, md)
			TGNS.Ban(client, targetClient, TEMPBAN_DURATION_IN_MINUTES, reason)
			TGNSClientKicker.Kick(targetClient, reason, nil, nil, false)
			local message = string.format("%s tempbanned %s for %s.", TGNS.GetClientName(client), TGNS.GetClientName(targetClient), reason)
			md:ToAdminNotifyInfo(message)
			md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), message)
			log(client, targetClient, self.consoleCommandName, reason)
		end
		, true
		, string.format("<player> <reason> Ban player for %s minutes.", TEMPBAN_DURATION_IN_MINUTES)
	)
	, CreateCommand(
		"sh_kick"
		, "kick"
		, "KICK"
		, nil
		, nil
		, function(self, client, targetClient, reason, md)
			TGNSClientKicker.Kick(targetClient, reason, nil, nil, true)
			local message = string.format("%s kicked %s for %s.", TGNS.GetClientName(client), TGNS.GetClientName(targetClient), reason)
			md:ToAdminNotifyInfo(message)
			md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), message)
			log(client, targetClient, self.consoleCommandName, reason)
		end
		, true
		, "<player> <reason> Kick player."
	)
}

local Plugin = {}

function Plugin:GetApprovedClients(targetSteamId)
	approvedClients[targetSteamId] = approvedClients[targetSteamId] or {}
	return approvedClients[targetSteamId]
end

function Plugin:PlayerSay(client, networkMessage)
	local cancel = false
	local teamOnly = networkMessage.teamOnly
	local message = StringTrim(networkMessage.message)
	local isApproveChat = TGNS.StartsWith(networkMessage.message, '^') and string.len(message) > 1
	if isApproveChat then
		message = TGNS.Substring(message, 2)
		message = StringTrim(message)
		local parts = TGNS.Split(' ', message)
		local playerPredicate = #parts > 0 and parts[1] or ""
		local reason = #parts > 1 and TGNS.Substring(message, string.len(playerPredicate) + 2) or ""
		Shine.Commands.sh_approve.Func(client, playerPredicate, reason)
		cancel = true
	end
	if cancel then
		return ""
	end
end

function Plugin:CreateCommands()
	TGNS.DoFor(commands, function(command)
		local boundCommand = self:BindCommand(command.consoleCommandName, command.chatCommandName, function(client, playerPredicate, reason)
			local md = TGNSMessageDisplayer.Create(command.messageChannel)
			local player = TGNS.GetPlayer(client)
			if playerPredicate == nil or playerPredicate == "" then
				md:ToPlayerNotifyError(player, "You must specify a player.")
			else
				local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
				if targetPlayer ~= nil then
					local targetClient = TGNS.GetClient(targetPlayer)
					if command.IsValidTargetClient(targetClient) then
						if TGNS.HasNonEmptyValue(reason) or not command.isReasonRequired then
							command:OnInputValidated(client, targetClient, reason, md)
						else
							md:ToPlayerNotifyError(player, "You must specify a reason.")
						end
					else
						md:ToPlayerNotifyError(player, string.format(command.isNotValidTargetTemplate, TGNS.GetClientName(targetClient)))
					end
				else
					md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
				end
			end
		end)
		boundCommand:AddParam{ Type = "string", Optional = true }
		boundCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
		boundCommand:Help(command.helpText)
	end)
end

function Plugin:Affirm(client, targetClient, md)
	affirm(client, targetClient, md)
end

function Plugin:Approve(client, targetClient, reason, md)
	local player = TGNS.GetPlayer(client)
	local steamId = TGNS.GetClientSteamId(client)
	local targetPlayer = TGNS.GetPlayer(targetClient)
	local targetClientIndex = targetPlayer:GetClientIndex()
	local targetSteamId = TGNS.GetClientSteamId(targetClient)
	local targetClientName = TGNS.GetClientName(targetClient)
	approve(client, player, steamId, targetClient, targetClientIndex, targetSteamId, targetClientName, md, reason)
end

function Plugin:Initialise()
    self.Enabled = true
    TGNS.ScheduleAction(1, function()
    	self:CreateCommands()
    end)

	TGNS.ScheduleAction(10, function()
		local originalChangelevelFunc = Shine.Commands.sh_changelevel and Shine.Commands.sh_changelevel.Func or nil
		if originalChangelevelFunc then
			Shine.Commands.sh_changelevel.Func = function(client, mapName)
				TGNS.ScheduleAction(1, function()
					originalChangelevelFunc(client, mapName)
				end)
				local md = TGNSMessageDisplayer.Create()
				md:ToAllConsole(string.format("%s executed 'sh_changelevel %s'.", TGNS.GetClientNameSteamIdCombo(client), mapName))
			end
		end
	end)


	approvedClients = {}
	approveReceivedTotal = {}
	approveSentTotal = {}
	TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
		startTimeSeconds = secondsSinceEpoch
		approvedClients = {}
		approveSentTotal = {}
		approveReceivedTotal = {}
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.APPROVE_RESET, {})
			TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.APPROVE_RECEIVED_TOTAL, {t=0})
			TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.APPROVE_SENT_TOTAL, {t=0})
		end)
	end)

	TGNS.RegisterEventHook("VrConfirmed", function(client)
		vrConfirmedWhen[client] = TGNS.GetSecondsSinceMapLoaded()
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("targetedcommands", Plugin )