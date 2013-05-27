Script.Load("lua/TGNSCommon.lua")

local FIRSTCLIENT_TIME_BEFORE_ALLJOIN = 60
local GAMEEND_TIME_BEFORE_ALLJOIN = 33
local allMayJoinAt = Shared.GetSystemTime() + FIRSTCLIENT_TIME_BEFORE_ALLJOIN
local firstClientProcessed = false

local function StagedTeamJoinsOnClientDelayedConnect(client)
	if not firstClientProcessed then
		allMayJoinAt = Shared.GetTime() + FIRSTCLIENT_TIME_BEFORE_ALLJOIN
		firstClientProcessed = true
	end
end
TGNS.RegisterEventHook("OnClientDelayedConnect", StagedTeamJoinsOnClientDelayedConnect)

function StagedTeamJoinsGameEnd()
	allMayJoinAt = Shared.GetTime() + GAMEEND_TIME_BEFORE_ALLJOIN
end
TGNS.RegisterEventHook("OnGameEnd", StagedTeamJoinsGameEnd)

local function StagedTeamJoinsOnTeamJoin(self, player, newTeamNumber, force)
	local cancel = false
	local balanceIsInProgress = Balance and Balance.IsInProgress()
	if not balanceIsInProgress and not TGNS.ClientAction(player, TGNS.GetIsClientVirtual) and not TGNS.IsGameInCountdown() and not TGNS.IsGameInProgress() then
		if TGNS.IsGameplayTeam(newTeamNumber) then
			if TGNS.Any(TGNS.GetReadyRoomClients(TGNS.GetPlayerList()), TGNS.IsClientSM) then
				local secondsRemainingBeforeAllMayJoin = math.floor(allMayJoinAt - Shared.GetTime())
				if secondsRemainingBeforeAllMayJoin > 0 then
					if not TGNS.ClientAction(player, TGNS.IsClientSM) then
						local chatMessage = string.format("Supporting Members may join teams now. Wait %s seconds and try again.", secondsRemainingBeforeAllMayJoin)
						TGNS.SendChatMessage(player, chatMessage, "TGNS")
						TGNS.RespawnPlayer(player)
						cancel = true
					end
				end
			end
		end
	end
	return cancel
end
TGNS.RegisterEventHook("OnTeamJoin", StagedTeamJoinsOnTeamJoin)