local Plugin = Plugin

local prefixes = {}
local isCaptainsCaptain = {}
local isApproved = {}
local isQuerying = {}
local isVring = false
local isQueryingBadge = {}
local approveReceivedTotal = 0
local approveSentTotal = 0
local APPROVE_TEXTURE_DISABLED = "ui/approve/chevron-disabled.dds"
local QUERY_TEXTURE_DISABLED = "ui/query/contactcard-disabled.dds"
local VR_TEXTURE_DISABLED = "ui/vr/vr-disabled.dds"
local lastUpdatedPingsWhen = {}
local pings = {}
local showCustomNumbersColumn = true
local showOptionals = false
local notes = {}
local hasJetPacks = {}
local showTeamMessages = true
local badgeLabels = {}
local vrConfirmed = {}
local countdownSoundEventName = "sound/tgns.fev/winorlose/countdown"
local approveSoundEventName = "sound/tgns.fev/scoreboard/approve"

local CaptainsCaptainFontColor = Color(0, 1, 0, 1)

TGNS.HookNetworkMessage(Shine.Plugins.scoreboard.SCOREBOARD_DATA, function(message)
	prefixes[message.i] = message.p
	isCaptainsCaptain[message.i] = message.c
end)

local function getTeamApproveTexture(teamNumber)
	local result = string.format("ui/approve/chevron-team%s.dds", teamNumber)
	return result
end

local function getTeamVrTexture(teamNumber)
	local result = string.format("ui/vr/vr-team%s.dds", teamNumber)
	return result
end

local function getTeamQueryTexture(teamNumber)
	local result = string.format("ui/query/contactcard-team%s.dds", teamNumber)
	return result
end

