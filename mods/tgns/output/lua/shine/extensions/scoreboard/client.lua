local Plugin = Plugin

local prefixes = {}
local isCaptainsCaptain = {}
local isApproved = {}
local approveReceivedTotal = 0
local approveSentTotal = 0
local APPROVE_TEXTURE_DISABLED = "ui/approve/chevron-disabled.dds"

local CaptainsCaptainFontColor = Color(0, 1, 0, 1)

TGNS.HookNetworkMessage(Shine.Plugins.scoreboard.SCOREBOARD_DATA, function(message)
	prefixes[message.i] = message.p
	isCaptainsCaptain[message.i] = message.c
end)

local function getTeamApproveTexture(teamNumber)
	local result = string.format("ui/approve/chevron-team%s.dds", teamNumber)
	return result
end

function Plugin:Initialise()
	self.Enabled = true
	-- lua\GUIScoreboard.lua
	local originalGUIScoreboardUpdateTeam = GUIScoreboard.UpdateTeam
	GUIScoreboard.UpdateTeam = function(self, updateTeam)
		originalGUIScoreboardUpdateTeam(self, updateTeam)
		local playerList = updateTeam["PlayerList"]
		local teamScores = updateTeam["GetScores"]()
		local teamNumber = updateTeam["TeamNumber"]
		local currentPlayerIndex = 1
		local playerApproveReceiveTotalItemPosition
		for index, player in pairs(playerList) do
	        local playerRecord = teamScores[currentPlayerIndex]
	        local clientIndex = playerRecord.ClientIndex
	        -- Shared.Message(string.format("%s: %s", playerRecord.Name, clientIndex))
	        local prefix = prefixes[clientIndex]
	        player["Number"]:SetText(TGNS.HasNonEmptyValue(prefix) and prefix or "")
	        local numberColor = Color(0.5, 0.5, 0.5, 1)
	        if isCaptainsCaptain[clientIndex] == true then
	        	numberColor = CaptainsCaptainFontColor
	        end
	        player["Number"]:SetColor(numberColor)

	        local playerApproveIcon = player["PlayerApproveIcon"]
	        if playerApproveIcon then
				local playerIsBot = playerRecord.Ping == 0 or string.sub(playerRecord.Name,1,5)=="[BOT]"
	        	local playerApproveIconShouldDisplay = (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot)
	        	playerApproveIcon:SetIsVisible(playerApproveIconShouldDisplay)
		        playerApproveIcon:SetTexture(isApproved[clientIndex] and APPROVE_TEXTURE_DISABLED or getTeamApproveTexture(teamNumber))
	        end
	        local playerApproveStatusItem = player["PlayerApproveStatusItem"]
	        if playerApproveStatusItem then
	        	local playerApproveStatusItemShouldDisplay = clientIndex == Client.GetLocalClientIndex()
	        	playerApproveStatusItem:SetIsVisible(playerApproveStatusItemShouldDisplay)
	        	playerApproveStatusItem:SetText(tostring(approveSentTotal) .. ":" .. tostring(approveReceivedTotal))
	        end


		    playerApproveReceiveTotalItemPosition = player["Status"]:GetPosition()
	        currentPlayerIndex = currentPlayerIndex + 1
		end

	    -- local color = GUIScoreboard.kSpectatorColor
	    -- if teamNumber == kTeam1Index then
	    --     color = GUIScoreboard.kBlueColor
	    -- elseif teamNumber == kTeam2Index then
	    --     color = GUIScoreboard.kRedColor
	    -- end

		-- if teamNumber == Client.GetLocalClientTeamNumber() then
		-- 	if playerApproveReceiveTotalItemPosition then
		-- 		local playerApproveReceiveTotalItem = updateTeam["GUIs"]["Background"]["PlayerApproveReceiveTotalItem"]
		-- 		if not playerApproveReceiveTotalItem then
		-- 			playerApproveReceiveTotalItem = GUIManager:CreateTextItem()
		-- 			playerApproveReceiveTotalItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
		-- 			playerApproveReceiveTotalItem:SetAnchor(GUIItem.Left, GUIItem.Top)
		-- 			playerApproveReceiveTotalItem:SetTextAlignmentX(GUIItem.Align_Min)
		-- 			playerApproveReceiveTotalItem:SetTextAlignmentY(GUIItem.Align_Min)
		-- 			playerApproveReceiveTotalItemPosition.x = playerApproveReceiveTotalItemPosition.x - 14
		-- 			playerApproveReceiveTotalItemPosition.y = GUIScoreboard.kTeamNameFontSize + 7
		-- 			playerApproveReceiveTotalItem:SetPosition(playerApproveReceiveTotalItemPosition)
		-- 			playerApproveReceiveTotalItem:SetColor(color)
		-- 			updateTeam["GUIs"]["Background"].PlayerApproveReceiveTotalItem = playerApproveReceiveTotalItem
		-- 			updateTeam["GUIs"]["Background"]:AddChild(playerApproveReceiveTotalItem)
		-- 		end
		-- 		playerApproveReceiveTotalItem:SetText(tostring(approveReceivedTotal) .. "|" .. tostring(approveSentTotal))
		-- 	end
		-- elseif updateTeam["GUIs"]["Background"].PlayerApproveReceiveTotalItem then
		-- 	GUI.DestroyItem(updateTeam["GUIs"]["Background"]["PlayerApproveReceiveTotalItem"])
		-- 	updateTeam["GUIs"]["Background"]["PlayerApproveReceiveTotalItem"] = nil
		-- end

	end

	local originalGUIScoreboardCreatePlayerItem = GUIScoreboard.CreatePlayerItem
	GUIScoreboard.CreatePlayerItem = function(self)
		local output = originalGUIScoreboardCreatePlayerItem(self)
		if not output.PlayerApproveIcon then
		    local playerApproveIcon = GUIManager:CreateGraphicItem()
		    local playerApproveIconPosition = output.Status:GetPosition()
		    playerApproveIconPosition.x = playerApproveIconPosition.x - 25
		    playerApproveIconPosition.y = playerApproveIconPosition.y - 10
		    playerApproveIcon:SetSize(Vector(20, 20, 0))
		    playerApproveIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		    playerApproveIcon:SetPosition(playerApproveIconPosition)
		    playerApproveIcon:SetTexture(APPROVE_TEXTURE_DISABLED)
		    output.PlayerApproveIcon = playerApproveIcon
		    output.Background:AddChild(playerApproveIcon)
		end
		if not output.PlayerApproveStatusItem then
		    local color = GUIScoreboard.kSpectatorColor
		    if teamNumber == kTeam1Index then
		        color = GUIScoreboard.kBlueColor
		    elseif teamNumber == kTeam2Index then
		        color = GUIScoreboard.kRedColor
		    end
			local playerApproveStatusItem = GUIManager:CreateTextItem()
			playerApproveStatusItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
			playerApproveStatusItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			playerApproveStatusItem:SetTextAlignmentX(GUIItem.Align_Min)
			playerApproveStatusItem:SetTextAlignmentY(GUIItem.Align_Min)
			local playerApproveStatusItemPosition = output.Status:GetPosition()
		    playerApproveStatusItemPosition.x = playerApproveStatusItemPosition.x - 25
		    playerApproveStatusItemPosition.y = playerApproveStatusItemPosition.y + 8
			playerApproveStatusItem:SetPosition(playerApproveStatusItemPosition)
			playerApproveStatusItem:SetColor(color)
			output.PlayerApproveStatusItem = playerApproveStatusItem
			output.Background:AddChild(playerApproveStatusItem)
		end
	    return output
	end

	local originalGUIScoreboardSendKeyEvent = GUIScoreboard.SendKeyEvent
	GUIScoreboard.SendKeyEvent = function(self, key, down)
		local result = originalGUIScoreboardSendKeyEvent(self, key, down)
		if result then
			local mouseX, mouseY = Client.GetCursorPosScreen()
		    for t = 1, #self.teams do

		        local playerList = self.teams[t]["PlayerList"]
		        for p = 1, #playerList do

		            local playerItem = playerList[p]
		            local playerApproveIcon = playerItem["PlayerApproveIcon"]
		            if playerApproveIcon and playerApproveIcon:GetIsVisible() and GUIItemContainsPoint(playerApproveIcon, mouseX, mouseY) then
		                local clientIndex = playerItem["ClientIndex"]
		                isApproved[clientIndex] = true
		                TGNS.SendNetworkMessage(Plugin.APPROVE_REQUESTED, {c=clientIndex})
		            end

		        end

		    end
		end
		return result
	end
	TGNS.HookNetworkMessage(Plugin.APPROVE_MAY_TRY_AGAIN, function(message)
		isApproved[message.c] = false
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_ALREADY_APPROVED, function(message)
		-- Shared.Message(tostring(message.c))
		isApproved[message.c] = true
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_RESET, function(message)
		isApproved = {}
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_RECEIVED_TOTAL, function(message)
		approveReceivedTotal = message.t
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_SENT_TOTAL, function(message)
		approveSentTotal = message.t
	end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end