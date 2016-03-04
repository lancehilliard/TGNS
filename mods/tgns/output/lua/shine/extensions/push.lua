local md = TGNSMessageDisplayer.Create("PUSH")
local pushTempfilePath = "config://tgns/temp/push.json"
local Plugin = {}
local PUSHBULLET_CHANNEL_IDS = {'tgns-bots', 'tgns-priming', 'tgns-seeded', 'tgns-primed', 'tgns-captains', 'tgns-test'}

function Plugin:Push(pushChannelId, pushTitle, pushMessage, client)
	local sourcePlayerId = client and TGNS.GetClientSteamId(client) or 0
	if TGNS.Has(PUSHBULLET_CHANNEL_IDS, pushChannelId) then
		local pushUrl = string.format("%s&i=%s&c=%s&t=%s&m=%s", TGNS.Config.PushEndpointBaseUrl, sourcePlayerId, TGNS.UrlEncode(pushChannelId), TGNS.UrlEncode(pushTitle), TGNS.UrlEncode(pushMessage))
		TGNS.GetHttpAsync(pushUrl, function(pushResponseJson)
			local pushResponse = json.decode(pushResponseJson) or {}
			if pushResponse.success then
				if Shine:IsValidClient(client) then
					md:ToClientConsole(client, string.format("Success. Sent '%s: %s' to channel '%s'.", pushTitle, pushMessage, pushChannelId))
				end
			else
				local errorDisplayMessage = string.format("Unable to push title '%s' and message '%s' to channel '%s'", pushTitle, pushMessage, pushChannelId)
				if Shine:IsValidClient(client) then
					md:ToClientConsole(client, string.format("ERROR: %s. See server log for details.", errorDisplayMessage))
				end
				local errorMessage = string.format("%s for NS2ID %s. msg: %s | response: %s | stacktrace: %s", errorDisplayMessage, sourcePlayerId, pushResponse.msg, pushResponseJson, pushResponse.stacktrace)
				TGNS.DebugPrint(string.format("push ERROR: %s", errorMessage))
			end
		end)
	end

	pushMessage = string.format("%s - Manage Notifications: http://rr.tacticalgamer.com/Notifications", pushMessage)
	local notifyUrl = string.format("%s&sourcePlayerId=%s&offeringName=%s&title=%s&message=%s", TGNS.Config.NotifyEndpointBaseUrl, sourcePlayerId, TGNS.UrlEncode(pushChannelId), TGNS.UrlEncode(pushTitle), TGNS.UrlEncode(pushMessage))
	TGNS.GetHttpAsync(notifyUrl, function(notifyResponseJson)
		local notifyResponse = json.decode(notifyResponseJson) or {}
		if notifyResponse.success then
			if Shine:IsValidClient(client) then
				md:ToClientConsole(client, string.format("Success. Sent '%s: %s' to subscription '%s'.", pushTitle, pushMessage, pushChannelId))
			end
		else
			local errorDisplayMessage = string.format("Unable to notify title '%s' and message '%s' to subscription '%s'", pushTitle, pushMessage, pushChannelId)
			if Shine:IsValidClient(client) then
				md:ToClientConsole(client, string.format("ERROR: %s. See server log for details.", errorDisplayMessage))
			end
			local errorMessage = string.format("%s for NS2ID %s. msg: %s | response: %s | stacktrace: %s", errorDisplayMessage, sourcePlayerId, notifyResponse.msg, notifyResponseJson, notifyResponse.stacktrace)
			TGNS.DebugPrint(string.format("notify ERROR: %s", errorMessage))
		end
	end)
end

local function validatePushInput(pushInput)
	local result = false
	local messageData = TGNS.Split("|", pushInput)
	local title = #messageData > 0 and messageData[1] or ""
	local message = #messageData > 1 and messageData[2] or ""
	if TGNS.HasNonEmptyValue(title) and TGNS.HasNonEmptyValue(message) then
		result = true
	end
	return result, title, message
end