function Plugin:Initialise()
	self.Enabled = true

	Client.PrecacheLocalSound(countdownSoundEventName)
	Client.PrecacheLocalSound(approveSoundEventName)

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



		if not player.PlayerApproveIcon then
		    local playerApproveIcon = GUIManager:CreateGraphicItem()
		    local playerApproveIconPosition = player.Status:GetPosition()
		    playerApproveIconPosition.x = playerApproveIconPosition.x - 25
		    playerApproveIconPosition.y = playerApproveIconPosition.y - 10
		    playerApproveIcon:SetSize(Vector(20, 20, 0))
		    playerApproveIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		    playerApproveIcon:SetPosition(playerApproveIconPosition)
		    playerApproveIcon:SetTexture(APPROVE_TEXTURE_DISABLED)
		    player.PlayerApproveIcon = playerApproveIcon
		    player.Background:AddChild(playerApproveIcon)
		end
		if not player.PlayerVrIcon then
		    local playerVrIcon = GUIManager:CreateGraphicItem()
		    local playerVrIconPosition = player.Status:GetPosition()
		    playerVrIconPosition.x = playerVrIconPosition.x - 65
		    playerVrIconPosition.y = playerVrIconPosition.y - 10
		    playerVrIcon:SetSize(Vector(20, 20, 0))
		    playerVrIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		    playerVrIcon:SetPosition(playerVrIconPosition)
		    playerVrIcon:SetTexture(VR_TEXTURE_DISABLED)
		    player.PlayerVrIcon = playerVrIcon
		    player.Background:AddChild(playerVrIcon)
		end
		if not player.PlayerQueryIcon then
		    local playerQueryIcon = GUIManager:CreateGraphicItem()
		    local playerQueryIconPosition = player.Status:GetPosition()
		    playerQueryIconPosition.x = playerQueryIconPosition.x - 45
		    playerQueryIconPosition.y = playerQueryIconPosition.y - 10
		    playerQueryIcon:SetSize(Vector(20, 20, 0))
		    playerQueryIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		    playerQueryIcon:SetPosition(playerQueryIconPosition)
		    playerQueryIcon:SetTexture(QUERY_TEXTURE_DISABLED)
		    player.PlayerQueryIcon = playerQueryIcon
		    player.Background:AddChild(playerQueryIcon)
		end
		if not player.PlayerApproveStatusItem then
			local playerApproveStatusItem = GUIManager:CreateTextItem()
			playerApproveStatusItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
			playerApproveStatusItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			playerApproveStatusItem:SetTextAlignmentX(GUIItem.Align_Min)
			playerApproveStatusItem:SetTextAlignmentY(GUIItem.Align_Min)
			local playerApproveStatusItemPosition = player.Status:GetPosition()
		    playerApproveStatusItemPosition.x = playerApproveStatusItemPosition.x - 25
		    playerApproveStatusItemPosition.y = playerApproveStatusItemPosition.y + 8
			playerApproveStatusItem:SetPosition(playerApproveStatusItemPosition)
			player.PlayerApproveStatusItem = playerApproveStatusItem
			player.Background:AddChild(playerApproveStatusItem)
		end
		if not player.PlayerNoteItem then
			local playerNoteItem = GUIManager:CreateTextItem()
			playerNoteItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
			playerNoteItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			playerNoteItem:SetTextAlignmentX(GUIItem.Align_Max)
			playerNoteItem:SetTextAlignmentY(GUIItem.Align_Min)
			player.PlayerNoteItem = playerNoteItem
			player.Background:AddChild(playerNoteItem)
		end




			local playerIsBot = playerRecord.Ping == 0
	        local playerApproveIcon = player["PlayerApproveIcon"]
	        local playerApproveIconShouldDisplay = (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals
	        local playerVrIconShouldDisplay = ((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber())) and (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals and not vrConfirmed[clientIndex]
	        if playerVrIconShouldDisplay then
	        	local targetPrefix = prefixes[clientIndex] or ""
        		local targetPrefixFiltered = TGNS.Replace(targetPrefix, "!", "")
        		targetPrefixFiltered = TGNS.Replace(targetPrefixFiltered, "*", "")
        		playerVrIconShouldDisplay = not TGNS.HasNonEmptyValue(targetPrefixFiltered)
	        end

			local playerNoteItemPosition = player.Status:GetPosition()
			playerNoteItemPosition.x = playerNoteItemPosition.x - ((playerVrIconShouldDisplay and 60 or 40) + 5)
		    playerNoteItemPosition.y = playerNoteItemPosition.y + 8
			player.PlayerNoteItem:SetPosition(playerNoteItemPosition)

	        local playerQueryIconShouldDisplay = (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals
	        if playerApproveIcon then
	        	playerApproveIcon:SetIsVisible(playerApproveIconShouldDisplay)
		        playerApproveIcon:SetTexture(isApproved[clientIndex] and APPROVE_TEXTURE_DISABLED or getTeamApproveTexture(teamNumber))
	        end
	        local playerVrIcon = player["PlayerVrIcon"]
	        if playerVrIcon then
	        	playerVrIcon:SetIsVisible(playerVrIconShouldDisplay)
	        	local playerVrIconShouldBeDisabled = isVring or (Client.GetLocalClientTeamNumber() == kSpectatorIndex)
		        playerVrIcon:SetTexture(playerVrIconShouldBeDisabled and VR_TEXTURE_DISABLED or getTeamVrTexture(teamNumber))
	        end
	        local playerQueryIcon = player["PlayerQueryIcon"]
	        if playerQueryIcon then
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

	        local playerNoteItem = player["PlayerNoteItem"]
	        if playerNoteItem then
	        	local playerNoteItemShouldDisplay = (teamNumber == kMarineTeamType or teamNumber == kAlienTeamType) and ((teamNumber == Client.GetLocalClientTeamNumber()) or (PlayerUI_GetIsSpecating() and Client.GetLocalClientTeamNumber() ~= kMarineTeamType and Client.GetLocalClientTeamNumber() ~= kAlienTeamType))
	        	playerNoteItem:SetIsVisible(playerNoteItemShouldDisplay)
	        	playerNoteItem:SetText(string.format("%s", notes[clientIndex] and notes[clientIndex] or ""))
	        	playerNoteItem:SetColor(color)
	        end

	        -- if teamNumber == kTeamReadyRoom and playerRecord.IsSpectator then
	        -- 	player["Status"]:SetText("Spectator")
	        -- end

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
		            local playerVrIcon = playerItem["PlayerVrIcon"]
		            local playerVrIconShouldBeDisabled = isVring or (Client.GetLocalClientTeamNumber() == kSpectatorIndex)
		            if playerVrIcon and playerVrIcon:GetIsVisible() and GUIItemContainsPoint(playerVrIcon, mouseX, mouseY) and not playerVrIconShouldBeDisabled then
		                isVring = true
		                TGNS.SendNetworkMessage(Plugin.VR_REQUESTED, {c=clientIndex})
		            end
		       --      local badgeIcons = playerItem["BadgeItems"]
		       --      if badgeIcons then
		       --          for i = 1, #badgeIcons do
		       --          	local badgeIcon = badgeIcons[i]
				     --        if badgeIcon and badgeIcon:GetIsVisible() and GUIItemContainsPoint(badgeIcon, mouseX, mouseY) and not isQueryingBadge[clientIndex] then
				     --            isQueryingBadge[clientIndex] = true
				     --            TGNS.SendNetworkMessage(Plugin.BADGE_QUERY_REQUESTED, {c=clientIndex})
				     --        end
					    -- end
		       --      end
		        end

		    end
		end
		return result
	end
	TGNS.HookNetworkMessage(Plugin.APPROVE_MAY_TRY_AGAIN, function(message)
		isApproved[message.c] = false
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_ALREADY_APPROVED, function(message)
		isApproved[message.c] = true
	end)
	TGNS.HookNetworkMessage(Plugin.VR_CONFIRMED, function(message)
		vrConfirmed[message.c] = true
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_RESET, function(message)
		isApproved = {}
	end)
	TGNS.HookNetworkMessage(Plugin.QUERY_ALLOWED, function(message)
		isQuerying[message.c] = false
	end)
	TGNS.HookNetworkMessage(Plugin.VR_ALLOWED, function(message)
		isVring = false
	end)
	TGNS.HookNetworkMessage(Plugin.BADGE_QUERY_ALLOWED, function(message)
		isQueryingBadge[message.c] = false
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_RECEIVED_TOTAL, function(message)
		if message.t > approveReceivedTotal then
			Shared.PlaySound(Client.GetLocalPlayer(), approveSoundEventName, 0.015)
		end
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
	TGNS.HookNetworkMessage(Plugin.PLAYER_NOTE, function(message)
		local clientIndex = message.c
		local note = message.n
		notes[clientIndex] = note
	end)


	-- if CHUDGUI_DeathStats then
	-- 	local originalCHUDGUI_DeathStatsUpdate = CHUDGUI_DeathStats.Update
	-- 	CHUDGUI_DeathStats.Update = function(self, deltaTime) end
	-- end
	-- if ShowClientStats then
	-- 	local originalShowClientStats = ShowClientStats
	-- 	ShowClientStats = function(endRound) end
	-- end

	TGNS.HookNetworkMessage(Plugin.HAS_JETPACK, function(message)
		hasJetPacks[message.c] = message.h
	end)
	TGNS.HookNetworkMessage(Plugin.HAS_JETPACK_RESET, function(message)
		hasJetPacks = {}
	end)
	TGNS.HookNetworkMessage(Plugin.SHOW_TEAM_MESSAGES, function(message)
		showTeamMessages = message.s
	end)

	if GUIMarineTeamMessage == nil or GUIAlienTeamMessage == nil then
		Script.Load("lua/GUIMarineTeamMessage.lua")
	end

	if GUIMarineTeamMessage and GUIMarineTeamMessage.SetTeamMessage then
		local originalGUIMarineTeamMessageSetTeamMessage = GUIMarineTeamMessage.SetTeamMessage
		GUIMarineTeamMessage.SetTeamMessage = function(self, message)
			if showTeamMessages then
				originalGUIMarineTeamMessageSetTeamMessage(self, message)
			end
		end
	end

	if GUIAlienTeamMessage and GUIAlienTeamMessage.SetTeamMessage then
		local originalGUIAlienTeamMessageSetTeamMessage = GUIAlienTeamMessage.SetTeamMessage
		GUIAlienTeamMessage.SetTeamMessage = function(self, message)
			if showTeamMessages then
				originalGUIAlienTeamMessageSetTeamMessage(self, message)
			end
		end
	end


	local originalSharedGetString = Shared.GetString
	Shared.GetString = function(stringIndex)
		local result = stringIndex == TGNS.READYROOM_LOCATION_ID and "Ready Room" or originalSharedGetString(stringIndex)
		return result
	end


    local originalGetBadgeFormalName = GetBadgeFormalName
    GetBadgeFormalName = function(name)
    	local result = originalGetBadgeFormalName(name)
    	if result == "Custom Badge" then
    		local badgeLabel = badgeLabels[name]
    		if badgeLabel then
    			result = badgeLabel
    		end
    	end
    	return result
	end

	TGNS.HookNetworkMessage(Plugin.BADGE_DISPLAY_LABEL, function(message)
		badgeLabels[string.format("ui/badges/%s.dds", message.n)] = message.l
	end)

	local originalGUIHoverTooltipShow = GUIHoverTooltip.Show
	GUIHoverTooltip.Show = function(self, displayTimeInSeconds)
		if self.tooltip and self.tooltip.GetText and self.tooltip:GetText():find("TGNS") then
			displayTimeInSeconds = 2
		end
		originalGUIHoverTooltipShow(self, displayTimeInSeconds)
	end

	TGNS.HookNetworkMessage(Plugin.WINORLOSE_WARNING, function(message)
		Shared.PlaySound(Client.GetLocalPlayer(), countdownSoundEventName, 0.025)
	end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end