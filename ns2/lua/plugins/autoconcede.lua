//NS2 Automatic Concede

local kConcedeTime = 0
local kConcedeTeam = 0
local kConcedeCheck = 0
local kConcedeMessage = 0
local kConcedeCheckInt = 1

local function OnPluginInitialized()

	local originalNS2GRCheckGameEnd
	
	originalNS2GRCheckGameEnd = DAK:Class_ReplaceMethod(DAK.config.loader.GamerulesClassName, "CheckGameEnd", 
		function(self)
		
			if self:GetGameStarted() and self.timeGameEnded == nil and not DAK:GetTournamentMode() and not Shared.GetCheatsEnabled() and not Shared.GetDevMode() and not self.preventGameEnd then
				if kConcedeCheck == nil or (Shared.GetTime() > kConcedeCheck + kConcedeCheckInt) then
					local team1Players = self.team1:GetNumPlayers()
					local team2Players = self.team2:GetNumPlayers()
					local totalCount = team1Players + team2Players
					local concede = 0
					if totalCount >= DAK.config.autoconcede.kMinimumPlayers then
						local playerdiff = team1Players - team2Players
						if Sign(playerdiff) == 1 and math.abs(playerdiff) >= DAK.config.autoconcede.kImbalanceAmount then
							concede = 2
						elseif Sign(playerdiff) == -1 and math.abs(playerdiff) >= DAK.config.autoconcede.kImbalanceAmount then
							concede = 1
						end
					end
					if kConcedeTime == 0 then
						if concede ~= 0 then
							DAK:DisplayMessageToAllClients("ConcedeWarningMessage", DAK.config.autoconcede.kImbalanceDuration)
							kConcedeTeam = concede
							kConcedeTime = Shared.GetTime()
							kConcedeMessage = Shared.GetTime()
						end
					elseif Shared.GetTime() - kConcedeMessage > DAK.config.autoconcede.kImbalanceNotification then
						if concede ~= 0 then
							DAK:DisplayMessageToAllClients("ConcedeWarningMessage", (DAK.config.autoconcede.kImbalanceDuration - (Shared.GetTime() - kConcedeTime)))
							kConcedeMessage = Shared.GetTime()
						end
					else
						if concede == 0 or kConcedeTeam ~= concede then
							DAK:DisplayMessageToAllClients("ConcedeCancelledMessage")
							kConcedeTeam = 0
							kConcedeTime = 0
							kConcedeMessage = 0
						end
					end
					if kConcedeTime ~= 0 and Shared.GetTime() - kConcedeTime > DAK.config.autoconcede.kImbalanceDuration then
						DAK:DisplayMessageToAllClients("ConcedeMessage")
						if kConcedeTeam == 2 then
							self:EndGame(self.team2)
						elseif kConcedeTeam == 1 then
							self:EndGame(self.team1)
						end
						kConcedeTeam = 0
						kConcedeTime = 0
						kConcedeMessage = 0
					end
					kConcedeCheck = Shared.GetTime()
				end
			end

			originalNS2GRCheckGameEnd( self )
		
		end
	)

end

if DAK.config and DAK.config.loader and DAK.config.loader.GamerulesExtensions then
	DAK:RegisterEventHook("OnPluginInitialized", OnPluginInitialized, 5, "autoconcede")
end