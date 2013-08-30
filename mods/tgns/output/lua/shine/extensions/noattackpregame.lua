local originalGetCanAttack

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	originalGetCanAttack = TGNS.ReplaceClassMethod("Player", "GetCanAttack", function(self)
		local preGame = GetGamerules():GetGameState() == kGameState.PreGame or GetGamerules():GetGameState() == kGameState.NotStarted
		local canAttack = originalGetCanAttack(self) and not preGame
		return canAttack
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("noattackpregame", Plugin)