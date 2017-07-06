local md = TGNSMessageDisplayer.Create()

local Plugin = {}
local PROHIBITED_PLAYER_NAMES = {"nsplayer", "nspiayer"}

local nameIsProhibited = function(player)
	local result = TGNS.Has(PROHIBITED_PLAYER_NAMES, TGNS.ToLower(TGNS.GetPlayerName(player)))
	return result
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	if nameIsProhibited(player) then
		md:ToPlayerNotifyError(player, string.format("%s: Default player name not allowed.", TGNS.GetPlayerName(player)))
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

Shine:RegisterExtension("prohibitednames", Plugin )