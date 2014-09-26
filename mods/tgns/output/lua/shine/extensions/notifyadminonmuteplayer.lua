local md

local function OnMutePlayer(client, networkMessage)
	clientIndex, isMuted = ParseMutePlayerMessage(networkMessage)
	for _, player in pairs(TGNS.GetPlayerList()) do
		if player:GetClientIndex() == clientIndex then
			if isMuted then
				muteText = "muted"
			else
				muteText = "unmuted"
			end
			local sourcePlayer = TGNS.GetPlayer(client)
			if TGNS.PlayerIsOnPlayingTeam(sourcePlayer) and TGNS.PlayersAreTeammates(sourcePlayer, player) then
				local message = string.format("%s has %s %s.", TGNS.GetClientName(client), muteText, TGNS.GetPlayerName(player))
				md:ToAuthorizedNotifyInfo(message, "sh_mutes")
			end
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
						if TGNS.PlayersAreTeammates(sourcePlayer, targetPlayer) and not TGNS.IsPlayerSpectator(sourcePlayer) then
							if sourcePlayer:GetClientMuted(targetPlayer:GetClientIndex()) then
								table.insert(result, { sourcePlayer = sourcePlayer, targetPlayer = targetPlayer })
							end
						end
				end)
			end
		end
	)
	return result
end

local function GetPlayerMuteMessage(playerMute)
	local result = string.format("%s has %s muted.", TGNS.GetPlayerName(playerMute.sourcePlayer), TGNS.GetPlayerName(playerMute.targetPlayer))
	return result
end

local function TellAdminsAboutPlayerMutes()
	local playerMutes = GetPlayerMutes()
	if #playerMutes > 0 then
		local firstPlayerMute = TGNS.GetFirst(playerMutes)
		md:ToAdminNotifyInfo(GetPlayerMuteMessage(firstPlayerMute))
		TGNS.DoFor(playerMutes, function(m)
				md:ToAdminConsole(GetPlayerMuteMessage(m))
		end)
	end
end

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
    md = TGNSMessageDisplayer.Create("MUTES")
    TGNS.ScheduleActionInterval(30, TellAdminsAboutPlayerMutes)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("notifyadminonmuteplayer", Plugin )