local allowPostGameAttacksUntil = 0

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true

	local originalHandleAttacks
	originalHandleAttacks = TGNS.ReplaceClassMethod("Player", "HandleAttacks", function(self, input)
		local allow
		if TGNS.IsPlayerReadyRoom(self) then
			allow = true
		else
			local isPreGame = GetGamerules():GetGameState() == kGameState.PreGame or GetGamerules():GetGameState() == kGameState.NotStarted
			if isPreGame then
				local skulkIsLeaping = (bit.band(input.commands, Move.SecondaryAttack) ~= 0 or self.secondaryAttackLastFrame) and self:isa("Skulk")
				if skulkIsLeaping then
					allow = true
				end
			else
				allow = true
			end
		end
		if allow then
			originalHandleAttacks(self, input)
		end
	end)

	local originalCanEntityDoDamageTo = CanEntityDoDamageTo
	CanEntityDoDamageTo = function(attacker, target, cheats, devMode, friendlyFire, damageType)
		local result = originalCanEntityDoDamageTo(attacker, target, cheats, devMode, friendlyFire, damageType)
		if not result then
			result = (not GetGameInfoEntity():GetGameStarted() and not GetGameInfoEntity():GetWarmUpActive() and allowPostGameAttacksUntil > Shared.GetTime()) or TGNS.IsPlayerReadyRoom(attacker)
		end
		return result
	end

    return true
end

function Plugin:EndGame(gamerules, winningTeam)
	allowPostGameAttacksUntil = Shared.GetTime() + TGNS.ENDGAME_TIME_TO_READYROOM - 0.5
end


function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("noattackpregame", Plugin)