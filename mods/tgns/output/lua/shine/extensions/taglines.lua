local unescapedTaglineMessages = {}

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
			Shared.Message("taglines ERROR: Unable to access data.")
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
							Shared.Message("taglines ERROR: Unable to save data.")
						end
					end)
				else
					taglineMd:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to access tagline data.")
					Shared.Message("taglines ERROR: Unable to access data.")
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
		pdr:Load(steamId, function(loadResponse)
			if loadResponse.success then
				local tagline = loadResponse.value
				if TGNS.HasNonEmptyValue(tagline.message) then
					unescapedTaglineMessages[client] = getUnescapedTaglineMessage(tagline.message)
				end
			else
				Shared.Message("taglines ERROR: Unable to access data.")
			end
		end)
	end
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("OnSlotTaken", function(client)
		if not TGNS.GetIsClientVirtual(client) then
			local connectedTimeInSeconds = Shared.GetSystemTime() - TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
			if connectedTimeInSeconds < 120 then
				local steamProfileName = Shine.Plugins.betterknownas and Shine.Plugins.betterknownas.GetSteamProfileName and Shine.Plugins.betterknownas:GetSteamProfileName(client)
				local steamProfileNameDisplay = (TGNS.HasNonEmptyValue(steamProfileName) and TGNS.ToLower(steamProfileName) ~= TGNS.ToLower(TGNS.GetClientName(client))) and string.format("    Steam: %s", steamProfileName) or ""
				local message = string.format("%s joined (%s)! %s", TGNS.GetClientName(client), TGNS.PlayerAction(client, TGNS.GetPlayerTeamName), steamProfileNameDisplay)
				tgnsMd:ToAllNotifyInfo(message)
				if TGNS.ClientCanRunCommand(client, "sh_taglineannounce") and TGNS.HasNonEmptyValue(unescapedTaglineMessages[client]) then
					tgnsMd:ToAllNotifyInfo(unescapedTaglineMessages[client])
				end
			end
		end
	end)
	self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("taglines", Plugin )