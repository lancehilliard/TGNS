local Plugin = Plugin

function Plugin:Initialise()
	self.Enabled = true

	if Shine.GetGamemode() == "Infested" then
		local originalGUIVoiceChatUpdate
		originalGUIVoiceChatUpdate = Class_ReplaceMethod("GUIVoiceChat", "Update", function(guivoicechatself, deltaTime)
			originalGUIVoiceChatUpdate(guivoicechatself, deltaTime)
			local statuses = {}
			TGNS.DoFor(ScoreboardUI_GetAllScores(), function(s)
				statuses[s.Name] = s.Status
			end)
			local deadStatus = Locale.ResolveString("STATUS_DEAD")
			local infestedStatus = Locale.ResolveString("STATUS_INFESTED") or "Infested"
			local localPlayer = Client.GetLocalPlayer()
			local localPlayerMayKnowWhoIsInfested = not (localPlayer:GetIsAlive() and (localPlayer:GetTeamNumber() == kMarineTeamType))

			TGNS.DoForPairs(guivoicechatself.chatBars, function(index, bar)
		        if bar.Background:GetIsVisible() then
			    	local chatBarPlayerName = bar.Name:GetText()
			    	local chatBarPlayerStatus = statuses[chatBarPlayerName]
			    	local newColor
			    	if chatBarPlayerStatus == deadStatus then
			    		newColor = Color(1, 0, 0, 1)
			    	end
			    	if newColor ~= nil then
			    		bar.Name:SetColor(newColor)
			    		bar.Icon:SetColor(newColor)
			    	end
		        end
			end)
		end)
	end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end