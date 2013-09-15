//local FIRSTCLIENT_TIME_BEFORE_ALLJOIN = 45
local GAMEEND_TIME_BEFORE_ALLJOIN = TGNS.ENDGAME_TIME_TO_READYROOM + 5
local allMayJoinAt = 0 // Shared.GetSystemTime() + FIRSTCLIENT_TIME_BEFORE_ALLJOIN
//local firstClientProcessed = false
local md = TGNSMessageDisplayer.Create()

local Plugin = {}

//function Plugin:ClientConnect(client)
//	if not firstClientProcessed then
//		allMayJoinAt = Shared.GetTime() + FIRSTCLIENT_TIME_BEFORE_ALLJOIN
//		firstClientProcessed = true
//	end
//end

function atLeastOneSupportingMemberIsPresent()
	local result = TGNS.Any(TGNS.GetReadyRoomClients(TGNS.GetPlayerList()), TGNS.IsClientSM)
	return result
end

function Plugin:EndGame(gamerules, winningTeam)
	allMayJoinAt = Shared.GetTime() + GAMEEND_TIME_BEFORE_ALLJOIN
	TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 2.5, function()
		if atLeastOneSupportingMemberIsPresent() then
			md:ToAllNotifyInfo("Supporting Members get just a few seconds to join their team of choice.")
		end
	end)
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local cancel = false
	local balanceIsInProgress = Balance and Balance.IsInProgress()
	if not force and not shineForce and not balanceIsInProgress and not TGNS.ClientAction(player, TGNS.GetIsClientVirtual) and not TGNS.IsGameInCountdown() and not TGNS.IsGameInProgress() then
		if TGNS.IsGameplayTeamNumber(newTeamNumber) then
			if atLeastOneSupportingMemberIsPresent() then
				local secondsRemainingBeforeAllMayJoin = math.floor(allMayJoinAt - Shared.GetTime())
				if secondsRemainingBeforeAllMayJoin > 0 then
					if not TGNS.ClientAction(player, TGNS.IsClientSM) then
						local chatMessage = string.format("Supporting Members may join teams now. Wait %s seconds and try again.", secondsRemainingBeforeAllMayJoin)
						md:ToPlayerNotifyError(player, chatMessage)
						TGNS.RespawnPlayer(player)
						cancel = true
					end
				end
			end
		end
	end
	if cancel then
		return false
	end
end

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("stagedteamjoins", Plugin )