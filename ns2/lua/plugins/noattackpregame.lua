local originalGetCanAttack

originalGetCanAttack = TGNS.ReplaceClassMethod("Player", "GetCanAttack",
	function(self)
		local preGame = GetGamerules():GetGameState() == kGameState.PreGame or GetGamerules():GetGameState() == kGameState.NotStarted
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
