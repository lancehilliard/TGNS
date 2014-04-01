local Plugin = Plugin

local prefixes = {}
local isCaptainsCaptain = {}
local isApproved = {}
local isQuerying = {}
local isQueryingBadge = {}
local approveReceivedTotal = 0
local approveSentTotal = 0
local APPROVE_TEXTURE_DISABLED = "ui/approve/chevron-disabled.dds"
local QUERY_TEXTURE_DISABLED = "ui/query/questionmark-disabled.dds"
local lastUpdatedPingsWhen = {}
local pings = {}
local showCustomNumbersColumn = true
local showOptionals = false
-- locations
local locationNames = {}

local CaptainsCaptainFontColor = Color(0, 1, 0, 1)

TGNS.HookNetworkMessage(Shine.Plugins.scoreboard.SCOREBOARD_DATA, function(message)
	prefixes[message.i] = message.p
	isCaptainsCaptain[message.i] = message.c
end)

local function getTeamApproveTexture(teamNumber)
	local result = string.format("ui/approve/chevron-team%s.dds", teamNumber)
	return result
end

local function getTeamQueryTexture(teamNumber)
	local result = string.format("ui/query/questionmark-team%s.dds", teamNumber)
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
	        if showCustomNumbersColumn then
		        local prefix = prefixes[clientIndex]
		        player["Number"]:SetText(TGNS.HasNonEmptyValue(prefix) and prefix or "")
		        local numberColor = Color(0.5, 0.5, 0.5, 1)
		        if isCaptainsCaptain[clientIndex] == true then
		        	numberColor = CaptainsCaptainFontColor
		        end
		        player["Number"]:SetColor(numberColor)
	        end

			local playerIsBot = playerRecord.Ping == 0 or string.sub(playerRecord.Name,1,5)=="[BOT]"
	        local playerApproveIcon = player["PlayerApproveIcon"]
	        if playerApproveIcon then
	        	local playerApproveIconShouldDisplay = (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals
	        	playerApproveIcon:SetIsVisible(playerApproveIconShouldDisplay)
		        playerApproveIcon:SetTexture(isApproved[clientIndex] and APPROVE_TEXTURE_DISABLED or getTeamApproveTexture(teamNumber))
	        end
	        local playerQueryIcon = player["PlayerQueryIcon"]
	        if playerQueryIcon then
	        	local playerQueryIconShouldDisplay = (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals
	        	playerQueryIcon:SetIsVisible(playerQueryIconShouldDisplay)
		        playerQueryIcon:SetTexture(isQuerying[clientIndex] and QUERY_TEXTURE_DISABLED or getTeamQueryTexture(teamNumber))
	        end
		    local color = GUIScoreboard.kSpectatorColor
		    if teamNumber == kTeam1Index then
		        color = GUIScoreboard.kBlueColor
		    elseif teamNumber == kTeam2Index then
		        color = GUIScoreboard.kRedColor
		    end
	        local playerApproveStatusItem = player["PlayerApproveStatusItem"]
	        if playerApproveStatusItem then
	        	local playerApproveStatusItemShouldDisplay = clientIndex == Client.GetLocalClientIndex() and showOptionals
	        	playerApproveStatusItem:SetIsVisible(playerApproveStatusItemShouldDisplay)
	        	playerApproveStatusItem:SetText(tostring(approveSentTotal) .. ":" .. tostring(approveReceivedTotal))
	        	playerApproveStatusItem:SetColor(color)
	        end


	        -- locations
	        local playerLocationNameItem = player["PlayerLocationNameItem"]
	        if playerLocationNameItem then
	        	local playerLocationNameItemShouldDisplay = (teamNumber == kMarineTeamType or teamNumber == kAlienTeamType) and ((teamNumber == Client.GetLocalClientTeamNumber()) or PlayerUI_GetIsSpecating())
	        	playerLocationNameItem:SetIsVisible(playerLocationNameItemShouldDisplay)
	        	playerLocationNameItem:SetText(string.format("%s", locationNames[clientIndex] and locationNames[clientIndex] or ""))
	        	playerLocationNameItem:SetColor(color)
	        end


	        if teamNumber == kTeamReadyRoom and playerRecord.IsSpectator then
	        	player["Status"]:SetText("Spectator")
	        end

	        -- if not playerIsBot then
	        -- 	local lastUpdatedClientPingsWhen = lastUpdatedPingsWhen[clientIndex] or 0
	        -- 	if lastUpdatedClientPingsWhen < Shared.GetTime() - kUpdatePingsIndividual then
			      --   math.randomseed(clientIndex + Shared.GetTime())
			      --   local ping = playerRecord.Ping * 0.5 -- math.random(24, 49)
			      --   pings[clientIndex] = math.floor(ping)
	        -- 		lastUpdatedPingsWhen[clientIndex] = Shared.GetTime()
	        -- 	end
	        -- 	local ping = pings[clientIndex]
		       --  player["Ping"]:SetText(tostring(ping))
		       --  if ping < GUIScoreboard.kLowPingThreshold then
		       --      player["Ping"]:SetColor(GUIScoreboard.kLowPingColor)
		       --  elseif ping < GUIScoreboard.kMedPingThreshold then
		       --      player["Ping"]:SetColor(GUIScoreboard.kMedPingColor)
		       --  elseif ping < GUIScoreboard.kHighPingThreshold then
		       --      player["Ping"]:SetColor(GUIScoreboard.kHighPingColor)
		       --  else
		       --      player["Ping"]:SetColor(GUIScoreboard.kInsanePingColor)
		       --  end
	        -- end

		    playerApproveReceiveTotalItemPosition = player["Status"]:GetPosition()
	        currentPlayerIndex = currentPlayerIndex + 1
		end
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
		if not output.PlayerQueryIcon then
		    local playerQueryIcon = GUIManager:CreateGraphicItem()
		    local playerQueryIconPosition = output.Status:GetPosition()
		    playerQueryIconPosition.x = playerQueryIconPosition.x - 45
		    playerQueryIconPosition.y = playerQueryIconPosition.y - 10
		    playerQueryIcon:SetSize(Vector(20, 20, 0))
		    playerQueryIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		    playerQueryIcon:SetPosition(playerQueryIconPosition)
		    playerQueryIcon:SetTexture(QUERY_TEXTURE_DISABLED)
		    output.PlayerQueryIcon = playerQueryIcon
		    output.Background:AddChild(playerQueryIcon)
		end
		if not output.PlayerApproveStatusItem then
			local playerApproveStatusItem = GUIManager:CreateTextItem()
			playerApproveStatusItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
			playerApproveStatusItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			playerApproveStatusItem:SetTextAlignmentX(GUIItem.Align_Min)
			playerApproveStatusItem:SetTextAlignmentY(GUIItem.Align_Min)
			local playerApproveStatusItemPosition = output.Status:GetPosition()
		    playerApproveStatusItemPosition.x = playerApproveStatusItemPosition.x - 25
		    playerApproveStatusItemPosition.y = playerApproveStatusItemPosition.y + 8
			playerApproveStatusItem:SetPosition(playerApproveStatusItemPosition)
			output.PlayerApproveStatusItem = playerApproveStatusItem
			output.Background:AddChild(playerApproveStatusItem)
		end


		-- locations
		if not output.PlayerLocationNameItem then
			local playerLocationNameItem = GUIManager:CreateTextItem()
			playerLocationNameItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
			playerLocationNameItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			playerLocationNameItem:SetTextAlignmentX(GUIItem.Align_Max)
			playerLocationNameItem:SetTextAlignmentY(GUIItem.Align_Min)
			local playerLocationNameItemPosition = output.Status:GetPosition()
		    playerLocationNameItemPosition.x = playerLocationNameItemPosition.x - 45
		    playerLocationNameItemPosition.y = playerLocationNameItemPosition.y + 8
			playerLocationNameItem:SetPosition(playerLocationNameItemPosition)
			output.PlayerLocationNameItem = playerLocationNameItem
			output.Background:AddChild(playerLocationNameItem)
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
	                local clientIndex = playerItem["ClientIndex"]
		            local playerApproveIcon = playerItem["PlayerApproveIcon"]
		            if playerApproveIcon and playerApproveIcon:GetIsVisible() and GUIItemContainsPoint(playerApproveIcon, mouseX, mouseY) and not isApproved[clientIndex] then
		                isApproved[clientIndex] = true
		                TGNS.SendNetworkMessage(Plugin.APPROVE_REQUESTED, {c=clientIndex})
		            end
		            local playerQueryIcon = playerItem["PlayerQueryIcon"]
		            if playerQueryIcon and playerQueryIcon:GetIsVisible() and GUIItemContainsPoint(playerQueryIcon, mouseX, mouseY) and not isQuerying[clientIndex] then
		                isQuerying[clientIndex] = true
		                TGNS.SendNetworkMessage(Plugin.QUERY_REQUESTED, {c=clientIndex})
		            end
		            local badgeIcons = playerItem["BadgeItems"]
		            if badgeIcons then
		                for i = 1, #badgeIcons do
		                	local badgeIcon = badgeIcons[i]
				            if badgeIcon and badgeIcon:GetIsVisible() and GUIItemContainsPoint(badgeIcon, mouseX, mouseY) and not isQueryingBadge[clientIndex] then
				                isQueryingBadge[clientIndex] = true
				                TGNS.SendNetworkMessage(Plugin.BADGE_QUERY_REQUESTED, {c=clientIndex})
				            end
					    end
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
	TGNS.HookNetworkMessage(Plugin.QUERY_ALLOWED, function(message)
		isQuerying[message.c] = false
	end)
	TGNS.HookNetworkMessage(Plugin.BADGE_QUERY_ALLOWED, function(message)
		isQueryingBadge[message.c] = false
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_RECEIVED_TOTAL, function(message)
		approveReceivedTotal = message.t
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_SENT_TOTAL, function(message)
		approveSentTotal = message.t
	end)
	TGNS.HookNetworkMessage(Plugin.TOGGLE_CUSTOM_NUMBERS_COLUMN, function(message)
		showCustomNumbersColumn = message.t
	end)
	TGNS.HookNetworkMessage(Plugin.TOGGLE_OPTIONALS, function(message)
		showOptionals = message.t
	end)


	-- locations
	TGNS.HookNetworkMessage(Plugin.LOCATION_CHANGED, function(message)
		local clientIndex = message.c
		local locationName = message.n
		locationNames[clientIndex] = locationName
	end)


	local originalCHUDGUI_DeathStatsUpdate = CHUDGUI_DeathStats.Update
	CHUDGUI_DeathStats.Update = function(self, deltaTime) end
	local originalShowClientStats = ShowClientStats
	ShowClientStats = function(endRound) end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end