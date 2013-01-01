// replaceGetCanPlayerHearPlayer

if kDAKConfig and kDAKConfig.replaceGetCanPlayerHearPlayer then
	if kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.GamerulesClassName then
		Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "GetCanPlayerHearPlayer", 
			function(self, listenerPlayer, speakerPlayer)

				local canHear = false
				
				// Check if the listerner has the speaker muted.
				if listenerPlayer:GetClientMuted(speakerPlayer:GetClientIndex()) then
					return false
				end
				
				// If both players have the same team number, they can hear each other
				if(listenerPlayer:GetTeamNumber() == speakerPlayer:GetTeamNumber()) then
					canHear = true
				end
					
				// Or if cheats or dev mode is on, they can hear each other
				if(Shared.GetCheatsEnabled() or Shared.GetDevMode()) then
					canHear = true
				end
				
				if kDAKSettings and kDAKSettings.AllTalk then
					canHear = true
				end
				
				// If we're spectating, we can hear any player not in the ready room
				if listenerPlayer:GetTeamNumber() == kSpectatorIndex and speakerPlayer:GetTeamNumber() ~= kTeamReadyRoom then
					canHear = true
				end
				
				return canHear
				
			end
		)
	end
end

Shared.Message("replaceGetCanPlayerHearPlayer Loading Complete")