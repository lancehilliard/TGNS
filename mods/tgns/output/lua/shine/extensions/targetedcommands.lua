local TEMPBAN_DURATION_IN_MINUTES = 15

local function CreateCommand(consoleCommandName, chatCommandName, messageChannel, isValidTargetClient, isNotValidTargetTemplate, onInputValidated, isReasonRequired, helpText)
	local result = {}
	result.consoleCommandName = consoleCommandName
	result.chatCommandName = chatCommandName
	result.messageChannel = messageChannel
	result.isNotValidTargetTemplate = isNotValidTargetTemplate
	result.isReasonRequired = isReasonRequired
	result.helpText = helpText
	function result:OnInputValidated(client, targetClient, reason, md) return onInputValidated(self, client, targetClient, reason, md) end
	function result:IsValidTargetClient(client) return isValidTargetClient(self, client) end
	return result
end

local log = function(client, targetClient, commandName, reason)
	local logMessage = string.format("%s executed %s against %s. Reason: %s", TGNS.GetClientNameSteamIdCombo(client), commandName, TGNS.GetClientNameSteamIdCombo(targetClient), reason)
	TGNS.EnhancedLog(logMessage)
end

local function affirm(client, targetClient, md, commandName)
	TGNSConnectedTimesTracker.SetClientConnectedTimeInSeconds(targetClient, 0)
	md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), string.format("%s seemingly connected a long, long time ago...", TGNS.GetClientName(targetClient)))
	log(client, targetClient, commandName or "sh_affirm")
end

local commands = { CreateCommand(
		"sh_affirm"
		, "affirm"
		, "AFFIRM"
		, function(self, client) return TGNS.IsClientStranger(client) end
		, "'%s' is not a stranger."
		, function(self, client, targetClient, reason, md)
			affirm(client, targetClient, md, self.consoleCommandName)
		end
		, false
		, "<player> Make a stranger less vulnerable to reserved slots."
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

function Plugin:CreateCommands()
	TGNS.DoFor(commands, function(command)
		local boundCommand = self:BindCommand(command.consoleCommandName, chatCommandName, function(client, playerPredicate, reason)
			local md = TGNSMessageDisplayer.Create(command.messageChannel)
			local player = TGNS.GetPlayer(client)
			if playerPredicate == nil or playerPredicate == "" then
				md:ToPlayerNotifyError(player, "You must specify a player.")
			else
				local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
				if targetPlayer ~= nil then
					local targetClient = TGNS.GetClient(targetPlayer)
					if command.IsValidTarget == nil or command.IsValidTarget(targetClient) then
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

function Plugin:Initialise()
    self.Enabled = true
    TGNS.ScheduleAction(1, function()
    	self:CreateCommands()
    end)

	TGNS.ScheduleAction(10, function()
		local originalChangelevelFunc = Shine.Commands.sh_changelevel.Func
		Shine.Commands.sh_changelevel.Func = function(client, mapName)
			TGNS.ScheduleAction(1, function()
				originalChangelevelFunc(client, mapName)
			end)
			local md = TGNSMessageDisplayer.Create()
			md:ToAllConsole(string.format("%s executed 'sh_changelevel %s'.", TGNS.GetClientNameSteamIdCombo(client), mapName))
		end
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("targetedcommands", Plugin )