local isAfkResetEnabled

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

function Plugin:Initialise()
    self.Enabled = true
    TGNS.ScheduleAction(5, function()
    	isAfkResetEnabled = Shine.Plugins.afkkick and Shine.Plugins.afkkick.Enabled and Shine.Plugins.afkkick.ResetAFKTime
    end)
	local originalGetCanPlayerHearPlayer
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		resetAfk(TGNS.GetClient(speakerPlayer))
		return originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("afkkickhelper", Plugin )