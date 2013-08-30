local originalGetCanPlayerHearPlayer
	
local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		if listenerPlayer:GetTeamNumber() == kSpectatorIndex then
			result = true
		end
		return result
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("speclisten", Plugin )