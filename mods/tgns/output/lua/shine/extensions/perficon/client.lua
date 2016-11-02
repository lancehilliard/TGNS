local Plugin = Plugin

function Plugin:Initialise()
	self.Enabled = true

	local originalGUIIssuesDisplayUpdate = GUIIssuesDisplay.Update
	GUIIssuesDisplay.Update = function(guiIssuesDisplaySelf, deltaTime)
		originalGUIIssuesDisplayUpdate(guiIssuesDisplaySelf, deltaTime)
		if not TGNS.IsGameInProgress() and guiIssuesDisplaySelf.serverPerformanceProblemsIcon then
			guiIssuesDisplaySelf.serverPerformanceProblemsIcon:SetIsVisible(false)
		end
	end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end