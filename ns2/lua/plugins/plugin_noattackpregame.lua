if kDAKConfig and kDAKConfig.NoAttackPregame then

	local originalGetCanAttack
	
	originalGetCanAttack = Class_ReplaceMethod("Player", "GetCanAttack",
		function(self)
			local preGame = GetGamerules():GetGameState() == kGameState.PreGame
			local canAttack = originalGetCanAttack(self) and not preGame
			
			/*
			if preGame then
				Shared.Message("Pregame")
			else
				Shared.Message("NOT Pregame");
			end

			if canAttack then
				Shared.Message("Can Attack")
			else
				Shared.Message("Can NOT Attack");
			end
			*/
			
			return canAttack
		end
	)
	
end

Shared.Message("NoAttackPregame Loading Complete")