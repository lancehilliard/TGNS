// allow SMs a moment to join a team before other players get a chance

if kDAKConfig and kDAKConfig.StagedTeamJoins then
	Script.Load("lua/TGNSCommon.lua")

	local FIRSTCLIENT_TIME_BEFORE_ALLJOIN = 30
	local GAMEEND_TIME_BEFORE_ALLJOIN = 23
	local allMayJoinAt = 0
	local firstClientProcessed = false

	local function StagedTeamJoinsOnClientDelayedConnect(client)
		if not firstClientProcessed then
			allMayJoinAt = Shared.GetTime() + FIRSTCLIENT_TIME_BEFORE_ALLJOIN
			firstClientProcessed = true
		end
	end
	DAKRegisterEventHook("kDAKOnClientDelayedConnect", StagedTeamJoinsOnClientDelayedConnect, 5)

	function StagedTeamJoinsGameEnd()
		allMayJoinAt = Shared.GetTime() + GAMEEND_TIME_BEFORE_ALLJOIN
	end
	DAKRegisterEventHook("kDAKOnGameEnd", StagedTeamJoinsGameEnd, 5)

	local function StagedTeamJoinsOnTeamJoin(self, player, newTeamNumber, force)
		local cancel = false
		local balanceIsInProgress = Balance and Balance.IsInProgress()
		if not balanceIsInProgress then
			if TGNS.IsGameplayTeam(newTeamNumber) then
				local atLeastOneSmIsOnTheServer = TGNS.Any(TGNS.GetPlayerList(), function(p) return TGNS.ClientAction(p, TGNS.IsClientSM) end)
				if atLeastOneSmIsOnTheServer then
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
	DAKRegisterEventHook("kDAKOnTeamJoin", StagedTeamJoinsOnTeamJoin, 5)

end

Shared.Message("StagedTeamJoins Loading Complete")