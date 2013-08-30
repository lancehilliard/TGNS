local md = TGNSMessageDisplayer.Create("MUTES")

local function OnMutePlayer(client, networkMessage)
	clientIndex, isMuted = ParseMutePlayerMessage(networkMessage)
	for _, player in pairs(TGNS.GetPlayerList()) do
		if player:GetClientIndex() == clientIndex then
			if isMuted then
				muteText = "muted"
			else
				muteText = "unmuted"
			end
			local message = string.format("%s has %s %s.", TGNS.GetClientName(client), muteText, TGNS.GetPlayerName(player))
			md:ToAuthorizedNotifyInfo(message, "sh_mutes")
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
	local playerMutes = GetPlayerMutes()
	if TGNS.Any(playerMutes) then
		local firstPlayerMute = playerMutes[1]
		TGNS.SendAdminChat(GetPlayerMuteMessage(firstPlayerMute))
		TGNS.DoFor(playerMutes, function(m)
				md:ToAdminNotifyInfo(GetPlayerMuteMessage(m))
			end
		)
	end		
end
TGNS.ScheduleActionInterval(30, TellAdminsAboutPlayerMutes)

//local function ListMutes(client)
//	// build look up table for player names by clientindex
//	playerNames = {}
//	
//	ServerAdminPrint(client, "Player Mutes:")
//	for _, player in pairs(TGNS.GetPlayerList()) do
//		playerNames[player:GetClientIndex()] = player:GetName()
//	end
//	for _, player in pairs(TGNS.GetPlayerList()) do
//		for clientIndex, name in pairs(playerNames) do
//			if player:GetClientMuted(clientIndex) then
//				ServerAdminPrint(client, player:GetName() .. " : " .. name)
//			end
//		end
//	end
//end
//TGNS.RegisterCommandHook("Console_sv_mutes", ListMutes, help)

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("notifyadminonmuteplayer", Plugin )