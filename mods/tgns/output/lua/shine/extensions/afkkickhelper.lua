local isAfkResetEnabled
local md
local lastWarnTimes = {}
local lastMoveTimes = {}
local mayEarnRemovedFromPlayByAfkKarma = {}

local function resetAfk(client)
	if isAfkResetEnabled and client then
		Shine.Plugins.afkkick:ResetAFKTime(client)
	end
end

local function getAfkThresholdInSeconds()
	local isAggressive = Shared.GetTime() - Shine.Plugins.timedstart:GetWhenFifteenSecondAfkTimerWasLastAdvertised() < 30
	if not TGNS.IsProduction() then
		-- isAggressive = true
	end
	local result = isAggressive and 15 or 60
	return result, isAggressive
end

local Plugin = {}

-- function Plugin:OnProcessMove(player, input)
-- 	if bit.band(input.commands, Move.Use) ~= 0 then
-- 		resetAfk(TGNS.GetClient(player))
-- 	end
-- end

function Plugin:PlayerSay(client, networkMessage)
	resetAfk(client)
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
    if TGNS.IsPlayerReadyRoom(player) then
    	if TGNS.IsGameInProgress() then
	    	if TGNS.IsGameplayTeamNumber(oldTeamNumber) and TGNS.GetCurrentGameDurationInSeconds() > 30 and TGNS.IsPlayerAFK(player) and #TGNS.GetPlayingClients(TGNS.GetPlayerList()) >= 7 and (not (force or shineForce)) then
	    		if mayEarnRemovedFromPlayByAfkKarma[client] then
		    		TGNS.Karma(client, "RemovedFromPlayByAFK")
		    		mayEarnRemovedFromPlayByAfkKarma[client] = false
	    		end
	    	end
	    else
	    	TGNS.MarkPlayerAFK(player)
    	end
    elseif not (force or shineForce) then
    	TGNS.ClearPlayerAFK(player)
    end
end

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create("AFK")

	TGNS.RegisterEventHook("AFKChanged", function(client, playerIsAfk)
		if client and not playerIsAfk then
			mayEarnRemovedFromPlayByAfkKarma[client] = true
		end
	end)

    TGNS.ScheduleAction(5, function()
    	isAfkResetEnabled = Shine.Plugins.afkkick and Shine.Plugins.afkkick.Enabled and Shine.Plugins.afkkick.ResetAFKTime
    end)
	local originalGetCanPlayerHearPlayer
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		resetAfk(TGNS.GetClient(speakerPlayer))
		return originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
	end)

	local processAfkPlayers
	processAfkPlayers = function()
		local afkThresholdInSeconds, isAggressive = getAfkThresholdInSeconds();
		local afkScenarioDescriptor = isAggressive and " (pre/early game)" or ""
		TGNS.ScheduleAction(isAggressive and 1 or 15, processAfkPlayers)
		TGNS.DoFor(TGNS.GetHumanClientList(), function(c)
			local p = TGNS.GetPlayer(c)
			if TGNS.IsPlayerAFK(p) then
				local lastMoveTime = Shine.Plugins.afkkick:GetLastMoveTime(c)
				if (lastMoveTime ~= nil) and (TGNS.GetSecondsSinceMapLoaded() - lastMoveTime >= afkThresholdInSeconds) and TGNS.ClientIsOnPlayingTeam(c) then
					local lastWarnTime = lastWarnTimes[c] or 0
					if Shared.GetTime() - lastWarnTime > 10 then
						md:ToPlayerNotifyInfo(p, string.format("AFK %s%s. Move to avoid being sent to Ready Room.", Pluralize(afkThresholdInSeconds, "second"), afkScenarioDescriptor))
						lastWarnTimes[c] = Shared.GetTime()
						local playAfkPingSoundToClient = function(level)
							if Shine:IsValidClient(c) and TGNS.IsClientAFK(c) and TGNS.ClientIsOnPlayingTeam(c) then
								TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(c), Shine.Plugins.arclight.HILL_SOUND, {i=level})
							end
						end
						TGNS.ScheduleAction(1, function() playAfkPingSoundToClient(6) end)
						TGNS.ScheduleAction(2, function() playAfkPingSoundToClient(5) end)
						TGNS.ScheduleAction(3, function() playAfkPingSoundToClient(4) end)
						TGNS.ScheduleAction(4, function() playAfkPingSoundToClient(3) end)
						TGNS.ScheduleAction(5, function() playAfkPingSoundToClient(2) end)
					end
					TGNS.ScheduleAction(6, function()
						if Shine:IsValidClient(c) then
							p = TGNS.GetPlayer(c)
							if TGNS.IsPlayerAFK(p) then
								local lastMoveTime = lastMoveTimes[c] or 0
								if Shared.GetTime() - lastMoveTime > 10 then
									md:ToPlayerNotifyInfo(p, string.format("AFK %s%s. Moved to Ready Room.", Pluralize(afkThresholdInSeconds, "second"), afkScenarioDescriptor))
									TGNS.SendToTeam(p, kTeamReadyRoom, true)
									lastMoveTimes[c] = Shared.GetTime()
								end
							end
						end
					end)
				end
			end
		end)
	end
	TGNS.ScheduleAction(15, processAfkPlayers)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("afkkickhelper", Plugin )