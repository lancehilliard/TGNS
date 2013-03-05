Script.Load("lua/TGNSCommon.lua")

local function PrintableNamesOnClientDelayedConnect(client)
	local player = client:GetControllingPlayer()

	local _, nonPrintableCharactersCount = string.gsub(player:GetName(), "[^\32-\126]", "")

	if nonPrintableCharactersCount>0 then
		TGNS.SendChatMessage(player, DAK.config.printablenames.kPrintableNamesWarnMessage)
	end
end
TGNS.RegisterEventHook("OnClientDelayedConnect", PrintableNamesOnClientDelayedConnect)

local function PrintableNamesOnTeamJoin(self, player, newTeamNumber, force)
	local _, nonPrintableCharactersCount = string.gsub(player:GetName(), "[^\32-\126]", "")
	if nonPrintableCharactersCount>0 and newTeamNumber ~= kTeamReadyRoom then
		local client = Server.GetOwner(player)
		client.disconnectreason = DAK.config.printablenames.kPrintableNamesKickMessage
		Server.DisconnectClient(client)
	end
end
TGNS.RegisterEventHook("OnTeamJoin", PrintableNamesOnTeamJoin)

local function PrintableNamesOnCommandSetName(client, message)
    local name = message.name
	if client ~= nil and name ~= nil then
		local player = client:GetControllingPlayer()
		local _, nonPrintableCharactersCount = string.gsub(name, "[^\32-\126]", "")
		if nonPrintableCharactersCount>0 then
			local gamerules = GetGamerules()
			if gamerules then
				TGNS.SendChatMessage(player, DAK.config.printablenames.kPrintableNamesWarnMessage)
				gamerules:JoinTeam(player, kTeamReadyRoom)
			end
		end
	end
    
end
TGNS.RegisterNetworkMessageHook("SetName", PrintableNamesOnCommandSetName)