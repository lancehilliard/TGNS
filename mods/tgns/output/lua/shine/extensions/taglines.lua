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

local function ShowCurrentTagline(client)
	taglineMd:ToClientConsole(client, "Your current tagline:")
	local steamId = client:GetUserId()
	local tagline = pdr:Load(steamId)
	if tagline == nil or tagline.message == "" then
		taglineMd:ToClientConsole(client, "     You don't currently have a tagline saved.")
		taglineMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "You don't currently have a tagline saved.")
	else
		taglineMd:ToClientConsole(client, "     " .. tagline.message)
		taglineMd:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Your current tagline: " .. tagline.message)
	end
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
	taglineMd:ToClientConsole(client, "")
end

function Plugin:CreateCommands()
	local taglineCommand = self:BindCommand( "sh_tagline", "tagline", function(client, taglineMessage)
		local steamId = TGNS.GetClientSteamId(client)
		if taglineMessage == nil or taglineMessage == "" then
			ShowUsage(client)
		else
			local tagline = pdr:Load(steamId)
			if taglineMessage == "remove" then
				taglineMessage = ""
			end
			tagline.message = taglineMessage
			pdr:Save(tagline)
			ShowCurrentTagline(client)
		end
	end, true)
	taglineCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	taglineCommand:Help( "<tagline> Sets your tagline." )
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("OnSlotTaken", function(client)
		if not TGNS.GetIsClientVirtual(client) then
			local connectedTimeInSeconds = Shared.GetSystemTime() - TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
			if connectedTimeInSeconds < 120 then
				local message = TGNS.GetClientName(client) .. string.format(" joined (%s)!", TGNS.PlayerAction(client, TGNS.GetPlayerTeamName))
				if TGNS.ClientCanRunCommand(client, "sh_taglineannounce") then
					local steamId = TGNS.GetClientSteamId(client)
					local tagline = pdr:Load(steamId)
					if tagline ~= nil and tagline.message ~= "" then
						 message = message .. " " .. tagline.message
					end
				end
				tgnsMd:ToAllNotifyInfo(message)
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