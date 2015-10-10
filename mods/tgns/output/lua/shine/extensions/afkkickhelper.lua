local isAfkResetEnabled
local md
local lastWarnTimes = {}
local lastMoveTimes = {}

local function resetAfk(client)
	if isAfkResetEnabled and client then
		Shine.Plugins.afkkick:ResetAFKTime(client)
	end
end

local function getAfkThresholdInSeconds()
	local isEarlyGame = TGNS.IsGameInCountdown() or (TGNS.IsGameInProgress() and TGNS.GetCurrentGameDurationInSeconds() < 30)
	local result = isEarlyGame and 15 or 60
	return result, isEarlyGame
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
    if TGNS.IsPlayerReadyRoom(player) then
    	TGNS.MarkPlayerAFK(player)
    elseif not (force or shineForce) then
    	TGNS.ClearPlayerAFK(player)
    end
end

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create("AFK")
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
		local afkThresholdInSeconds, isEarlyGame = getAfkThresholdInSeconds();
		TGNS.ScheduleAction(isEarlyGame and 1 or 15, processAfkPlayers)
		TGNS.DoFor(TGNS.GetHumanClientList(), function(c)
			local p = TGNS.GetPlayer(c)
			if TGNS.IsPlayerAFK(p) then
				local lastMoveTime = Shine.Plugins.afkkick:GetLastMoveTime(c)
				if (lastMoveTime ~= nil) and (TGNS.GetSecondsSinceMapLoaded() - lastMoveTime >= afkThresholdInSeconds) and TGNS.ClientIsOnPlayingTeam(c) then
					local lastWarnTime = lastWarnTimes[c] or 0
					if Shared.GetTime() - lastWarnTime > 10 then
						md:ToPlayerNotifyInfo(p, string.format("AFK %s. Move to avoid being sent to Ready Room.", Pluralize(afkThresholdInSeconds, "second")))
						lastWarnTimes[c] = Shared.GetTime()
					end
					TGNS.ScheduleAction(6, function()
						if Shine:IsValidClient(c) then
							p = TGNS.GetPlayer(c)
							if TGNS.IsPlayerAFK(p) then
								local lastMoveTime = lastMoveTimes[c] or 0
								if Shared.GetTime() - lastMoveTime > 10 then
									md:ToPlayerNotifyInfo(p, string.format("AFK %s. Moved to Ready Room.", Pluralize(afkThresholdInSeconds, "second")))
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