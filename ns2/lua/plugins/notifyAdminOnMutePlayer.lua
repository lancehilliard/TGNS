Script.Load("lua/TGNSCommon.lua")

local function OnMutePlayer(client, networkMessage)
	clientIndex, isMuted = ParseMutePlayerMessage(networkMessage)
	for _, player in pairs(TGNS.GetPlayerList()) do
		if player:GetClientIndex() == clientIndex then
			if isMuted then
				muteText = "muted"
			else
				muteText = "unmuted"
			end
			TGNS.PMAllPlayersWithAccess(nil, client:GetControllingPlayer():GetName() .. " has " .. muteText .. " player " .. player:GetName(), "sv_mutes", false)
			break
		end
	end
end
TGNS.RegisterNetworkMessageHook("MutePlayer", OnMutePlayer, 5)

local function GetPlayerMutes()
	local result = {}
	local playerList = TGNS.GetPlayerList()
	TGNS.DoFor(playerList, function(sourcePlayer)
			if sourcePlayer then
				TGNS.DoFor(playerList, function(targetPlayer)
						if sourcePlayer:GetClientMuted(targetPlayer:GetClientIndex()) then
							table.insert(result, { sourcePlayer = sourcePlayer, targetPlayer = targetPlayer })
						end
				end)
			end
		end
	)
	return result
end

function GetPlayerMuteMessage(playerMute)
	local result = string.format("%s has %s muted.", TGNS.GetPlayerName(playerMute.sourcePlayer), TGNS.GetPlayerName(playerMute.targetPlayer))
	return result
end

function TellAdminsAboutPlayerMutes()
	TGNS.ScheduleAction(30, TellAdminsAboutPlayerMutes)
	local playerMutes = GetPlayerMutes()
	if TGNS.Any(playerMutes) then
		local firstPlayerMute = playerMutes[1]
		TGNS.SendAdminChat(GetPlayerMuteMessage(firstPlayerMute))
		TGNS.DoFor(playerMutes, function(m)
				TGNS.SendAdminConsoles(GetPlayerMuteMessage(m), "MUTES")
			end
		)
	end		
end
TGNS.ScheduleAction(60, TellAdminsAboutPlayerMutes)

local function ListMutes(client)
	// build look up table for player names by clientindex
	playerNames = {}
	
	ServerAdminPrint(client, "Player Mutes:")
	for _, player in pairs(TGNS.GetPlayerList()) do
		playerNames[player:GetClientIndex()] = player:GetName()
	end
	for _, player in pairs(TGNS.GetPlayerList()) do
		for clientIndex, name in pairs(playerNames) do
			if player:GetClientMuted(clientIndex) then
				ServerAdminPrint(client, player:GetName() .. " : " .. name)
			end
		end
	end
end
TGNS.RegisterCommandHook("Console_sv_mutes", ListMutes, help)