local function handlePushCommand(plugin, client, commandName, channelId, pushInput)
	local inputIsValid, title, message = validatePushInput(pushInput)
	if inputIsValid then
		plugin:Push(channelId, title, message, client)
		TGNS.EnhancedLog(string.format("%s executed %s with title '%s' and message '%s' to channel '%s'.", TGNS.GetClientNameSteamIdCombo(client), commandName, title, message, channelId))
	else
		md:ToClientConsole(client, "You must specify a title and message delimited by pipe (|). Example: Alert|This is a message.")
	end
end

local function createPushCommand(plugin, channelId, channelTitle)
	local channelIdCharactersToTrimFromCommandName = TGNS.StartsWith(channelId, "tgns-") and 5 or 0
	local commandName = string.format("sh_push-%s", TGNS.Substring(channelId, channelIdCharactersToTrimFromCommandName + 1))
	local command = plugin:BindCommand(commandName, nil, function(client, pushInput)
		handlePushCommand(plugin, client, commandName, channelId, pushInput)
	end)
	command:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	command:Help(string.format("<title|message> Push message on channel '%s'.", channelTitle))
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	local numberOfPrimerSignersNecessaryToSendPrimingNotification = 6
	local numberOfPrimerSignersNecessaryToSendPrimedNotification = 14
	local playerList = TGNS.GetPlayerList()
	local playingClients = TGNS.GetPlayingClients(playerList)
	local numberOfPrimerSignersAmongPlayingClients = #TGNS.GetPrimerWithGamesClients(TGNS.GetPlayers(playingClients))
	local secondsSinceEpoch = TGNS.GetSecondsSinceEpoch()
	local secondsThreshold = TGNS.ConvertHoursToSeconds(3)
	if numberOfPrimerSignersAmongPlayingClients >= numberOfPrimerSignersNecessaryToSendPrimedNotification then
		local pushData = Shine.LoadJSONFile(pushTempfilePath) or {}
		local secondsSincePrimedNotifications = secondsSinceEpoch - (pushData.primedLastSentInSeconds or 0)
		if secondsSincePrimedNotifications >= secondsThreshold then
			self:Push("tgns-primed", "TGNS primed!", string.format("%s+ Primer signers playing %s on %s. Server Info: http://rr.tacticalgamer.com/ServerInfo", numberOfPrimerSignersNecessaryToSendPrimedNotification, TGNS.GetCurrentMapName(), TGNS.GetSimpleServerName()))
			pushData.primedLastSentInSeconds = secondsSinceEpoch
			Shine.SaveJSONFile(pushData, pushTempfilePath)
		end
	elseif numberOfPrimerSignersAmongPlayingClients >= numberOfPrimerSignersNecessaryToSendPrimingNotification then
		local pushData = Shine.LoadJSONFile(pushTempfilePath) or {}
		local secondsSincePrimingNotifications = secondsSinceEpoch - (pushData.primingLastSentInSeconds or 0)
		local secondsSincePrimedNotifications = secondsSinceEpoch - (pushData.primedLastSentInSeconds or 0)
		if secondsSincePrimingNotifications >= secondsThreshold and secondsSincePrimedNotifications >= secondsThreshold then
			self:Push("tgns-priming", "TGNS priming!", string.format("%s+ Primer signers playing %s on %s. Server Info: http://rr.tacticalgamer.com/ServerInfo", numberOfPrimerSignersNecessaryToSendPrimingNotification, TGNS.GetCurrentMapName(), TGNS.GetSimpleServerName()))
			pushData.primingLastSentInSeconds = secondsSinceEpoch
			Shine.SaveJSONFile(pushData, pushTempfilePath)
		end
	end
end

function Plugin:CreateCommands()
	createPushCommand(self, "tgns", "TGNS")
	createPushCommand(self, "tgns-captains", "TGNS Captains")
	createPushCommand(self, "tgns-test", "TGNS Test")
end

function Plugin:Initialise()
    self.Enabled = true
	self:CreateCommands()

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("push", Plugin )