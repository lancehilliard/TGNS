local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	local originalGetCanAttack
	originalGetCanAttack = TGNS.ReplaceClassMethod("Player", "GetCanAttack", function(self)
		local result = originalGetCanAttack(self)
		if result and not TGNS.IsPlayerReadyRoom(self) then
			local isPreGame = GetGamerules():GetGameState() == kGameState.PreGame or GetGamerules():GetGameState() == kGameState.NotStarted
			result = not isPreGame
		end
		return result
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("noattackpregame", Plugin)