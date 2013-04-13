if DAK.config.loader and DAK.config.loader.GamerulesClassName then
	TGNS.ReplaceClassMethod(DAK.config.loader.GamerulesClassName, "GetCanPlayerHearPlayer", 
		function(self, listenerPlayer, speakerPlayer)

			local canHear = false
			
			// Check if the listener has the speaker muted.
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
			
			if DAK.settings and DAK.settings.AllTalk then
				canHear = true
			end
			
			// If we're spectating, we can hear any player
			if listenerPlayer:GetTeamNumber() == kSpectatorIndex then
				canHear = true
			end
			
			return canHear
			
		end
	)
end
