local function PlayerNameIsProhibited(name)
	for _,prohibitedName in ipairs(DAK.config.prohibitednames.kProhibitedNames) do
		if prohibitedName == name then
			return true
		end
	end
	return false
end

local function ProhibitedNamesOnClientDelayedConnect(client)
	local player = client:GetControllingPlayer()
	
	if PlayerNameIsProhibited(player:GetName()) then
		Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, DAK.config.prohibitednames.kProhibitedNamesWarnMessage), true)
	end
end
TGNS.RegisterEventHook("OnClientDelayedConnect", ProhibitedNamesOnClientDelayedConnect)

local function ProhibitedNamesOnTeamJoin(self, player, newTeamNumber, force)
	if PlayerNameIsProhibited(player:GetName()) and newTeamNumber ~= kTeamReadyRoom then
		local client = Server.GetOwner(player)
		client.disconnectreason = DAK.config.prohibitednames.kProhibitedNamesKickMessage
		Server.DisconnectClient(client)
	end
end
TGNS.RegisterEventHook("OnTeamJoin", ProhibitedNamesOnTeamJoin)

function ProhibitedNamesOnCommandSetName(client, message)
	local name = message.name
	if client ~= nil and name ~= nil then
		local player = client:GetControllingPlayer()
		if PlayerNameIsProhibited(name) then
			local gamerules = GetGamerules()
			if gamerules then
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, DAK.config.prohibitednames.kProhibitedNamesWarnMessage), true)
				gamerules:JoinTeam(player, kTeamReadyRoom)
			end
		end
	end
end
TGNS.RegisterNetworkMessageHook("SetName", ProhibitedNamesOnCommandSetName)