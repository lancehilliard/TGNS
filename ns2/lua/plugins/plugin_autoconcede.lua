//NS2 Automatic Concede

if kDAKConfig and kDAKConfig.AutoConcede then

	local kConcedeTime = 0
	local kConcedeTeam = 0
	local kConcedeCheck = 0
	local kConcedeCheckInt = 1

	if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.GamerulesExtensions then
	
		local originalNS2GRCheckGameEnd
		
		originalNS2GRCheckGameEnd = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "CheckGameEnd", 
			function(self)
			
				if self:GetGameStarted() and self.timeGameEnded == nil and not Shared.GetCheatsEnabled() and not self.preventGameEnd then
					if kConcedeCheck == nil or (Shared.GetTime() > kConcedeCheck + kConcedeCheckInt) then
					    local team1Players = self.team1:GetNumPlayers()
						local team2Players = self.team2:GetNumPlayers()
						local totalCount = team1Players + team2Players
						local concede = 0
						if totalCount >= kDAKConfig.AutoConcede.kMinimumPlayers then
							local playerdiff = team1Players - team2Players
							if Sign(playerdiff) == 1 and math.abs(playerdiff) >= kDAKConfig.AutoConcede.kImbalanceAmount then
								concede = 2
							elseif Sign(playerdiff) == -1 and math.abs(playerdiff) >= kDAKConfig.AutoConcede.kImbalanceAmount then
								concede = 1
							end
						end
						if kConcedeTime == 0 then
							if concede ~= 0 then
								DAKDisplayMessageToAllClients("kConcedeWarningMessage", kDAKConfig.AutoConcede.kImbalanceDuration)
								kConcedeTeam = concede
								kConcedeTime = Shared.GetTime()
							end
						else
							if concede == 0 or kConcedeTeam ~= concede then
								DAKDisplayMessageToAllClients("kConcedeCancelledMessage")
								kConcedeTeam = 0
								kConcedeTime = 0
							end
						end
					    if kConcedeTime ~= 0 and Shared.GetTime() - kConcedeTime > kDAKConfig.AutoConcede.kImbalanceDuration then
							DAKDisplayMessageToAllClients("kConcedeMessage")
							if kConcedeTeam == 2 then
								self:EndGame(self.team2)
							elseif kConcedeTeam == 1 then
								self:EndGame(self.team1)
							end
							kConcedeTeam = 0
							kConcedeTime = 0
						end
						kConcedeCheck = Shared.GetTime()
					end
				end

				originalNS2GRCheckGameEnd( self )
			
			end
		)
    
	end
	
end

Shared.Message("AutoConcede Loading Complete")