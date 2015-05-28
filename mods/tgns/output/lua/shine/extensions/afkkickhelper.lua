local isAfkResetEnabled
local md
local afkThresholdInMinutes = 1

local function resetAfk(client)
	if isAfkResetEnabled and client then
		Shine.Plugins.afkkick:ResetAFKTime(client)
	end
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

	TGNS.ScheduleActionInterval(15, function()
		TGNS.DoFor(TGNS.GetClientList(), function(c)
			local p = TGNS.GetPlayer(c)
			if TGNS.IsPlayerAFK(p) then
				local lastMoveTime = Shine.Plugins.afkkick:GetLastMoveTime(c)
				if (lastMoveTime ~= nil) and (TGNS.GetSecondsSinceMapLoaded() - lastMoveTime >= TGNS.ConvertMinutesToSeconds(afkThresholdInMinutes)) and TGNS.ClientIsOnPlayingTeam(c) then
					md:ToPlayerNotifyInfo(p, string.format("AFK %s minute. Move to avoid being sent to Ready Room.", afkThresholdInMinutes))
					TGNS.ScheduleAction(6, function()
						if Shine:IsValidClient(c) then
							p = TGNS.GetPlayer(c)
							if TGNS.IsPlayerAFK(p) then
								md:ToPlayerNotifyInfo(p, string.format("AFK %s minute. Moved to Ready Room.", afkThresholdInMinutes))
								TGNS.SendToTeam(p, kTeamReadyRoom, true)
							end
						end
					end)
				end
			end
		end)
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("afkkickhelper", Plugin )