Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSPlayerDataRepository.lua")
Script.Load("lua/TGNSMessageDisplayer.lua")
Script.Load("lua/TGNSConnectedTimesTracker.lua")

local pdr = TGNSPlayerDataRepository.Create("taglines", function(tagline)
	tagline.message = tagline.message ~= nil and tagline.message or ""
	return tagline
end)

local tgnsMd = TGNSMessageDisplayer.Create("TGNS")
	
local function GetTaglineMessage(...)
	local result = ""
	local concatenation = StringConcatArgs(...)
	if concatenation then
		result = concatenation
	end
	return result
end

local function ShowCurrentTagline(client)
	TGNS.ConsolePrint(client, "Your current tagline:", "TAGLINE")
	local steamId = client:GetUserId()
	local tagline = pdr:Load(steamId)
	if tagline == nil or tagline.message == "" then
		ServerAdminPrint(client, "[TAGLINE]     You don't currently have a tagline saved.")
	else
		ServerAdminPrint(client, "[TAGLINE]     " .. tagline.message)
	end
end

local function ShowUsage(client) 
	ServerAdminPrint(client, "[TAGLINE]")
	ServerAdminPrint(client, "[TAGLINE] Usage:")
	ServerAdminPrint(client, "[TAGLINE]     sv_tagline <whatever you want all players to see when you join as a Supporting Member>")
	ServerAdminPrint(client, "[TAGLINE] Notes:")
	ServerAdminPrint(client, "[TAGLINE] * Any length may be saved, but displayed character count is dictated by NS2 and may change in the future.")
	ServerAdminPrint(client, "[TAGLINE] * Taglines do not display to players in the first two minutes after a map loads")
	ServerAdminPrint(client, "[TAGLINE] * To remove your tagline at any time: sv_tagline remove")
	ShowCurrentTagline(client)
	ServerAdminPrint(client, "[TAGLINE]")
end

local function svTagline(client, ...)
	local steamId = client:GetUserId()
	local taglineMessage = GetTaglineMessage(...)
	if taglineMessage == "" then
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
end
TGNS.RegisterCommandHook("Console_sv_tagline", svTagline, "<tagline> Sets your tagline.", true)

local function TaglinesOnClientDelayedConnect(client)
	local player = TGNS.GetPlayer(client)
	local message = TGNS.GetPlayerName(player) .. " joined!"
	if TGNS.ClientCanRunCommand(client, "sv_taglineannounce") and TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client) < 120 then
		local steamId = client:GetUserId()
		local tagline = pdr:Load(steamId)
		if tagline ~= nil and tagline.message ~= "" then
			 message = message .. " " .. tagline.message
		end
	end
	if TGNS.IsClientStranger(client) then
		message = message .. " Please DO use 'gb' responsibly."
	end
	tgnsMd:ToAllChat(message)
end
TGNS.RegisterEventHook("OnClientDelayedConnect", TaglinesOnClientDelayedConnect)