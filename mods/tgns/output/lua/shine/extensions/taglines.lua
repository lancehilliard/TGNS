local unescapedTaglineMessages = {}
local taglinesCache = {}
local taglinesCacheWasPreloaded = false;

local Plugin = {}

local pdr = TGNSPlayerDataRepository.Create("taglines", function(tagline)
	tagline.message = tagline.message ~= nil and tagline.message or ""
	return tagline
end)

local tgnsMd = TGNSMessageDisplayer.Create("TGNS")
local taglineMd = TGNSMessageDisplayer.Create("TAGLINE")

local function GetTaglineMessage(...)
	local result = ""
	local concatenation = StringConcatArgs(...)
	if concatenation then
		result = concatenation
	end
	return result
end

local function getEscapedTaglineMessage(message)
	local result = TGNS.Replace(message, '"', '\"')
	return result
end

local function getUnescapedTaglineMessage(message)
	local result = TGNS.Replace(message, '\"', '"')
	return result
end

local function ShowCurrentTagline(client)
	local steamId = client:GetUserId()
	pdr:Load(steamId, function(loadResponse)
		if loadResponse.success then
			local tagline = loadResponse.value
			taglineMd:ToClientConsole(client, "Your current tagline:")
			if tagline == nil or tagline.message == "" then
				taglineMd:ToClientConsole(client, "     You don't currently have a tagline saved.")
				taglineMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "You don't currently have a tagline saved.")
			else
				local taglineMessage = getUnescapedTaglineMessage(tagline.message)
				taglineMd:ToClientConsole(client, "     " .. taglineMessage)
				taglineMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Your current tagline: " .. taglineMessage)
			end
		else
			TGNS.DebugPrint("taglines ERROR: Unable to access data.", true)
			taglineMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to access tagline data.")
		end
		taglineMd:ToClientConsole(client, "")
	end)
end

local function ShowUsage(client)
	taglineMd:ToClientConsole(client, "")
	taglineMd:ToClientConsole(client, "Usage:")
	taglineMd:ToClientConsole(client, "    sh_tagline <whatever you want all players to see when you join as a Supporting Member>")
	taglineMd:ToClientConsole(client, "Notes:")
	taglineMd:ToClientConsole(client, "* Any length may be saved, but displayed character count is dictated by NS2 and may change in the future.")
	taglineMd:ToClientConsole(client, "* Taglines do not display to players in the first two minutes after a map loads")
	taglineMd:ToClientConsole(client, "* To remove your tagline at any time: sh_tagline remove")
	ShowCurrentTagline(client)
end

function Plugin:CreateCommands()
	local taglineCommand = self:BindCommand( "sh_tagline", "tagline", function(client, taglineMessage)
		local steamId = TGNS.GetClientSteamId(client)
		if taglineMessage == nil or taglineMessage == "" then
			ShowUsage(client)
		else
			pdr:Load(steamId, function(loadResponse)
				if loadResponse.success then
					local tagline = loadResponse.value
					if taglineMessage == "remove" then
						taglineMessage = ""
					end
					tagline.message = getEscapedTaglineMessage(taglineMessage)
					pdr:Save(tagline, function(saveResponse)
						if saveResponse.success then
							ShowCurrentTagline(client)
						else
							taglineMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to save tagline.")
							TGNS.DebugPrint("taglines ERROR: Unable to save data.", true)
						end
					end)
				else
					taglineMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to access tagline data.")
					TGNS.DebugPrint("taglines ERROR: Unable to access data.", true)
				end
			end)
		end
	end, true)
	taglineCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	taglineCommand:Help( "<tagline> Sets your tagline." )
end

function Plugin:ClientConnect(client)
	if not TGNS.GetIsClientVirtual(client) then
		local steamId = TGNS.GetClientSteamId(client)
		if taglinesCache[steamId] ~= nil then
			unescapedTaglineMessages[client] = getUnescapedTaglineMessage(taglinesCache[steamId])
		elseif not taglinesCacheWasPreloaded then
			pdr:Load(steamId, function(loadResponse)
				if loadResponse.success then
					local tagline = loadResponse.value
					if TGNS.HasNonEmptyValue(tagline.message) then
						unescapedTaglineMessages[client] = getUnescapedTaglineMessage(tagline.message)
					end
				else
					TGNS.DebugPrint("taglines ERROR: Unable to access data.", true)
				end
			end)
		end
	end
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("OnSlotTaken", function(client)
		if not TGNS.GetIsClientVirtual(client) then
			local connectedTimeInSeconds = Shared.GetSystemTime() - TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
			if connectedTimeInSeconds < 120 and TGNS.IsGameInProgress() then
				local steamProfileName = Shine.Plugins.betterknownas and Shine.Plugins.betterknownas.GetSteamProfileName and Shine.Plugins.betterknownas:GetSteamProfileName(client)
				local steamProfileNameDisplay = (TGNS.HasNonEmptyValue(steamProfileName) and TGNS.ToLower(steamProfileName) ~= TGNS.ToLower(TGNS.GetClientName(client))) and string.format("    Steam: %s", steamProfileName) or ""
				local totalGames = Balance.GetTotalGamesPlayed(client)
				local message = string.format("%s joined (%s%s)! %s", TGNS.GetClientName(client), TGNS.PlayerAction(client, TGNS.GetPlayerTeamName), (totalGames > 0 and totalGames < 50) and string.format("; %s total games so far", totalGames) or "", steamProfileNameDisplay)
				if TGNS.ClientIsMarine(client) then
					tgnsMd:ToAllNotifyMarineColor(message)
				elseif TGNS.ClientIsAlien(client) then
					tgnsMd:ToAllNotifyAlienColor(message)
				end
				if TGNS.ClientCanRunCommand(client, "sh_taglineannounce") and TGNS.HasNonEmptyValue(unescapedTaglineMessages[client]) then
					tgnsMd:ToAllNotifyInfo(string.format("-- %s", unescapedTaglineMessages[client]))
				end
			end
		end
	end)
	self:CreateCommands()

	TGNS.DoWithConfig(function()
		local url = TGNS.Config.TaglinesEndpointBaseUrl
		TGNS.GetHttpAsync(url, function(taglinesResponseJson)
			local taglinesResponse = json.decode(taglinesResponseJson) or {}
			if taglinesResponse.success then
				TGNS.DoForPairs(taglinesResponse.result, function(steamId, steamIdData)
					taglinesCache[tonumber(steamId)] = steamIdData
				end)
				taglinesCacheWasPreloaded = true
			else
				TGNS.DebugPrint(string.format("taglines ERROR: Unable to access taglines data. url: %s | msg: %s | response: %s | stacktrace: %s", url, taglinesResponse.msg, taglinesResponseJson, taglinesResponse.stacktrace))
			end
		end)
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("taglines", Plugin )