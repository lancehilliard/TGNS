local Plugin = Plugin

function Plugin:Initialise()
	self.Enabled = true

	GhostModelUI_GetTunnelText = function()
		local result = "" -- "Crouch while building to preserve the oldest entrance"
		local player = Client.GetLocalPlayer()
		if player and player.GetGhostModelTechId and player:GetGhostModelTechId() == kTechId.GorgeTunnel then
			local playerTunnelDescriptions = Shine.Plugins.scoreboard:GetTunnelDescriptions(Client.GetLocalClientIndex())
			if TGNS.HasNonEmptyValue(playerTunnelDescriptions) then
				if TGNS.Contains(playerTunnelDescriptions, " / ") then
					local playerTunnelDescriptionParts = TGNS.Split(" / ", playerTunnelDescriptions)
					if #playerTunnelDescriptionParts == 2 then
						local olderEntrance = playerTunnelDescriptionParts[1]
						local newerEntrance = TGNS.Replace(playerTunnelDescriptionParts[2], "/ ", "")
						result = string.format("open a tunnel to %s%s", player:GetCrouching() and olderEntrance or newerEntrance, olderEntrance == newerEntrance and "" or string.format(" (%s for %s)", player:GetCrouching() and "release" or "crouch", player:GetCrouching() and newerEntrance or olderEntrance))
					end
				else
					local entranceToConnectTo = playerTunnelDescriptions
					result = string.format("open a tunnel to %s", entranceToConnectTo)
				end
			end
		end
		return result
	end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end