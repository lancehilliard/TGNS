local Plugin = Plugin

function Plugin:Initialise()
	self.Enabled = true

	local originalGUIScoreboardSendKeyEvent = GUIScoreboard.SendKeyEvent
	GUIScoreboard.SendKeyEvent = function(guiScoreboardSelf, key, down)
		if (GetIsBinding(key, "Reload")) and down and TGNS.Has({kTeamInvalid, kTeamReadyRoom}, Client.GetLocalClientTeamNumber()) and not ChatUI_EnteringChatMessage() then
			TGNS.SendNetworkMessage(Plugin.SPRAY_REQUESTED, {})
		end
		return originalGUIScoreboardSendKeyEvent(guiScoreboardSelf, key, down)
	end

	local originalClientCreateTimeLimitedDecal = Client.CreateTimeLimitedDecal
	Client.CreateTimeLimitedDecal = function(materialName, coords, scale, lifeTime)
		if TGNS.Contains(materialName, "ui/sprays/") then
			lifeTime = math.huge
		    local reUseDecals = { }
		    TGNS.DoFor(Client.timeLimitedDecals, function(decalEntry)
		        if decalEntry[2] > Shared.GetTime() and decalEntry[4] ~= materialName then
		            table.insert(reUseDecals, decalEntry)
		        else
		            Client.DestroyRenderDecal(decalEntry[1])
		        end
		    end)
		    Client.timeLimitedDecals = reUseDecals
		end
		originalClientCreateTimeLimitedDecal(materialName, coords, scale, lifeTime)
	end

	local originalReceiveCreateSpray = Shine.Plugins.readyroomrave.ReceiveCreateSpray
	Shine.Plugins.readyroomrave.ReceiveCreateSpray = function(ravePluginSelf, message)
		-- Shared.Message(string.format("Spray location: X: %s; Y: %s; Z: %s; Pitch: %s; Yaw: %s; Roll: %s", message.originX, message.originY, message.originZ, message.pitch, message.yaw, message.roll ))
		originalReceiveCreateSpray(ravePluginSelf, message)
	end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end