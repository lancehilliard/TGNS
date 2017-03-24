Event.Hook("MapPostLoad", function()
	if false then
		TGNS.ModifyAlienMaxSpeeds(function(maxSpeed) return maxSpeed + (kCelerityAddSpeed or 1.5) end)
		kStompEnergyCost = kStompEnergyCost * 2
	end
end)

if Server or Client then
	local Plugin = {}

	local MAX_NON_CAPTAIN_PLAYERS = 14


	local OnClientInitialise = function(self) end
	local OnServerInitialise = function(self) end

	Plugin.CAPTAINS_DATA = "captains_CAPTAINS_DATA"

	TGNS.RegisterNetworkMessage(Plugin.CAPTAINS_DATA, {d="string(999)"})

	if Client then
		local showClientDebug = false
		Event.Hook("Console_captainsclientdebug", function(client)
			showClientDebug = not showClientDebug
			Shared.Message("showClientDebug: " .. tostring(showClientDebug))
		end)
		local debug = function(message)
			if showClientDebug then
		 		Shared.Message(string.format("CAPTAINSCLIENTDEBUG[%s] %s", math.floor(Shared.GetTime()), message))
			end
		end

		local captainsData = {}
		local rolesClientData = {}
		local captainsClientIndexes = {}
		local localClientIsCaptain = false
		local optedInCount = 0
        local hoverBadge = false
        local rolesClientDataLastUpdated
		local scoreboardIsBeingShown
		local userHasToggledCaptainsBoardDisplayOn
		local CaptainsCaptainFontColor = Color(0, 1, 0, 1)
		local optedInScores = {}
		local notOptedInScores = {}

		TGNS.HookNetworkMessage(Plugin.CAPTAINS_DATA, function(message)
			local data = json.decode(message.d)
			debug("message.d: " .. tostring(message.d))
			if data then
				rolesClientData = data.p
				optedInCount = data.o
				captainsClientIndexes = data.c or {}
				localClientIsCaptain = TGNS.Has(captainsClientIndexes, Client.GetLocalClientIndex())
				rolesClientDataLastUpdated = Shared.GetTime()
				if userHasToggledCaptainsBoardDisplayOn == nil then
					userHasToggledCaptainsBoardDisplayOn = true
				end

				local scoresData = GetScoreData({ kTeamReadyRoom, kMarineTeamType, kAlienTeamType })


				local buildScoresData = function(isForOptedInBoard)
					local dataName = isForOptedInBoard and "optedInScores" or "notOptedInScores"
					local getKey = function(s) return string.format("c%s", s.ClientIndex) end
					local scoresDataPredicate = isForOptedInBoard and function(s) return rolesClientData[getKey(s)] ~= nil and not TGNS.Has(captainsClientIndexes, s.ClientIndex) end or function(s) return rolesClientData[getKey(s)] == nil and s.EntityTeamNumber == kTeamReadyRoom and not TGNS.Has(captainsClientIndexes, s.ClientIndex) end
			   		local result = TGNS.Where(scoresData, scoresDataPredicate)
		   			TGNS.SortDescending(result, function(s)
		   				local teamAdditive = 0
		   				if s.EntityTeamNumber == kMarineTeamType then
		   					teamAdditive = 50000
	   					elseif s.EntityTeamNumber == kAlienTeamType then
	   						teamAdditive = 25000
	   					end
		   				return s.Skill + teamAdditive
		   			end)
			   		local datas = {scoresData=scoresData, rolesClientData=rolesClientData}
			   		datas[dataName] = result
			   		debug(string.format("total: %s; optedIn: %s; %s: %s; datas: %s", #scoresData, optedInCount, dataName, #result, json.encode(datas)))
			   		return result
				end
		   		optedInScores = buildScoresData(true)
		   		notOptedInScores = buildScoresData(false)
			end

		end)

		OnClientInitialise = function(self)

			-- local originalGUIGameEndSetGameEnded
			-- originalGUIGameEndSetGameEnded = TGNS.ReplaceClassMethod("GUIGameEnd", "SetGameEnded", function(guiGameEndSelf, playerWon, playerDraw, playerTeamType)
			-- 	originalGUIGameEndSetGameEnded(guiGameEndSelf, playerWon, playerDraw, playerTeamType)
			-- 	if #captainsClientIndexes > 0 and not (PlayerUI_IsASpectator() or playerDraw) then
			-- 		local messageText = guiGameEndSelf.messageText:GetText()
			-- 		local marinesWon = TGNS.Has({"Marines Win!", "Aliens lose"}, messageText)
			-- 		local winningTeamName = marinesWon and InsightUI_GetTeam1Name() or InsightUI_GetTeam2Name()
			-- 		if winningTeamName then
			-- 			guiGameEndSelf.messageText:SetColor(marinesWon and kMarineFontColor or kAlienFontColor)
			-- 			guiGameEndSelf.messageText:SetFontName(marinesWon and Fonts.kAgencyFB_Huge or Fonts.kStamp_Huge)
			-- 			guiGameEndSelf.endIcon:SetTexture(marinesWon and "ui/marine_victory.dds" or "ui/alien_victory.dds")
			-- 			guiGameEndSelf.messageText:SetText(string.format("%s Wins!", winningTeamName))
			-- 			GUIMakeFontScale(guiGameEndSelf.messageText)
			-- 		end
			-- 	end
			-- end)

			local background
			local backgroundStencil
			local scoreboardBackground
			local kBgMaxYSpace
			local guiLayer = kGUILayerScoreboard
			local slidePercentage
			local contentYSize
			local slidebarBg
			local slidebar
			local mousePressed = { LMB = { Down = nil }, RMB = { Down = nil } }
			local isDragging
			local teams = {}
			local kIconOffset = Vector(-15, -10, 0)
			local kIconSize = Vector(40, 40, 0)
			local reusePlayerItems = {}
			local playerHighlightItem
			local clickForMouseBackground
			local kPlayerItemLeftMargin = 10
			local kPlayerNumberWidth = 20
			local kPlayerVoiceChatIconSize = 20
			local kPlayerBadgeIconSize = 20
			local kPlayerBadgeRightPadding = 4
			local kMinTruncatedNameLength = 15
			local hoverPlayerClientIndex
			local kMutedTextTexture = PrecacheAsset("ui/sb-text-muted.dds")
			local kMutedVoiceTexture = PrecacheAsset("ui/sb-voice-muted.dds")
			local mouseVisible
			local clickForMouseIndicator
			local badgeNameTooltip

			local captainsBoardShouldBeShown = function()
				local rolesClientDataLastUpdatedRecently = rolesClientDataLastUpdated ~= nil and Shared.GetTime() - rolesClientDataLastUpdated < 5
				return rolesClientDataLastUpdatedRecently and userHasToggledCaptainsBoardDisplayOn and not scoreboardIsBeingShown -- and PlayerUI_GetTeamType() == kTeamReadyRoom and not PlayerUI_IsASpectator()
			end

			local function CreateTeamBackground(color, guiLayer)
			    local teamItem = GUIManager:CreateGraphicItem()
			    teamItem:SetStencilFunc(GUIItem.NotEqual)
			    
			    teamItem:SetSize(Vector(teamItemWidth, GUIScoreboard.kTeamItemHeight, 0) * GUIScoreboard.kScalingFactor)
		        teamItem:SetAnchor(GUIItem.Middle, GUIItem.Top)
			    
			    teamItem:SetColor(Color(0/255,16/255,0/255, 0.75))
			    teamItem:SetIsVisible(false)
			    teamItem:SetLayer(guiLayer)
			    
			    local logoItem = GUIManager:CreateGraphicItem()
			    logoItem:SetSize(Vector(300, 50, 0) * GUIScoreboard.kScalingFactor)
			    logoItem:SetAnchor(GUIItem.Right, GUIItem.Top)
			    logoItem:SetColor(Color(1, 1, 1, 1))
			    logoItem:SetTexture("ui/captains/CaptainsBanner.dds")
			    logoItem:SetPosition(Vector(-300, 0, 0) * GUIScoreboard.kScalingFactor)
			    logoItem:SetStencilFunc(GUIItem.NotEqual)
			    logoItem:SetIsVisible(true)
			    teamItem:AddChild(logoItem)


			    local teamNameItem = GUIManager:CreateTextItem()
			    teamNameItem:SetFontName(GUIScoreboard.kTeamNameFontName)
			    teamNameItem:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
			    GUIMakeFontScale(teamNameItem)
			    teamNameItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			    teamNameItem:SetTextAlignmentX(GUIItem.Align_Min)
			    teamNameItem:SetTextAlignmentY(GUIItem.Align_Min)
			    teamNameItem:SetPosition(Vector(10, 5, 0) * GUIScoreboard.kScalingFactor)
			    teamNameItem:SetColor(color)
			    teamNameItem:SetStencilFunc(GUIItem.NotEqual)
			    teamItem:AddChild(teamNameItem)
			    
			    local teamInfoItem = GUIManager:CreateTextItem()
			    teamInfoItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
			    teamInfoItem:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
			    GUIMakeFontScale(teamInfoItem)
			    teamInfoItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			    teamInfoItem:SetTextAlignmentX(GUIItem.Align_Min)
			    teamInfoItem:SetTextAlignmentY(GUIItem.Align_Min)
			    teamInfoItem:SetPosition(Vector(12, GUIScoreboard.kTeamNameFontSize + 3, 0) * GUIScoreboard.kScalingFactor)
			    teamInfoItem:SetColor(color)
			    teamInfoItem:SetStencilFunc(GUIItem.NotEqual)
			    teamItem:AddChild(teamInfoItem)
			    
			    local currentColumnX = ConditionalValue(GUIScoreboard.screenWidth < 1280, GUIScoreboard.kPlayerItemWidth, teamItemWidth - GUIScoreboard.kTeamColumnSpacingX * 10)
			    local playerDataRowY = 10
			    
			    local tgnsItemText = ""
			    local tgnsItem = GUIManager:CreateTextItem()
			    tgnsItem:SetFontName(GUIScoreboard.kTeamNameFontName)
			    tgnsItem:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
			    GUIMakeFontScale(tgnsItem)
			    tgnsItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			    tgnsItem:SetTextAlignmentX(GUIItem.Align_Min)
			    tgnsItem:SetTextAlignmentY(GUIItem.Align_Min)
			    tgnsItem:SetPosition(Vector(currentColumnX + 60, playerDataRowY, 0) * GUIScoreboard.kScalingFactor)
			    tgnsItem:SetColor(color)
			    tgnsItem:SetText(tgnsItemText)
			    tgnsItem:SetStencilFunc(GUIItem.NotEqual)
			    teamItem:AddChild(tgnsItem)
			    
			    currentColumnX = currentColumnX + GUIScoreboard.kTeamColumnSpacingX * 2 + teamItem:GetTextWidth(tgnsItemText) * GUIScoreboard.kScalingFactor
			    
			    return { Background = teamItem, TeamName = teamNameItem, TeamInfo = teamInfoItem, Logo = logoItem }
			    
			end

			local function SetMouseVisible(setVisible)

			    if mouseVisible ~= setVisible then
			        mouseVisible = setVisible
			        MouseTracker_SetIsVisible(mouseVisible, "ui/Cursor_MenuDefault.dds", true)
			        clickForMouseIndicator:SetText((mouseVisible and "Right-Click to Hide" or "Left-Click for") .. " Mouse")
			    end
			    if not mouseVisible then
			    	badgeNameTooltip:Hide(0)
			    end
			    
			end


			local function HandleSlidebarClicked(mouseX, mouseY)
			    if slidebarBg:GetIsVisible() and isDragging then
			        local topPos = 20
			        local bottomPos = Client.GetScreenHeight() - 20
			        mouseY = Clamp(mouseY, topPos, bottomPos)
			        slidePercentage = (mouseY - topPos) / (bottomPos - topPos) * 100
			    end
			end

			local function CreatePlayerItem()


			    -- Reuse an existing player item if there is one.
			    if table.count(reusePlayerItems) > 0 then
			        local returnPlayerItem = reusePlayerItems[1]
			        table.remove(reusePlayerItems, 1)
			        return returnPlayerItem
			    end
			    
			    -- Create background.
			    local playerItem = GUIManager:CreateGraphicItem()
			    playerItem:SetSize(Vector(teamItemWidth - (GUIScoreboard.kPlayerItemWidthBuffer * 2), GUIScoreboard.kPlayerItemHeight, 0) * GUIScoreboard.kScalingFactor)
			    playerItem:SetAnchor(GUIItem.Left, GUIItem.Top)
			    playerItem:SetPosition(Vector(GUIScoreboard.kPlayerItemWidthBuffer, GUIScoreboard.kPlayerItemHeight / 2, 0) * GUIScoreboard.kScalingFactor)
			    playerItem:SetColor(Color(1, 1, 1, 1))
			    playerItem:SetTexture("ui/hud_elements.dds")
			    playerItem:SetTextureCoordinates(0, 0, 0.558, 0.16)
			    playerItem:SetStencilFunc(GUIItem.NotEqual)

			    local playerItemChildX = kPlayerItemLeftMargin

			    -- Player number item
			    local playerNumber = GUIManager:CreateTextItem()
			    playerNumber:SetFontName(GUIScoreboard.kPlayerStatsFontName)
			    playerNumber:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
			    GUIMakeFontScale(playerNumber)
			    playerNumber:SetAnchor(GUIItem.Left, GUIItem.Center)
			    playerNumber:SetTextAlignmentX(GUIItem.Align_Min)
			    playerNumber:SetTextAlignmentY(GUIItem.Align_Center)
			    playerNumber:SetPosition(Vector(playerItemChildX, 0, 0))
			    playerItemChildX = playerItemChildX + kPlayerNumberWidth
			    playerNumber:SetColor(Color(0.5, 0.5, 0.5, 1))
			    playerNumber:SetStencilFunc(GUIItem.NotEqual)
			    playerNumber:SetIsVisible(true)
			    playerItem:AddChild(playerNumber)

			    -- Player voice icon item.
			    local playerVoiceIcon = GUIManager:CreateGraphicItem()
			    playerVoiceIcon:SetSize(Vector(kPlayerVoiceChatIconSize, kPlayerVoiceChatIconSize, 0) * GUIScoreboard.kScalingFactor)
			    playerVoiceIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
			    playerVoiceIcon:SetPosition(Vector(
			                playerItemChildX,
			                -kPlayerVoiceChatIconSize/2,
			                0) * GUIScoreboard.kScalingFactor)
			    playerItemChildX = playerItemChildX + kPlayerVoiceChatIconSize
			    playerVoiceIcon:SetTexture(kMutedVoiceTexture)
			    playerVoiceIcon:SetStencilFunc(GUIItem.NotEqual)
			    playerVoiceIcon:SetIsVisible(false)
			    playerVoiceIcon:SetColor(GUIScoreboard.kVoiceMuteColor)
			    playerItem:AddChild(playerVoiceIcon)
			    
			    local playerSkillBar

			    -- //----------------------------------------
			    -- //  Badge icons
			    -- //----------------------------------------
			    local maxBadges = Badges_GetMaxBadges()
			    local badgeItems = {}
			    
			    -- // Player badges
			    for i = 1,maxBadges do
			        local playerBadge = GUIManager:CreateGraphicItem()
			        playerBadge:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
			        playerBadge:SetAnchor(GUIItem.Left, GUIItem.Center)
			        playerBadge:SetPosition(Vector(playerItemChildX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			        playerItemChildX = playerItemChildX + kPlayerBadgeIconSize + kPlayerBadgeRightPadding
			        playerBadge:SetIsVisible(false)
			        playerBadge:SetStencilFunc(GUIItem.NotEqual)
			        playerItem:AddChild(playerBadge)
			        table.insert( badgeItems, playerBadge )
			    end

			    -- // Player name text item.
			    local playerNameItem = GUIManager:CreateTextItem()
			    playerNameItem:SetFontName(GUIScoreboard.kPlayerStatsFontName)
			    playerNameItem:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
			    GUIMakeFontScale(playerNameItem)
			    playerNameItem:SetAnchor(GUIItem.Left, GUIItem.Center)
			    playerNameItem:SetTextAlignmentX(GUIItem.Align_Min)
			    playerNameItem:SetTextAlignmentY(GUIItem.Align_Center)
			    playerNameItem:SetPosition(Vector(
			                playerItemChildX,
			                0, 0) * GUIScoreboard.kScalingFactor)
			    playerNameItem:SetColor(Color(1, 1, 1, 1))
			    playerNameItem:SetStencilFunc(GUIItem.NotEqual)
			    playerItem:AddChild(playerNameItem)

			    local currentColumnX = ConditionalValue(GUIScoreboard.screenWidth < 1280, GUIScoreboard.kPlayerItemWidth * 0.7, teamItemWidth - GUIScoreboard.kTeamColumnSpacingX * 10 + (80 * GUIScoreboard.kScalingFactor))
			    
			    -- // Status text item.
			    local statusItem = GUIManager:CreateTextItem()
			    statusItem:SetFontName(GUIScoreboard.kPlayerStatsFontName)
			    statusItem:SetScale(Vector(1, 1, 1) * GUIScoreboard.kScalingFactor)
			    GUIMakeFontScale(statusItem)
			    statusItem:SetAnchor(GUIItem.Left, GUIItem.Center)
			    statusItem:SetTextAlignmentX(GUIItem.Align_Min)
			    statusItem:SetTextAlignmentY(GUIItem.Align_Center)
			    statusItem:SetPosition(Vector(currentColumnX + ConditionalValue(GUIScoreboard.screenWidth < 1280, 0, 30), 0, 0) * GUIScoreboard.kScalingFactor)
			    statusItem:SetColor(Color(1, 1, 1, 1))
			    statusItem:SetStencilFunc(GUIItem.NotEqual)
			    playerItem:AddChild(statusItem)
			    
			    -- currentColumnX = currentColumnX + (30 * GUIScoreboard.kScalingFactor) + GUIScoreboard.kTeamColumnSpacingX * 2
				currentColumnX = currentColumnX + (60 * GUIScoreboard.kScalingFactor)
		    
		        local kdPercentIcon = GUIManager:CreateGraphicItem()
		        kdPercentIcon:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
		        kdPercentIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		        kdPercentIcon:SetPosition(Vector(currentColumnX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    kdPercentIcon:SetTexture("ui/captains/KillRatioSkill.dds")
		        kdPercentIcon:SetIsVisible(true)
		        kdPercentIcon:SetStencilFunc(GUIItem.NotEqual)
		        kdPercentIcon.tooltipText = "Kill/Death Ratio"
		        kdPercentIcon.allowHighlight = true
		        playerItem:AddChild(kdPercentIcon)
			    
			    currentColumnX = currentColumnX + kPlayerBadgeIconSize + (20 * GUIScoreboard.kScalingFactor)

		        local gorgePercentIcon = GUIManager:CreateGraphicItem()
		        gorgePercentIcon:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
		        gorgePercentIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		        gorgePercentIcon:SetPosition(Vector(currentColumnX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    gorgePercentIcon:SetTexture("ui/captains/GorgeSkill.dds")
		        gorgePercentIcon:SetIsVisible(true)
		        gorgePercentIcon:SetStencilFunc(GUIItem.NotEqual)
		        gorgePercentIcon.tooltipText = "Gorge"
		        gorgePercentIcon.allowHighlight = true
		        playerItem:AddChild(gorgePercentIcon)
			    
			    currentColumnX = currentColumnX + kPlayerBadgeIconSize + (5 * GUIScoreboard.kScalingFactor)
			    
		        local lerkPercentIcon = GUIManager:CreateGraphicItem()
		        lerkPercentIcon:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
		        lerkPercentIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		        lerkPercentIcon:SetPosition(Vector(currentColumnX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    lerkPercentIcon:SetTexture("ui/captains/LerkSkill.dds")
		        lerkPercentIcon:SetIsVisible(true)
		        lerkPercentIcon:SetStencilFunc(GUIItem.NotEqual)
		        lerkPercentIcon.tooltipText = "Lerk"
		        lerkPercentIcon.allowHighlight = true
		        playerItem:AddChild(lerkPercentIcon)
			    
			    currentColumnX = currentColumnX + kPlayerBadgeIconSize + (5 * GUIScoreboard.kScalingFactor)

		        local fadePercentIcon = GUIManager:CreateGraphicItem()
		        fadePercentIcon:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
		        fadePercentIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		        fadePercentIcon:SetPosition(Vector(currentColumnX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    fadePercentIcon:SetTexture("ui/captains/FadeSkill.dds")
		        fadePercentIcon:SetIsVisible(true)
		        fadePercentIcon:SetStencilFunc(GUIItem.NotEqual)
		        fadePercentIcon.tooltipText = "Fade"
		        fadePercentIcon.allowHighlight = true
		        playerItem:AddChild(fadePercentIcon)
			    
			    currentColumnX = currentColumnX + kPlayerBadgeIconSize + (5 * GUIScoreboard.kScalingFactor)

		        local onosPercentIcon = GUIManager:CreateGraphicItem()
		        onosPercentIcon:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
		        onosPercentIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		        onosPercentIcon:SetPosition(Vector(currentColumnX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    onosPercentIcon:SetTexture("ui/captains/OnosSkill.dds")
		        onosPercentIcon:SetIsVisible(true)
		        onosPercentIcon:SetStencilFunc(GUIItem.NotEqual)
		        onosPercentIcon.tooltipText = "Onos"
		        onosPercentIcon.allowHighlight = true
		        playerItem:AddChild(onosPercentIcon)
			    
			    currentColumnX = currentColumnX + kPlayerBadgeIconSize + (20 * GUIScoreboard.kScalingFactor)

		        local marineCommPercentIcon = GUIManager:CreateGraphicItem()
		        marineCommPercentIcon:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
		        marineCommPercentIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		        marineCommPercentIcon:SetPosition(Vector(currentColumnX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    marineCommPercentIcon:SetTexture("ui/captains/CommSkill.dds")
		        marineCommPercentIcon:SetIsVisible(true)
		        marineCommPercentIcon:SetStencilFunc(GUIItem.NotEqual)
		        marineCommPercentIcon.tooltipText = "Marine Commander"
		        marineCommPercentIcon.allowHighlight = true
		        playerItem:AddChild(marineCommPercentIcon)
			    
			    currentColumnX = currentColumnX + kPlayerBadgeIconSize + (5 * GUIScoreboard.kScalingFactor)

		        local alienCommPercentIcon = GUIManager:CreateGraphicItem()
		        alienCommPercentIcon:SetSize(Vector(kPlayerBadgeIconSize, kPlayerBadgeIconSize, 0) * GUIScoreboard.kScalingFactor)
		        alienCommPercentIcon:SetAnchor(GUIItem.Left, GUIItem.Center)
		        alienCommPercentIcon:SetPosition(Vector(currentColumnX, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    alienCommPercentIcon:SetTexture("ui/captains/KhammSkill.dds")
		        alienCommPercentIcon:SetIsVisible(true)
		        alienCommPercentIcon:SetStencilFunc(GUIItem.NotEqual)
		        alienCommPercentIcon.tooltipText = "Alien Khammander"
		        alienCommPercentIcon.allowHighlight = true
		        playerItem:AddChild(alienCommPercentIcon)
			    
			    currentColumnX = currentColumnX + kPlayerBadgeIconSize + (5 * GUIScoreboard.kScalingFactor)

			    local steamFriendIcon = GUIManager:CreateGraphicItem()
			    steamFriendIcon:SetSize(Vector(kPlayerVoiceChatIconSize, kPlayerVoiceChatIconSize, 0) * GUIScoreboard.kScalingFactor)
			    steamFriendIcon:SetAnchor(GUIItem.Right, GUIItem.Center)
		        steamFriendIcon:SetPosition(Vector(-kPlayerBadgeIconSize/2, -kPlayerBadgeIconSize/2, 0) * GUIScoreboard.kScalingFactor)
			    steamFriendIcon:SetTexture("ui/steamfriend.dds")
			    steamFriendIcon:SetStencilFunc(GUIItem.NotEqual)
			    steamFriendIcon:SetIsVisible(true)
			    steamFriendIcon.allowHighlight = true
			    playerItem:AddChild(steamFriendIcon)
			    
			    -- Let's do a table here to easily handle the highlighting/clicking of icons
			    -- It also makes it easy for other mods to add icons afterwards
			    local iconTable = {}
			    table.insert(iconTable, steamFriendIcon)
			    
			    return { Background = playerItem, Number = playerNumber, Name = playerNameItem,
			        Voice = playerVoiceIcon, Status = statusItem, 
			        BadgeItems = badgeItems, SkillBar = playerSkillBar, 
			        SteamFriend = steamFriendIcon, IconTable = iconTable,
			        GorgePercentIcon = gorgePercentIcon, LerkPercentIcon = lerkPercentIcon,
			        FadePercentIcon = fadePercentIcon, OnosPercentIcon = onosPercentIcon,
			        MarineCommPercentIcon = marineCommPercentIcon, AlienCommPercentIcon = alienCommPercentIcon, KdPercentIcon = kdPercentIcon
			    }
			end

			local function ResizePlayerList(playerList, numPlayers, teamGUIItem)
			    
			    while table.count(playerList) > numPlayers do
			        teamGUIItem:RemoveChild(playerList[1]["Background"])
			        playerList[1]["Background"]:SetIsVisible(false)
			        table.insert(reusePlayerItems, playerList[1])
			        table.remove(playerList, 1)
			    end
			    
			    while table.count(playerList) < numPlayers do
			        local newPlayerItem = CreatePlayerItem()
			        table.insert(playerList, newPlayerItem)
			        teamGUIItem:AddChild(newPlayerItem["Background"])
			        newPlayerItem["Background"]:SetIsVisible(true)
			    end

			end

			local function SetPlayerItemBadges( item, badgeTextures )

			    assert( #badgeTextures <= #item.BadgeItems )

			    local offset = 0

			    for i = 1, #item.BadgeItems do

			        if badgeTextures[i] ~= nil then
			            item.BadgeItems[i]:SetTexture( badgeTextures[i] )
			            item.BadgeItems[i]:SetIsVisible( true )
			        else
			            item.BadgeItems[i]:SetIsVisible( false )
			        end

			    end

			    -- now adjust the position of the player name
			    local numBadgesShown = math.min( #badgeTextures, #item.BadgeItems )
			    
			    offset = numBadgesShown*(kPlayerBadgeIconSize + kPlayerBadgeRightPadding) * GUIScoreboard.kScalingFactor
			                
			    return offset            

			end			

			local function UpdateTeam(updateTeam)
			    
			    local teamGUIItem = updateTeam["GUIs"]["Background"]
			    local teamNameGUIItem = updateTeam["GUIs"]["TeamName"]
			    local teamInfoGUIItem = updateTeam["GUIs"]["TeamInfo"]
			    local teamNameText = updateTeam["TeamTitle"]
			    local teamColor = updateTeam["Color"]
			    local localPlayerHighlightColor = updateTeam["HighlightColor"]
			    local playerList = updateTeam["PlayerList"]
			    local teamScores = updateTeam["GetScores"]()
			    local teamNumber = updateTeam["TeamNumber"]
			    local teamChoiceCaptainName = ""
			    local playerChoiceCaptainName = ""
			    if #captainsClientIndexes > 0 then
			    	local teamChoiceCaptainPlayerRecord = Scoreboard_GetPlayerRecord(captainsClientIndexes[1])
			    	if teamChoiceCaptainPlayerRecord then
				    	teamChoiceCaptainName = teamChoiceCaptainPlayerRecord.Name
			    	end
			    	if #captainsClientIndexes > 1 then
				    	local playerChoiceCaptainPlayerRecord = Scoreboard_GetPlayerRecord(captainsClientIndexes[2])
				    	if playerChoiceCaptainPlayerRecord then
					    	playerChoiceCaptainName = playerChoiceCaptainPlayerRecord.Name
				    	end
			    	end
			    end
			    local mouseX, mouseY = Client.GetCursorPosScreen()
			    
			    -- How many items per player.
			    local numPlayers = table.count(teamScores)
			    
			    -- Update the team name text.
			    local playersOnTeamText = string.format("%d %s", numPlayers, numPlayers == 1 and Locale.ResolveString("SB_PLAYER") or Locale.ResolveString("SB_PLAYERS") )
			    local sortDescription = ""
			    if numPlayers > 1 then
				    sortDescription = ", sorted by Name"
				    if teamNameText == "Pickable Players" then
				    	sortDescription = ", sorted by Team, then Skill"
				    end
			    end
			    local teamHeaderText = string.format("%s (%s%s)", teamNameText, playersOnTeamText, sortDescription)
			    
			    teamNameGUIItem:SetText( teamHeaderText )

				local captainsSlotsRemaining = MAX_NON_CAPTAIN_PLAYERS - optedInCount
				captainsSlotsRemaining = captainsSlotsRemaining >= 0 and captainsSlotsRemaining or 0
			    teamInfoGUIItem:SetText(teamNameText == "Pickable Players" and string.format("Team/Spawn Choice: %s        Player Choice: %s", teamChoiceCaptainName, playerChoiceCaptainName) or string.format("Slots remaining: %s/%s", captainsSlotsRemaining, MAX_NON_CAPTAIN_PLAYERS))

				if teamNameText == "Pickable Players" then
					teamInfoGUIItem:SetColor(CaptainsCaptainFontColor)
				end
			    
			    -- Make sure there is enough room for all players on this team GUI.
			    teamGUIItem:SetSize(Vector(teamItemWidth, (GUIScoreboard.kTeamItemHeight) + ((GUIScoreboard.kPlayerItemHeight + GUIScoreboard.kPlayerSpacing) * numPlayers), 0) * GUIScoreboard.kScalingFactor)
			    
			    -- Resize the player list if it doesn't match.
			    if table.count(playerList) ~= numPlayers then
			        ResizePlayerList(playerList, numPlayers, teamGUIItem, teamNameText == "Pickable Players")
			    end
			    
			    local currentY = (GUIScoreboard.kTeamNameFontSize + GUIScoreboard.kTeamInfoFontSize + 10) * GUIScoreboard.kScalingFactor
			    local currentPlayerIndex = 1
			    
			    for index, player in pairs(playerList) do
			        local playerRecord = teamScores[currentPlayerIndex]
			        local playerName = playerRecord.Name
			        local clientIndex = playerRecord.ClientIndex
			        local steamId = GetSteamIdForClientIndex(clientIndex)
			        local isCommander = playerRecord.IsCommander
			        local isRookie = playerRecord.IsRookie
			        local ping = playerRecord.Ping
			        local currentPosition = Vector(player["Background"]:GetPosition())
			        local playerStatus = "Opt-in (see above) or join Spectate" -- playerRecord.Status
			        local isSpectator = playerRecord.IsSpectator
			        local isSteamFriend = playerRecord.IsSteamFriend
			        local playerSkill = playerRecord.Skill
			        local commanderColor = GUIScoreboard.kCommanderFontColor
			        
			        currentPosition.y = currentY
			        player["Background"]:SetPosition(currentPosition)
			        player["Background"]:SetColor(ConditionalValue(isCommander, commanderColor, teamColor))
			        
			        -- Handle local player highlight
			        if ScoreboardUI_IsPlayerLocal(playerName) then
			            if playerHighlightItem:GetParent() ~= player["Background"] then
			                if playerHighlightItem:GetParent() ~= nil then
			                    playerHighlightItem:GetParent():RemoveChild(playerHighlightItem)
			                end
			                player["Background"]:AddChild(playerHighlightItem)
			                playerHighlightItem:SetIsVisible(true)
			                playerHighlightItem:SetColor(localPlayerHighlightColor)
			            end
			        end
			        
			        local prefix = Shine.Plugins.scoreboard:GetPrefixes(clientIndex)
			        player["Number"]:SetText(TGNS.HasNonEmptyValue(prefix) and prefix or "")

			        player["Name"]:SetText(playerName)
			        
			        player["ClientIndex"] = clientIndex
			        
			        player["Status"]:SetText(playerStatus)
			        
			        local white = GUIScoreboard.kWhiteColor
			        local baseColor, nameColor, statusColor = white, white, white
			        
					if playerRecord.IsRookie then
			            nameColor = kNewPlayerColorFloat    
			        end
			        
			        player["Status"]:SetColor(statusColor)
			        player["Name"]:SetColor(nameColor)
			            
					if teamNumber == 0 then
					    if Shine.Plugins.scoreboard:GetFailsBkaPrerequisite(clientIndex) then
							player.Name:SetColor(TGNS.Colors.BkaFail)
						elseif Shine.Plugins.scoreboard:GetFailsNewCommsPrerequisite(clientIndex) then
							player.Name:SetColor(TGNS.Colors.NewCommsFail)
						end
					end

			        currentY = currentY + (GUIScoreboard.kPlayerItemHeight + GUIScoreboard.kPlayerSpacing) * GUIScoreboard.kScalingFactor
			        currentPlayerIndex = currentPlayerIndex + 1
			        
			        local numberSize = 0
			        if player["Number"]:GetIsVisible() then
			            numberSize = kPlayerNumberWidth
			        end
			        
			        local statusPos = ConditionalValue(GUIScoreboard.screenWidth < 1280, GUIScoreboard.kPlayerItemWidth + 30, (teamItemWidth - GUIScoreboard.kTeamColumnSpacingX * 10) + 60)
			        if rolesClientData[string.format("c%s", clientIndex)] then
			        	playerStatus = ""
				        if playerRecord.EntityTeamNumber == kMarineTeamType then
				        	player["Background"]:SetColor(GUIScoreboard.kBlueColor)
				        	playerStatus = "(M)"
				        elseif playerRecord.EntityTeamNumber == kAlienTeamType then
				        	playerStatus = "(A)"
				        	player["Background"]:SetColor(GUIScoreboard.kRedColor)
				        end
			            player["Status"]:SetText(playerStatus)
			            statusPos = statusPos + GUIScoreboard.kTeamColumnSpacingX * ConditionalValue(GUIScoreboard.screenWidth < 1280, 2.75, 1.75)
			        end
			        
			        local pos = numberSize + kPlayerItemLeftMargin




				        for i = 1, #player["BadgeItems"] do
				            player["BadgeItems"][i]:SetPosition(Vector(numberSize + kPlayerItemLeftMargin + (i-1) * kPlayerVoiceChatIconSize + (i-1) * kPlayerBadgeRightPadding, -kPlayerVoiceChatIconSize/2, 0) * GUIScoreboard.kScalingFactor)
				        end
				        local clientIndexBadgeTextures = teamNameText == "Pickable Players" and Badges_GetBadgeTextures(clientIndex, "scoreboard") or {}
				        SetPlayerItemBadges( player, clientIndexBadgeTextures )
				        
				        local numBadges = math.min(#clientIndexBadgeTextures, #player["BadgeItems"])
				        pos = pos + (numBadges * kPlayerVoiceChatIconSize + numBadges * kPlayerBadgeRightPadding) * GUIScoreboard.kScalingFactor
				        pos = pos * GUIScoreboard.kScalingFactor




			        if teamNameText == "Pickable Players" then
			        end
			        
			        player["Name"]:SetPosition(Vector(pos, 0, 0))
			        
			        -- Icons on the right side of the player name
			        player["SteamFriend"]:SetIsVisible(playerRecord.IsSteamFriend or clientIndex == Client.GetLocalClientIndex())
			        
			        local nameRightPos = pos + (kPlayerBadgeRightPadding * GUIScoreboard.kScalingFactor)
			        
			        pos = (statusPos - kPlayerBadgeRightPadding) * GUIScoreboard.kScalingFactor
			        
			        local finalName = player["Name"]:GetText()
			        local finalNameWidth = player["Name"]:GetTextWidth(finalName) * GUIScoreboard.kScalingFactor
			        local dotsWidth = player["Name"]:GetTextWidth("...") * GUIScoreboard.kScalingFactor
			        -- The minimum truncated length for the name also includes the "..."
			        while nameRightPos + finalNameWidth > pos and string.UTF8Length(finalName) > kMinTruncatedNameLength do
			            finalName = string.UTF8Sub(finalName, 1, string.UTF8Length(finalName)-1)
			            finalNameWidth = (player["Name"]:GetTextWidth(finalName) * GUIScoreboard.kScalingFactor) + dotsWidth
			            player["Name"]:SetText(finalName .. "...")
			        end
			        
			        local color = Color(0.5, 0.5, 0.5, 1)
			        if isCommander then
			            color = GUIScoreboard.kCommanderFontColor * 0.8
			        else
			            color = teamColor * 0.8
			        end
			        
			        if not MainMenu_GetIsOpened() then
			            if MouseTracker_GetIsVisible() then
			            	if GUIItemContainsPoint(player["Background"], mouseX, mouseY) and (not Shine.VoteMenu.Visible) then
				                local canHighlight = true
				                for _, icon in ipairs(player["IconTable"]) do
				                    if icon:GetIsVisible() and GUIItemContainsPoint(icon, mouseX, mouseY) and not icon.allowHighlight then
				                        canHighlight = false
				                        break
				                    end
				                end

				                for i = 1, #player.BadgeItems do
				                    local badgeItem = player.BadgeItems[i]
				                    if GUIItemContainsPoint(badgeItem, mouseX, mouseY) and badgeItem:GetIsVisible() then
				                        local clientIndex = player["ClientIndex"]
				                        local _, badgeNames = Badges_GetBadgeTextures(clientIndex, "scoreboard")
				                        local badge = ToString(badgeNames[i])
				                        badgeNameTooltip:SetText(GetBadgeFormalName(badge))
				                        hoverBadge = true
				                        break
				                    end
				                end


				               	TGNS.DoForPairs(player, function(key, i)
				               		local tooltipText
				               		if TGNS.EndsWith(key, "PercentIcon") and i.tooltipText then
				               			if i.tooltipText == "Kill/Death Ratio" then
				               				tooltipText = "Kill/Death Ratio (Recent)\n\nThis icon displays only for remarkably high Marine KD.\n\nOpaqueness shows higher KD."
				               			else
				               				tooltipText = string.format("%s Playtime (Recent)\n\nThis icon's transparency shows roughly\nhow much game time this player has spent\nplaying in this role rather than other roles.\n\nOpaqueness shows more relative playtime.", i.tooltipText)
				               			end
				               		end
				               		if tooltipText then
					                    if GUIItemContainsPoint(i, mouseX, mouseY) and i:GetIsVisible() then
					                        badgeNameTooltip:SetText(string.format("%s\n_____________________________________\nOnly TGNS gameplay contributes to this data.", tooltipText))
					                        hoverBadge = true
					                        return true
					                    end
				               		end
				               	end)
				            
				                if canHighlight then
				                    hoverPlayerClientIndex = clientIndex
				                    player["Background"]:SetColor(color)
				                else
				                    hoverPlayerClientIndex = 0
				                end
			            	end
			            end
			        elseif steamId == GetSteamIdForClientIndex(hoverPlayerClientIndex) then
			            player["Background"]:SetColor(color)
			        end

			        if teamNameText == "Pickable Players" then
					    player["GorgePercentIcon"]:SetIsVisible(true)
					    player["LerkPercentIcon"]:SetIsVisible(true)
					    player["FadePercentIcon"]:SetIsVisible(true)
					    player["OnosPercentIcon"]:SetIsVisible(true)
					    player["MarineCommPercentIcon"]:SetIsVisible(true)
					    player["AlienCommPercentIcon"]:SetIsVisible(true)
					    player["KdPercentIcon"]:SetIsVisible(true)
				        local gorgePercentIconTransparency = 0
				        local lerkPercentIconTransparency = 0
				        local fadePercentIconTransparency = 0
				        local onosPercentIconTransparency = 0
				        local marineCommPercentIconTransparency = 0
				        local alienCommPercentIconTransparency = 0
				        local kdPercentIconTransparency = 0
				        local rolesData = rolesClientData[string.format("c%s", clientIndex)]
				        if rolesData then
				        	gorgePercentIconTransparency = rolesData[1]
				        	lerkPercentIconTransparency = rolesData[2]
				        	fadePercentIconTransparency = rolesData[3]
				        	onosPercentIconTransparency = rolesData[4]
				        	marineCommPercentIconTransparency = rolesData[5]
				        	alienCommPercentIconTransparency = rolesData[6]
				        	kdPercentIconTransparency = rolesData[7]
				        end
			        	player["GorgePercentIcon"]:SetColor(Color(1,1,1,gorgePercentIconTransparency))
			        	player["LerkPercentIcon"]:SetColor(Color(1,1,1,lerkPercentIconTransparency))
			        	player["FadePercentIcon"]:SetColor(Color(1,1,1,fadePercentIconTransparency))
			        	player["OnosPercentIcon"]:SetColor(Color(1,1,1,onosPercentIconTransparency))
			        	player["MarineCommPercentIcon"]:SetColor(Color(1,1,1,marineCommPercentIconTransparency))
			        	player["AlienCommPercentIcon"]:SetColor(Color(1,1,1,alienCommPercentIconTransparency))
			        	player["KdPercentIcon"]:SetColor(Color(1,1,1,kdPercentIconTransparency))

			        	player["GorgePercentIcon"]:SetIsVisible(gorgePercentIconTransparency > 0)
			        	player["LerkPercentIcon"]:SetIsVisible(lerkPercentIconTransparency > 0)
			        	player["FadePercentIcon"]:SetIsVisible(fadePercentIconTransparency > 0)
			        	player["OnosPercentIcon"]:SetIsVisible(onosPercentIconTransparency > 0)
			        	player["MarineCommPercentIcon"]:SetIsVisible(marineCommPercentIconTransparency > 0)
			        	player["AlienCommPercentIcon"]:SetIsVisible(alienCommPercentIconTransparency > 0)
			        	player["KdPercentIcon"]:SetIsVisible(kdPercentIconTransparency > 0)
			        else
					    player["GorgePercentIcon"]:SetIsVisible(false)
					    player["LerkPercentIcon"]:SetIsVisible(false)
					    player["FadePercentIcon"]:SetIsVisible(false)
					    player["OnosPercentIcon"]:SetIsVisible(false)
					    player["MarineCommPercentIcon"]:SetIsVisible(false)
					    player["AlienCommPercentIcon"]:SetIsVisible(false)
					    player["KdPercentIcon"]:SetIsVisible(false)
			        end
			    end

			    local logo = updateTeam["GUIs"]["Logo"]
			    logo:SetIsVisible(teamNameText ~= "Pickable Players")
			end

			function Plugin:PlayerKeyPress(key, down, amount)
				if GetIsBinding(key, "Scoreboard") then
					scoreboardIsBeingShown = down
					if not down and userHasToggledCaptainsBoardDisplayOn ~= nil then
						userHasToggledCaptainsBoardDisplayOn = not userHasToggledCaptainsBoardDisplayOn
					end
				end

				if captainsBoardShouldBeShown() then
				    if key == InputKey.MouseButton0 and mousePressed["LMB"]["Down"] ~= down then
				        mousePressed["LMB"]["Down"] = down
				        if down then
				            local mouseX, mouseY = Client.GetCursorPosScreen()
				            isDragging = GUIItemContainsPoint(slidebarBg, mouseX, mouseY)
				            if not MouseTracker_GetIsVisible() then
				                SetMouseVisible(true)
				            end
				            return true
				        end
				    elseif key == InputKey.MouseButton1 then
			            if MouseTracker_GetIsVisible() then
			                SetMouseVisible(false)
			            end
			            return true
				    end

				    if slidebarBg:GetIsVisible() then
				        if key == InputKey.MouseWheelDown then
				            slidePercentage = math.min(slidePercentage + 5, 100)
				            return true
				        elseif key == InputKey.MouseWheelUp then
				            slidePercentage = math.max(slidePercentage - 5, 0)
				            return true
				        elseif key == InputKey.PageDown and down then
				            slidePercentage = math.min(slidePercentage + 10, 100)
				            return true
				        elseif key == InputKey.PageUp and down then
				            slidePercentage = math.max(slidePercentage - 10, 0)
				            return true
				        elseif key == InputKey.Home then
				            slidePercentage = 0
				            return true
				        elseif key == InputKey.End then
				            slidePercentage = 100
				            return true
				        end
				    end
				end
			end

			local function destroyCaptainsBoard()
			    for index, team in ipairs(teams) do
			        GUI.DestroyItem(team["GUIs"]["Background"])
			    end
			    teams = { }
			    
			    for index, playerItem in ipairs(reusePlayerItems) do
			        GUI.DestroyItem(playerItem["Background"])
			    end
			    reusePlayerItems = { }
			    
			    GUI.DestroyItem(clickForMouseIndicator)
			    clickForMouseIndicator = nil
			    GUI.DestroyItem(clickForMouseBackground)
			    clickForMouseBackground = nil
			    			    
			    GUI.DestroyItem(scoreboardBackground)
			    scoreboardBackground = nil
			    
			    GUI.DestroyItem(background)
			    background = nil
			    
			    GUI.DestroyItem(playerHighlightItem)
			    playerHighlightItem = nil
			end

			function Plugin:OnResolutionChanged( OldX, OldY, NewX, NewY )
				destroyCaptainsBoard()
			end

			function Plugin:Think(deltaTime)
				contentYSize = 10
				teamItemWidth = GUIScoreboard:GetTeamItemWidth() * .7
				kBgMaxYSpace = GUIScoreboard.kBgMaxYSpace
				if not scoreboardBackground then
					slidePercentage = -1
					
				    scoreboardBackground = GUIManager:CreateGraphicItem()
				    scoreboardBackground:SetAnchor(GUIItem.Middle, GUIItem.Center)
				    scoreboardBackground:SetLayer(guiLayer)
				    scoreboardBackground:SetColor(GUIScoreboard.kBgColor)

				    background = GUIManager:CreateGraphicItem()
				    background:SetAnchor(GUIItem.Middle, GUIItem.Center)
				    background:SetLayer(guiLayer)
				    background:SetColor(GUIScoreboard.kBgColor)
				    background:SetIsVisible(false)

				    table.insert(teams, { GUIs = CreateTeamBackground(GUIScoreboard.kSpectatorColor, guiLayer), TeamTitle = "Pickable Players",
				                               Color = GUIScoreboard.kSpectatorColor, PlayerList = { }, HighlightColor = GUIScoreboard.kSpectatorHighlightColor,
				                               GetScores = function()
				                               		return optedInScores
				                               end, TeamNumber = kTeamReadyRoom })

				    table.insert(teams, { GUIs = CreateTeamBackground(GUIScoreboard.kSpectatorColor, guiLayer), TeamTitle = "Not Opted In",
				                               Color = GUIScoreboard.kSpectatorColor, PlayerList = { }, HighlightColor = GUIScoreboard.kSpectatorHighlightColor,
				                               GetScores = function()
				                               		return notOptedInScores
				                               end, TeamNumber = kMarineTeamType })
				                               
				    background:AddChild(teams[1].GUIs.Background)
				    background:AddChild(teams[2].GUIs.Background)

				    playerHighlightItem = GUIManager:CreateGraphicItem()
				    playerHighlightItem:SetSize(Vector(teamItemWidth - (GUIScoreboard.kPlayerItemWidthBuffer * 2), GUIScoreboard.kPlayerItemHeight, 0) * GUIScoreboard.kScalingFactor)
				    playerHighlightItem:SetAnchor(GUIItem.Left, GUIItem.Top)
				    playerHighlightItem:SetColor(Color(1, 1, 1, 1))
				    playerHighlightItem:SetTexture("ui/hud_elements.dds")
				    playerHighlightItem:SetTextureCoordinates(0, 0.16, 0.558, 0.32)
				    playerHighlightItem:SetStencilFunc(GUIItem.NotEqual)
				    playerHighlightItem:SetIsVisible(false)

				    clickForMouseBackground = GUIManager:CreateGraphicItem()
				    clickForMouseBackground:SetSize(GUIScoreboard.kClickForMouseBackgroundSize)
				    clickForMouseBackground:SetPosition(Vector(-GUIScoreboard.kClickForMouseBackgroundSize.x / 2, -GUIScoreboard.kClickForMouseBackgroundSize.y - 5, 0))
				    clickForMouseBackground:SetAnchor(GUIItem.Middle, GUIItem.Bottom)
				    clickForMouseBackground:SetIsVisible(false)

				    clickForMouseIndicator = GUIManager:CreateTextItem()
				    clickForMouseIndicator:SetFontName(GUIScoreboard.kClickForMouseFontName)
				    clickForMouseIndicator:SetScale(GetScaledVector())
				    GUIMakeFontScale(clickForMouseIndicator)
				    clickForMouseIndicator:SetAnchor(GUIItem.Middle, GUIItem.Center)
				    clickForMouseIndicator:SetTextAlignmentX(GUIItem.Align_Center)
				    clickForMouseIndicator:SetTextAlignmentY(GUIItem.Align_Center)
				    clickForMouseIndicator:SetColor(Color(0, 0, 0, 1))
				    clickForMouseIndicator:SetText(GUIScoreboard.kClickForMouseText)
				    clickForMouseBackground:AddChild(clickForMouseIndicator)

				    backgroundStencil = GUIManager:CreateGraphicItem()
				    backgroundStencil:SetIsStencil(true)
				    backgroundStencil:SetClearsStencilBuffer(true)
				    scoreboardBackground:AddChild(backgroundStencil)

				    slidebar = GUIManager:CreateGraphicItem()
				    slidebar:SetAnchor(GUIItem.Left, GUIItem.Top)
				    slidebar:SetSize(GUIScoreboard.kSlidebarSize * GUIScoreboard.kScalingFactor)
				    slidebar:SetLayer(guiLayer)
				    slidebar:SetColor(Color(1, 1, 1, 1))
				    slidebar:SetIsVisible(true)

				    slidebarBg = GUIManager:CreateGraphicItem()
				    slidebarBg:SetAnchor(GUIItem.Right, GUIItem.Top)
				    slidebarBg:SetSize(Vector(GUIScoreboard.kSlidebarSize.x * GUIScoreboard.kScalingFactor, kBgMaxYSpace-20, 0))
				    slidebarBg:SetPosition(Vector(-12.5 * GUIScoreboard.kScalingFactor, 10, 0))
				    slidebarBg:SetLayer(guiLayer)
				    slidebarBg:SetColor(Color(0.25, 0.25, 0.25, 1))
				    slidebarBg:SetIsVisible(false)
				    slidebarBg:AddChild(slidebar)
				    scoreboardBackground:AddChild(slidebarBg)

				    hoverPlayerClientIndex = 0

				    badgeNameTooltip = GetGUIManager():CreateGUIScript("menu/GUIHoverTooltip")
				end

				if captainsBoardShouldBeShown() then
				    --First, update teams.
				    local teamGUISize = {}

				    hoverBadge = false

				    for index, team in ipairs(teams) do
				    
				        -- Don't draw if no players on team
				        local numPlayers = table.count(team["GetScores"]())
				        team["GUIs"]["Background"]:SetIsVisible(true) -- captainsBoardShouldBeShown() and (numPlayers > 0)
				        
				        if captainsBoardShouldBeShown() then
				            UpdateTeam(team)
			                if teamGUISize[team.TeamNumber] == nil then
			                    teamGUISize[team.TeamNumber] = {}
			                end
			                teamGUISize[team.TeamNumber] = teams[index].GUIs.Background:GetSize().y
				        end
				        
				    end

			        if hoverBadge then
			            badgeNameTooltip:Show()
			        else
			            badgeNameTooltip:Hide(0)
			        end


			        local teamItemWidth = teamItemWidth * GUIScoreboard.kScalingFactor
			        local teamItemVerticalFormat = teamItemWidth*2 > GUIScoreboard.screenWidth
			        local contentXOffset = (GUIScoreboard.screenWidth - teamItemWidth * 2) / 2
			        local contentXExtraOffset = ConditionalValue(GUIScoreboard.screenWidth > 1900, contentXOffset * 0.33, 15 * GUIScoreboard.kScalingFactor)
			        local contentXSize = teamItemWidth + contentXExtraOffset * 2
			        local contentYSpacing = 20 * GUIScoreboard.kScalingFactor

			        if teamGUISize[1] then
		                teams[2].GUIs.Background:SetPosition(Vector(-teamItemWidth / 2, contentYSize, 0))
		                contentYSize = contentYSize + teamGUISize[1] + contentYSpacing
			        end
			        if teamGUISize[0] then
			            teams[1].GUIs.Background:SetPosition(Vector(-teamItemWidth / 2, contentYSize, 0))
			            contentYSize = contentYSize + teamGUISize[0] + contentYSpacing
			        end

        	        local slideOffset = -(slidePercentage * contentYSize/100)+(slidePercentage * slidebarBg:GetSize().y/100)
			        local displaySpace = Client.GetScreenHeight() - 100
			        local showSlidebar = contentYSize > displaySpace
			        local ySize = math.min(displaySpace, contentYSize)

			        local sliderPos = (slidePercentage * slidebarBg:GetSize().y/100)
			        if sliderPos < slidebar:GetSize().y/2 then
			            sliderPos = 0
			        end
			        if sliderPos > slidebarBg:GetSize().y - slidebar:GetSize().y then
			            sliderPos = slidebarBg:GetSize().y - slidebar:GetSize().y
			        end

			        background:SetPosition(Vector(0, 10+(-ySize/2+slideOffset), 0))
			        scoreboardBackground:SetSize(Vector(contentXSize, ySize, 0))
			        scoreboardBackground:SetPosition(Vector(-contentXSize/2, -ySize/2, 0))
			        backgroundStencil:SetSize(Vector(contentXSize, ySize-20, 0))
			        backgroundStencil:SetPosition(Vector(0, 10, 0))

			        slidebar:SetPosition(Vector(0, sliderPos, 0))
			        slidebarBg:SetIsVisible(showSlidebar)
			        scoreboardBackground:SetColor(ConditionalValue(showSlidebar, GUIScoreboard.kBgColor, Color(0, 0, 0, 0)))


			        local mouseX, mouseY = Client.GetCursorPosScreen()
			        if mousePressed["LMB"]["Down"] and isDragging then
			            HandleSlidebarClicked(mouseX, mouseY)
			        end
				end

				if captainsBoardShouldBeShown() then
					background:SetIsVisible(true)
				    scoreboardBackground:SetIsVisible(true)
					clickForMouseBackground:SetIsVisible(true)
				else
					background:SetIsVisible(false)
				    scoreboardBackground:SetIsVisible(false)
					clickForMouseBackground:SetIsVisible(false)
					SetMouseVisible(false)
					badgeNameTooltip:Hide(0)
				end

			end
		end

		-- local originalGUIGameEndSetGameEnded = GUIGameEnd.SetGameEnded
		-- GUIGameEnd.SetGameEnded = function(guiGameEndSelf, playerWon, playerDraw, playerTeamType)
		-- 	if playerDraw then
		-- 		originalGUIGameEndSetGameEnded(guiGameEndSelf, playerWon, playerDraw, playerTeamType)
		-- 	else
		-- 		originalGUIGameEndSetGameEnded(guiGameEndSelf, true, playerDraw, playerWon and playerTeamType or )
		-- 	end
		-- end
	end

	if Server then
		local md
		local captainClients = {}
		local captainsModeEnabled
		local captainsGamesFinished = 0
		local readyTeams = {}
		local captainTeamNumbers = {}
		local gameStarted
		local readyPlayerClients = {}
		local readyCaptainClients = {}
		local timeAtWhichToForceRoundStart
		local SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START = 270
		local whenToAllowTeamJoins = 0
		local votesAllowedUntil
		local mayVoteYet
		local automaticVoteAllowAction = function()
			mayVoteYet = true
		end
		local MIN_CAPTAINS_PLAYERS = 8
		local lastVoiceWarningTimes = {}
		local plans = {}
		local highVolumeMessagesLastShownTime
		local bannerDisplayed
		local showRemainingTimer
		//local lastOptInAttemptWhen = {}
		local OPT_IN_THROTTLE_IN_SECONDS = 3
		local allPlayersWereArtificiallyForcedToReadyRoom
		local setSpawnsSummaryText
		local confirmedConnectedClients = {}
		local captainsGamesWon = {}
		local recentCaptainPlayerIds = {}
		local recentPlayerPlayerIds = {}
		local rolandHasBeenUsed = false
		local momentWhenCaptainsModeWasEnabled
		local momentsWhenLastLeftPlayingTeam = {}
		local momentWhenSecondCaptainOptedIn
		local ALLOW_VOTE_MAXIMUM_LIMIT_IN_SECONDS = 115
		local RESTRICTED_OPTIN_DURATION_IN_SECONDS = 0 -- 5
		local PLAN_DISPLAY_LENGTH = 9
		local OPTIN_VOTE_DURATION = 90
		local lastUpdateCaptainsReadyProgress = {}
		local infiniteTimeRemainingDisplayStarted
		local hasEarnedSetSpawnsKarma = {}
		local hasEarnedCaptainsNightPunctualityKarma = {}
		local CAPTAINS_NIGHT_START_HOUR_LOCAL_SERVER_TIME = 20
		local recentCaptainsData = {}
		local recentCaptainsTempfilePath = "config://tgns/temp/recentcaptains.json"
		local rolesServerData = {}
		local captainsEventStartPushSent = false
		local gameLastEndedAt
		local nextGameSpawnLocationsSummary

		local function disableCaptainsMode()
			captainsModeEnabled = false
		end

		local function getTeamChoiceCaptainClient(clients)
			return clients[1]
		end

		local function getPlayerChoiceCaptainClient(clients)
			return clients[2]
		end

		local function startGame()
			if timeAtWhichToForceRoundStart and timeAtWhichToForceRoundStart ~= 0 then
				timeAtWhichToForceRoundStart = 0
				TGNS.ScheduleAction(2, function()
					if not (TGNS.IsGameInCountdown() or TGNS.IsGameInProgress()) then
						TGNS.ForceGameStart(true)
					end
				end)
			end
		end

		local function bothTeamsAreReady()
			local result = readyTeams["Marines"] == true and readyTeams["Aliens"] == true
			return result
		end

		local function warnOfPendingCaptainsGameStart()
			local now = TGNS.GetSecondsSinceMapLoaded()
			if timeAtWhichToForceRoundStart and timeAtWhichToForceRoundStart ~= 0 then
				if bothTeamsAreReady() then
					TGNS.ScheduleAction(1, warnOfPendingCaptainsGameStart)
				else
					if not TGNS.IsGameInCountdown() and not TGNS.IsGameInProgress() then
						local message
						local duration = 3
						local r = 0
						local g = 255
						local b = 0
						local secondsRemaining = timeAtWhichToForceRoundStart - now
						if secondsRemaining >= 1 then
							--message = string.format("Game will force-start in %s.\nType in team chat: !plan", string.DigitalTime(secondsRemaining))
							message = string.format("Game will force-start in %s.\n\nStarting without a commander\ncauses a random team member\nto begin with 0 personal resources.", string.DigitalTime(secondsRemaining))
							if secondsRemaining < 30 then
								r = 255
								g = 255
								b = 0
							end

							if Shine.Plugins.timedstart and Shine.Plugins.timedstart.WarnPlayersOfImminentGameStart then
								Shine.Plugins.timedstart:WarnPlayersOfImminentGameStart(TGNS.GetPlayerList(), secondsRemaining)
							end

							TGNS.ScheduleAction(1, warnOfPendingCaptainsGameStart)
						else
							message = "Planning time expired.\nGame is force-starting now."
							duration = 7
							startGame()
							r = 255
							g = 0
							b = 0
						end
						Shine.ScreenText.Add(51, {X = 0.5, Y = 0.85, Text = message, Duration = duration, R = r, G = g, B = b, Alignment = TGNS.ShineTextAlignmentCenter, Size = 1, FadeIn = 0, IgnoreFormat = true})

						if captainsGamesFinished == 1 then
							Shine.ScreenText.Add(58, {X = 0.75, Y = 0.1, Text = "Round 2 swaps\nspawn locations!", Duration = 3, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true})
						end


					end
				end
			end
		end

		local function remindTeam(teamName, teamNumber)
			if captainsModeEnabled and not (TGNS.IsGameInProgress() or readyTeams[teamName]) then
				local otherTeamName = TGNS.GetOtherPlayingTeamName(teamName)
				md:ToTeamNotifyInfo(teamNumber, string.format("Play will begin when %s 'ready' in chat.", readyTeams[otherTeamName] and "your team types" or "both teams type"))
				TGNS.ScheduleAction(readyTeams[otherTeamName] and 20 or 40, function() remindTeam(teamName, teamNumber) end)
			end
		end

		local function remindTeams()
			remindTeam("Marines", kMarineTeamType)
			remindTeam("Aliens", kAlienTeamType)
		end

		local function setTimeAtWhichToForceRoundStart()
			timeAtWhichToForceRoundStart = TGNS.GetSecondsSinceMapLoaded() + SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START + 30 + (captainsGamesFinished == 0 and 60 or 0)
			TGNS.ScheduleAction(29, warnOfPendingCaptainsGameStart)
			TGNS.ScheduleAction(30, remindTeams)
		end

		local function showRoster(clients, renderClients, titleMessageId, column1MessageId, column2MessageId, titleY, titleText)
			local columnsY = titleY + 0.05
			local clientNameGetter = function(c)
				local nameToDisplay = string.format("%s%s%s", TGNS.IsPlayerAFK(TGNS.GetPlayer(c)) and "!" or "", TGNS.GetClientName(c), TGNS.PlayerAction(c, TGNS.IsPlayerSpectator) and " (Spec)" or "")
				return TGNS.Truncate(nameToDisplay, 16)
			end
			local names = TGNS.Select(clients, clientNameGetter)
			TGNS.ShowPanel(names, renderClients, titleMessageId, column1MessageId, column2MessageId, titleY, titleText, #names, 3, "(None)")
		end

		local sendRolesDataToAllPlayers = function(optedInClients)
			--md:ToAdminNotifyInfo(string.format("sendRolesDataToAllPlayers: optedInClients count: %s", #optedInClients))

			local data = {o = #TGNS.Where(readyPlayerClients, function(c) return Shine:IsValidClient(c) end), c = TGNS.Select(TGNS.Where(captainClients, function(c) return Shine:IsValidClient(c) end), TGNS.GetClientIndex), p=TGNS.ToTable(TGNS.Where(optedInClients, function(c) return Shine:IsValidClient(c) end), function(c) return string.format("c%s", TGNS.GetClientIndex(c)) end, function(c)
				local minimumTransparency = 0.1
				local transparencyBoost = 0.3
				local gorgePercent = 0
				local lerkPercent = 0
				local fadePercent = 0
				local onosPercent = 0
				local marineCommPercent = 0
				local alienCommPercent = 0
				local kdPercent = 0
				local steamId = TGNS.GetClientSteamId(c)
				local d = TGNS.FirstOrNil(rolesServerData, function(d) return d.PlayerId == steamId end)
				if d then
					local lifeformSecondsSum = d.GorgeSeconds + d.LerkSeconds + d.FadeSeconds + d.OnosSeconds
					local commSecondsSum = d.MarineCommSeconds + d.AlienCommSeconds
					local highestRelevantKd = 4.2
					local lowestRelevantKd = 3.6
					kdPercent = d.KD >= highestRelevantKd and 1 or (d.KD >= lowestRelevantKd and ((d.KD-lowestRelevantKd)/(highestRelevantKd-lowestRelevantKd))+transparencyBoost or 0)
					
					if lifeformSecondsSum > 1800 or commSecondsSum > 1800 then
						if lifeformSecondsSum > 1800 then
							gorgePercent = math.floor((d.GorgeSeconds / lifeformSecondsSum) * 100) / 100
							lerkPercent = math.floor((d.LerkSeconds / lifeformSecondsSum) * 100) / 100
							fadePercent = math.floor((d.FadeSeconds / lifeformSecondsSum) * 100) / 100
							onosPercent = math.floor((d.OnosSeconds / lifeformSecondsSum) * 100) / 100
						end
						if commSecondsSum > 1800 then
							marineCommPercent = math.floor((d.MarineCommSeconds / commSecondsSum) * 100) / 100
							alienCommPercent = math.floor((d.AlienCommSeconds / commSecondsSum) * 100) / 100
						end
						gorgePercent = gorgePercent >= minimumTransparency and gorgePercent + transparencyBoost or minimumTransparency
						lerkPercent = lerkPercent >= minimumTransparency and lerkPercent + transparencyBoost or minimumTransparency
						fadePercent = fadePercent >= minimumTransparency and fadePercent + transparencyBoost or minimumTransparency
						onosPercent = onosPercent >= minimumTransparency and onosPercent + transparencyBoost or minimumTransparency
						marineCommPercent = marineCommPercent >= minimumTransparency and marineCommPercent + transparencyBoost or minimumTransparency
						alienCommPercent = alienCommPercent >= minimumTransparency and alienCommPercent + transparencyBoost or minimumTransparency
					end
				end
				local result = {gorgePercent,lerkPercent,fadePercent,onosPercent,marineCommPercent,alienCommPercent,kdPercent}
				return result
			end)}
			local dataJson = json.encode(data)
			TGNS.DoFor(TGNS.GetPlayerList(), function(p)
				TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.captains.CAPTAINS_DATA, {d=dataJson})
			end)
		end

		local function getRolesData(steamIds)
			if #steamIds > 0 then
				local playerIdsInput = TGNS.Join(steamIds, ",")
				local url = string.format("%s&d=%s&i=%s", TGNS.Config.RolesEndpointBaseUrl, 30, playerIdsInput)
				TGNS.GetHttpAsync(url, function(rolesResponseJson)
					local rolesResponse = json.decode(rolesResponseJson) or {}
					if rolesResponse.success then
						TGNS.DoFor(rolesResponse.result, function(r)
							if not TGNS.Any(rolesServerData, function(d) return d.PlayerId == r.PlayerId end) then
								table.insert(rolesServerData, r)
							end
						end)
					else
						TGNS.DebugPrint(string.format("captains ERROR: Unable to access roles data for playerIds %s. url: %s | msg: %s | response: %s | stacktrace: %s", playerIdsInput, url, rolesResponse.msg, rolesResponseJson, rolesResponse.stacktrace))
					end
				end)
			end
		end

		local function showPickables()
			if not TGNS.IsGameInProgress() and not TGNS.IsGameInCountdown() then
				if captainsGamesFinished == 0 then
					TGNS.ScheduleAction(1.5, showPickables)
					local allClients = TGNS.GetClientList()
					local readyRoomClients = TGNS.GetReadyRoomClients()
					local teamChoiceCaptainClient = (#captainClients > 0 and Shine:IsValidClient(getTeamChoiceCaptainClient(captainClients))) and getTeamChoiceCaptainClient(captainClients) or nil
					local playerChoiceCaptainClient = (#captainClients > 1 and Shine:IsValidClient(getPlayerChoiceCaptainClient(captainClients))) and getPlayerChoiceCaptainClient(captainClients) or nil
					if teamChoiceCaptainClient and playerChoiceCaptainClient then
						local teamChoiceCaptainName = TGNS.GetClientName(teamChoiceCaptainClient)
						local playerChoiceCaptainName = TGNS.GetClientName(playerChoiceCaptainClient)

						if teamChoiceCaptainClient and TGNS.ClientIsOnPlayingTeam(teamChoiceCaptainClient) then
							local teamChoiceCaptainTeamNumber = TGNS.GetClientTeamNumber(teamChoiceCaptainClient)
							local teamChoiceCaptainTeammateClients = TGNS.GetTeamClients(teamChoiceCaptainTeamNumber, TGNS.GetPlayerList())
							TGNS.DoFor(teamChoiceCaptainTeammateClients, function(c)
								local truncatedTeamChoiceCaptainName = TGNS.Truncate(teamChoiceCaptainName, 16)
								local message = setSpawnsSummaryText and string.format("%s has selected\nthe game's spawn locations!", truncatedTeamChoiceCaptainName) or string.format("%s: Select Spawns!\nM > Captains > sh_setspawns", truncatedTeamChoiceCaptainName)
								Shine.ScreenText.Add(58, {X = 0.75, Y = 0.1, Text = message, Duration = 3, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
							end)
						end
						if playerChoiceCaptainClient and TGNS.ClientIsOnPlayingTeam(playerChoiceCaptainClient) then
							local playerChoiceCaptainTeamNumber = TGNS.GetClientTeamNumber(playerChoiceCaptainClient)
							local playerChoiceCaptainTeammateClients = TGNS.GetTeamClients(playerChoiceCaptainTeamNumber, TGNS.GetPlayerList())
							TGNS.DoFor(playerChoiceCaptainTeammateClients, function(c)
								local message = "Other team will\npick spawn locations."
								Shine.ScreenText.Add(58, {X = 0.75, Y = 0.1, Text = message, Duration = 3, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
							end)
						end
					end

					local optedInClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.ClientIsInGroup(c, "captainsgame_group") end)

					local playingReadyCaptainClients = TGNS.Where(readyCaptainClients, function(c) return Shine:IsValidClient(c) end)
					local playingReadyPlayerClients = TGNS.Where(readyPlayerClients, function(c) return Shine:IsValidClient(c) end)
					local rolesClients = TGNS.Where(TGNS.GetClientList(), function(c) return (TGNS.Has(playingReadyCaptainClients, c) or TGNS.Has(playingReadyPlayerClients, c)) end)
					local rolesClientsNeedingRoleData = TGNS.Where(rolesClients, function(c) return not TGNS.Any(rolesServerData, function(d) return d.PlayerId == TGNS.GetClientSteamId(c) end) end)
					local steamIdsOfOptedInClientsNeedingRoleData = TGNS.Select(rolesClientsNeedingRoleData, TGNS.GetClientSteamId)
					getRolesData(steamIdsOfOptedInClientsNeedingRoleData)
					sendRolesDataToAllPlayers(rolesClients)
				end
			end
		end

		local function swapCaptains()
			local newCaptainClients = {}
			table.insert(newCaptainClients, getPlayerChoiceCaptainClient(captainClients))
			table.insert(newCaptainClients, getTeamChoiceCaptainClient(captainClients))
			captainClients = newCaptainClients
		end

		local function enableCaptainsMode(nameOfEnabler, captain1Client, captain2Client)
			local randomizedCaptainClients = TGNS.GetRandomizedElements({captain1Client,captain2Client})
			captainClients = { randomizedCaptainClients[1], randomizedCaptainClients[2] }
			TGNS.AddTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
			captainTeamNumbers[getTeamChoiceCaptainClient(captainClients)] = 1
			captainTeamNumbers[getPlayerChoiceCaptainClient(captainClients)] = 2
			captainsModeEnabled = true
			momentWhenCaptainsModeWasEnabled = TGNS.GetSecondsSinceMapLoaded()
			setTimeAtWhichToForceRoundStart()
			captainsGamesFinished = 0
			TGNS.DoFor(captainClients, function(c)
				TGNS.AddTempGroup(c, "captains_group")
			end)
			TGNS.ScheduleAction(0, function()
				md:ToAllNotifyInfo(string.format("%s enabled Captains Game! Pick teams and play two rounds!", nameOfEnabler))
			end)
			allPlayersWereArtificiallyForcedToReadyRoom = true
			Shine.Plugins.mapvote.EndGame = function(mapVotePlugin) end
			TGNS.ForcePlayersToReadyRoom(TGNS.Where(TGNS.GetPlayerList(), function(p) return not TGNS.IsPlayerSpectator(p) end))
			whenToAllowTeamJoins = TGNS.GetSecondsSinceMapLoaded() + 20
			votesAllowedUntil = nil
			TGNS.ScheduleAction(1, showPickables)
			//Shine.Plugins.afkkick.Config.KickTime = 20
			TGNS.DoFor(TGNS.GetClientList(), function(c)
				Shine.ScreenText.End(93, c)
				Shine.ScreenText.End(94, c)
				Shine.ScreenText.End(92, c)
			end)
			TGNS.ScheduleAction(2, function()
				allPlayersWereArtificiallyForcedToReadyRoom = false
			end)
			Shine.Plugins.push:Push("tgns-captains", "TGNS Captains Game Starting", string.format("%s on %s. Server Info: http://rr.tacticalgamer.com/ServerInfo", TGNS.GetCurrentMapName(), TGNS.GetSimpleServerName()))
			TGNS.DoFor(TGNS.GetPlayerList(), TGNS.AlertApplicationIconForPlayer)
		end

		local function showBanner(headline)
			TGNS.DoFor(TGNS.GetClientList(), function(c)
				Shine.ScreenText.Add(41, {X = 0.5, Y = 0.2, Text = string.format("Captains?%s", headline), Duration = 5, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
			end)
			bannerDisplayed = true
		end

		local function getAdjustedNumberOfNeededReadyPlayerClients(playingClients)
			local minimumReadyPlayerClients = MIN_CAPTAINS_PLAYERS - 2
			local numberOfNeededReadyPlayerClients = #playingClients - 2
			if not rolandHasBeenUsed then
				numberOfNeededReadyPlayerClients = numberOfNeededReadyPlayerClients >= minimumReadyPlayerClients and numberOfNeededReadyPlayerClients or minimumReadyPlayerClients
				numberOfNeededReadyPlayerClients = TGNS.RoundPositiveNumberDown(numberOfNeededReadyPlayerClients * .75)
			end
			local result = numberOfNeededReadyPlayerClients <= MAX_NON_CAPTAIN_PLAYERS and numberOfNeededReadyPlayerClients or MAX_NON_CAPTAIN_PLAYERS
			return result
		end

		local function getCaptainCallText(captainName)
			local result = string.format("%s will Captain! Who else will Captain?", captainName)
			return result
		end

		local function getDescriptionOfWhatElseIsNeededToPlayCaptains(headlineReadyClient, playingClients, playingReadyPlayerClients, numberOfPlayingReadyCaptainClients, firstCaptainName, secondCaptainName)
			local result = ""
			if not captainsModeEnabled then
				local adjustedNumberOfNeededReadyPlayerClients = getAdjustedNumberOfNeededReadyPlayerClients(playingClients)
				--md:ToAllConsole(string.format("adjustedNumberOfNeededReadyPlayerClients: %s", adjustedNumberOfNeededReadyPlayerClients))
				local remaining = adjustedNumberOfNeededReadyPlayerClients - #playingReadyPlayerClients
				if not captainsModeEnabled and numberOfPlayingReadyCaptainClients == 1 then
					result = getCaptainCallText(firstCaptainName)
				elseif remaining > 0 then
					local headline = string.format(" (%s vs %s)", firstCaptainName, secondCaptainName)
					if not bannerDisplayed then
						showBanner(headline)
					end
					local howManyNeededMessage = votesAllowedUntil and string.format("%s more needed!", remaining) or ""
					local headlineReadyClientWantsCaptains = Shine:IsValidClient(headlineReadyClient) and TGNS.Has(readyPlayerClients, headlineReadyClient)
					local wantsMessage = headlineReadyClientWantsCaptains and string.format("%s wants Captains%s!", TGNS.GetClientName(headlineReadyClient), headline) or string.format("Who wants Captains%s?", headline)
					result = string.format("%s %s", wantsMessage, howManyNeededMessage)
				end
			end
			return result
		end

		local function getPlayingClients()
			local result = rolandHasBeenUsed and TGNS.GetClients(TGNS.Where(TGNS.GetPlayerList(), function(p) return not (TGNS.IsPlayerSpectator(p) or (TGNS.IsPlayerAFK(p))) end)) or TGNS.GetClients(TGNS.Where(TGNS.GetPlayerList(), TGNS.PlayerIsOnPlayingTeam))
			return result
		end

		local function updateCaptainsReadyProgress(readyClient)
			local playingClients = getPlayingClients()
			local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
			local twoCaptainsReady = #playingReadyCaptainClients > 1
			local firstCaptainName = #playingReadyCaptainClients > 0 and TGNS.GetClientName(playingReadyCaptainClients[1]) or "???"
			local secondCaptainName = twoCaptainsReady and TGNS.GetClientName(playingReadyCaptainClients[2]) or "???"
			local playingReadyPlayerClients = TGNS.Where(readyPlayerClients, function(c) return Shine:IsValidClient(c) end)
			local descriptionOfWhatElseIsNeededToPlayCaptains = getDescriptionOfWhatElseIsNeededToPlayCaptains(readyClient, playingClients, playingReadyPlayerClients, #playingReadyCaptainClients, firstCaptainName, secondCaptainName)
			if TGNS.HasNonEmptyValue(descriptionOfWhatElseIsNeededToPlayCaptains) then
				TGNS.DoFor(TGNS.GetClientList(), function(c)
					if (Shared.GetTime() - (lastUpdateCaptainsReadyProgress[c] or 0) > 1) or c == readyClient then
						Shine.ScreenText.Add(93, {X = 0.5, Y = 0.75, Text = descriptionOfWhatElseIsNeededToPlayCaptains, Duration = votesAllowedUntil and 120 or 10, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
						lastUpdateCaptainsReadyProgress[c] = Shared.GetTime()
					end
				end)
			else
				if not captainsModeEnabled then
					enableCaptainsMode(string.format("%s and %s", TGNS.GetClientName(playingReadyCaptainClients[1]), TGNS.GetClientName(playingReadyCaptainClients[2])), playingReadyCaptainClients[1], playingReadyCaptainClients[2])
				end
			end
		end

		local function getVoteSecondsRemaining()
			local result = votesAllowedUntil - TGNS.GetSecondsSinceMapLoaded()
			return result
		end

		local function announceTimeRemaining()
			if not captainsModeEnabled then
				local secondsRemaining = getVoteSecondsRemaining()
				if secondsRemaining > 1 then
					local timeLeftAdvisory = votesAllowedUntil == math.huge and "" or string.format("%s left.", string.DigitalTime(secondsRemaining))
					local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
					local firstCaptainName = #playingReadyCaptainClients > 0 and TGNS.GetClientName(playingReadyCaptainClients[1]) or "???"
					local secondCaptainName = #playingReadyCaptainClients > 1 and TGNS.GetClientName(playingReadyCaptainClients[2]) or "???"
					TGNS.DoFor(TGNS.GetClientList(), function(c)
						local optinStatusAdvisory = "Press 'M > Captains > sh_iwantcaptains' if you want to play Captains"
						local readyClientIsCaptain = TGNS.Has(playingReadyCaptainClients, c)
						if TGNS.Has(readyPlayerClients, c) or readyClientIsCaptain then
							optinStatusAdvisory = string.format("You're opted-in as ready to play%s (reserved slots disabled during Captains games)", readyClientIsCaptain and " as a Captain" or "")
						end
						local secondLineMessage = string.format("%s! %s", optinStatusAdvisory, timeLeftAdvisory)
						Shine.ScreenText.Add(92, {X = 0.5, Y = 0.85, Text = secondLineMessage, Duration = 10, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
					end)
					TGNS.ScheduleAction(1, announceTimeRemaining)
				else
					TGNS.ScheduleAction(1, function()
						if not captainsModeEnabled then
							TGNS.DoFor(TGNS.GetClientList(), function(c)
								Shine.ScreenText.Add(92, {X = 0.5, Y = 0.85, Text = "Captains vote expired.", Duration = 5, R = 255, G = 0, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 2, FadeIn = 0, IgnoreFormat = true}, c)
								Shine.ScreenText.End(93, c)
								Shine.ScreenText.End(94, c)
							end)
						end
					end)
				end
			end
		end

		local function removeReadyRoomAfkToMakeRoomForNewReadyPlayerClient(newReadyPlayerClientOptIn)
			if not TGNS.Has(readyPlayerClients, newReadyPlayerClientOptIn) then
				local playingReadyPlayerClients = TGNS.Where(readyPlayerClients, function(c) return Shine:IsValidClient(c) end)
				if #playingReadyPlayerClients >= MAX_NON_CAPTAIN_PLAYERS then
					local afkReadyRoomReadyPlayerClient = TGNS.FirstOrNil(TGNS.Where(readyPlayerClients, function(c) return Shine:IsValidClient(c) and TGNS.IsClientAFK(c) and TGNS.IsClientReadyRoom(c) and TGNS.GetPlayerAfkDurationInSeconds(TGNS.GetPlayer(c)) >= 60 end))
					if afkReadyRoomReadyPlayerClient then
	    				TGNS.RemoveAllMatching(readyPlayerClients, afkReadyRoomReadyPlayerClient)
						md:ToPlayerNotifyInfo(TGNS.GetPlayer(afkReadyRoomReadyPlayerClient), "You were removed from Captains opt-in due to AFK.")
	    				if captainsModeEnabled then
		    				md:ToAllNotifyInfo(string.format("%s is no longer opted in to Captains (AFK).", TGNS.GetClientName(afkReadyRoomReadyPlayerClient)))
	    				end
					end
				end
			end
		end

		local function addReadyPlayerClient(client)
			if votesAllowedUntil == nil then
				votesAllowedUntil = TGNS.GetSecondsSinceMapLoaded() + OPTIN_VOTE_DURATION + 2
				// TGNS.DoFor(readyPlayerClients, function(c)
				// 	if Shine:IsValidClient(c) then
				// 		if not captainsModeEnabled then
				// 			md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), "You are now opted-in to play a Captains game.")
				// 		end
				// 	end
				// end)
				TGNS.ScheduleAction(1, announceTimeRemaining)
			elseif votesAllowedUntil == math.huge and not infiniteTimeRemainingDisplayStarted then
				infiniteTimeRemainingDisplayStarted = true
				TGNS.ScheduleAction(1, announceTimeRemaining)
			end
			readyPlayerClients = readyPlayerClients or {}
			if TGNS.Has(readyPlayerClients, client) then
				updateCaptainsReadyProgress(client)
			else
				removeReadyRoomAfkToMakeRoomForNewReadyPlayerClient(client)
				local playingReadyPlayerClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyPlayerClients, c) end)
				local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
				local player = TGNS.GetPlayer(client)
				if #playingReadyPlayerClients < MAX_NON_CAPTAIN_PLAYERS + (captainsModeEnabled and (2 - #playingReadyCaptainClients) or 0) then
					table.insertunique(readyPlayerClients, client)
					TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.scoreboard.TOOLTIP_SOUND, {})
					md:ToAdminConsole(string.format("%s is opted in.", TGNS.GetClientName(client)))
					getRolesData({TGNS.GetClientSteamId(client)})
					TGNS.RemoveAllMatching(readyCaptainClients, client)
					updateCaptainsReadyProgress(client)
				else
					md:ToPlayerNotifyError(player, "Too many people have already opted in to play.")
					if #playingReadyCaptainClients < 2 then
						md:ToPlayerNotifyError(player, "There's still room for another Captain!")
					end
					local readyRoomReadyPlayerClientNames = TGNS.Select(TGNS.Where(TGNS.GetReadyRoomClients(TGNS.GetPlayerList()), function(c) return TGNS.Has(readyPlayerClients, c) end), TGNS.GetClientName)
					if #readyRoomReadyPlayerClientNames > 0 and #readyRoomReadyPlayerClientNames <= 3 then
						local namesDisplay = TGNS.Join(readyRoomReadyPlayerClientNames, ", ")
						md:ToPlayerNotifyError(player, "If any of these players are trying to give you their opt-in slot, have them join Spectate:")
						md:ToPlayerNotifyError(player, namesDisplay)
					end
				end
			end
			if captainsModeEnabled then
				if TGNS.Has(readyPlayerClients, client) then
					if not TGNS.IsGameInProgress() then
						if TGNS.PlayerAction(client, TGNS.IsPlayerReadyRoom) and not TGNS.ClientIsInGroup(client, "captainsgame_group") then
							TGNS.AddTempGroup(client, "captainsgame_group")
							md:ToAllNotifyInfo(string.format("%s wants Captains, too!", TGNS.GetClientName(client)))
						end
					end
				end
			end
		end

		local function showVoteTimingHelperMessages(message)
			if rolandHasBeenUsed then
				md:ToAllNotifyInfo(message)
			else
				md:ToAllConsole(message)
			end
		end

		local function addReadyCaptainClient(client)
			readyCaptainClients = readyCaptainClients or {}
			if not TGNS.Has(readyCaptainClients, client) then
				table.insertunique(readyCaptainClients, client)
				TGNS.RemoveAllMatching(readyPlayerClients, client)
				if #readyCaptainClients == 2 then
					showVoteTimingHelperMessages("Both captains are opted-in! Opt in to play! Press M > Captains > sh_iwantcaptains")
					momentWhenSecondCaptainOptedIn = momentWhenSecondCaptainOptedIn or TGNS.GetSecondsSinceMapLoaded()
				end
			end
			TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), Shine.Plugins.scoreboard.TOOLTIP_SOUND, {})
			md:ToAdminConsole(string.format("%s is opted in as a Captain.", TGNS.GetClientName(client)))
			getRolesData({TGNS.GetClientSteamId(client)})
			updateCaptainsReadyProgress(client)
		end

		//function swapTeamsAfterDelay(delayInSeconds)
		//	local originalPlayerTeamNumbers = {}
		//	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
		//		if TGNS.PlayerIsOnPlayingTeam(p) then
		//			originalPlayerTeamNumbers[p] = TGNS.GetPlayerTeamNumber(p)
		//		end
		//	end)
		//	TGNS.ScheduleAction(delayInSeconds, function()
		//		TGNS.DoForPairs(originalPlayerTeamNumbers, function(player, teamNumber)
		//			local otherTeamNumber = teamNumber == 1 and 2 or 1
		//			TGNS.SendToTeam(player, otherTeamNumber, true)
		//		end)
		//		md:ToAllNotifyInfo("Teams have been swapped!")
		//	end)
		//end

		function getCaptainsGameStateDescription()
			local result = ""
			if captainsGamesFinished < 2 then
				result = string.format("It's a Captains Game! Round %s %s!", captainsGamesFinished + 1, TGNS.IsGameInProgress() and "in progress" or "starting soon")
			else
				result = "Round Two of a Captains Game just finished! Captains Game over!"
			end
			return result
		end

		function Plugin:IsCaptainsModeEnabled()
			return captainsModeEnabled
		end

		function Plugin:IsClientCaptain(client)
			return Shine:IsInGroup(client, "captains_group")
		end

		function Plugin:IsOptedInAsPlayer(client)
			return TGNS.Has(readyPlayerClients, client)
		end

		function Plugin:GetNumPlayersFromGamerules( Gamerules ) -- https://github.com/Person8880/Shine/issues/597#issuecomment-287606018
			local Team1Players, _, Team1Bots = Gamerules.team1:GetNumPlayers()
			local Team2Players, _, Team2Bots = Gamerules.team2:GetNumPlayers()

			return Team1Players + Team2Players - Team1Bots - Team2Bots
		end

		function Plugin:UpdateWarmUp( Gamerules ) -- https://github.com/Person8880/Shine/issues/597#issuecomment-287606018
			if captainsModeEnabled then
				local State = Gamerules:GetGameState()
				if State ~= kGameState.WarmUp then return end

				local NumPlayers = self:GetNumPlayersFromGamerules( Gamerules )
				if NumPlayers >= Gamerules:GetWarmUpPlayerLimit() then
					-- Restore pre-314 behaviour, go to NotStarted when players exceed warm up total.
					Gamerules:SetGameState( kGameState.NotStarted )
					return false
				end
			end
		end

		function Plugin:CheckGameStart(gamerules)
			if captainsModeEnabled and not bothTeamsAreReady() then
				return false
			end
		end

		function Plugin:GetRecentCaptainsData()
			return recentCaptainsData
		end

		function Plugin:GetCaptainsNightStartHourLocalServerTime()
			return CAPTAINS_NIGHT_START_HOUR_LOCAL_SERVER_TIME
		end

		function Plugin:EndGame(gamerules, winningTeam)
			readyTeams["Marines"] = false
			readyTeams["Aliens"] = false
			gameLastEndedAt = TGNS.GetSecondsSinceMapLoaded()
			if not allPlayersWereArtificiallyForcedToReadyRoom then
				if captainsModeEnabled then
					if winningTeam == nil then
						TGNS.DoFor(captainClients, function(c)
							captainsGamesWon[c] = captainsGamesWon[c] or 0
							captainsGamesWon[c] = captainsGamesWon[c] + 1
							Shine.Plugins.scoreboard:SetTeamScoresData(c, captainsGamesWon[c])
						end)
					else
						local winningCaptainClient = TGNS.FirstOrNil(TGNS.GetTeamClients(winningTeam:GetTeamNumber()), function(c) return TGNS.Has(captainClients, c) end)
						if winningCaptainClient ~= nil then
							captainsGamesWon[winningCaptainClient] = captainsGamesWon[winningCaptainClient] or 0
							captainsGamesWon[winningCaptainClient] = captainsGamesWon[winningCaptainClient] + 1
							Shine.Plugins.scoreboard:SetTeamScoresData(winningCaptainClient, captainsGamesWon[winningCaptainClient])
						end
					end
					gameStarted = false
					captainsGamesFinished = captainsGamesFinished + 1
					TGNS.DoForPairs(captainTeamNumbers, function(client, teamNumber)
						captainTeamNumbers[client] = captainTeamNumbers[client] == 1 and 2 or 1
					end)
					local messageDisplayer
					if captainsGamesFinished < 2 then
						setTimeAtWhichToForceRoundStart()
						messageDisplayer = function()
							TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c)
								md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), string.format("Time for Round 2! Switch to %s!", TGNS.GetOtherPlayingTeamName(TGNS.GetClientTeamName(c))))
							end)
							TGNS.ScheduleAction(10, function()
								local nominationsMd = TGNSMessageDisplayer.Create("MAPCYCLE")
								nominationsMd:ToAllNotifyInfo("Put in nominations now for the next map!")
							end)
						end
					else
						local updateRecentCaptainsData = function()
							recentCaptainsData = Shine.LoadJSONFile(recentCaptainsTempfilePath) or {}
							TGNS.DoFor(readyCaptainClients, function(c)
								if Shine:IsValidClient(c) then
									table.insert(recentCaptainsData, {steamId=TGNS.GetClientSteamId(c),gameEnded=TGNS.GetSecondsSinceEpoch()})
								end
							end)
							Shine.SaveJSONFile(recentCaptainsData, recentCaptainsTempfilePath)
						end
						updateRecentCaptainsData()

						TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
							disableCaptainsMode()
							Shine.Plugins.mapvote:StartVote(true)
						end)
						messageDisplayer = function()
							md:ToAllNotifyInfo("Both rounds of Captains Game finished! Thanks for playing! -- TacticalGamer.com")
						end
					end
					TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM - 4, function()
						messageDisplayer()
					end)
					TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 4, function()
						TGNS.DoFor(TGNS.GetPlayers(TGNS.GetStrangersClients(TGNS.GetPlayerList())), function(p)
							md:ToPlayerNotifyInfo(p, "If you enjoy playing here, be sure to bookmark this TacticalGamer.com server!")
						end)
					end)
				else
					TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM + 65, function()
						if Shine.Plugins.mapvote:VoteStarted() then
							md:ToAllNotifyInfo("Join us Friday nights for Captains Games! Passworded, scrim-style gameplay")
							md:ToAllNotifyInfo("from ~8PM Central 'til. Read more in the TGNS Forums: http://rr.tacticalgamer.com/Community")
						end
					end)
					readyCaptainClients = {}
					readyPlayerClients = {}
				end
			end
		end

		local function displayPlansToAll()
			TGNS.DoFor(TGNS.GetPlayerList(), function(targetPlayer)
				local targetPlayerIsReadyRoom = TGNS.IsPlayerReadyRoom(targetPlayer)
				local targetPlayerIsSpectator = TGNS.IsPlayerSpectator(targetPlayer)
				TGNS.DoFor(TGNS.GetPlayerList(), function(sourcePlayer)
					local planToSend = ""
					local sourceClient = TGNS.GetClient(sourcePlayer)
					local playersAreTeammates = TGNS.PlayersAreTeammates(targetPlayer, sourcePlayer)
					if sourceClient and (playersAreTeammates or targetPlayerIsSpectator) and not targetPlayerIsReadyRoom then
						planToSend = plans[sourceClient] or ""
					end
					TGNS.SendNetworkMessageToPlayer(targetPlayer, Shine.Plugins.scoreboard.PLAYER_NOTE, {c=sourcePlayer:GetClientIndex(), n=TGNS.Truncate(planToSend, PLAN_DISPLAY_LENGTH)})
				end)
			end)
		end

		function Plugin:CreateCommands()

			local resetTimerCommand = self:BindCommand("sh_resetcaptainstimer", nil, function(client)
				if timeAtWhichToForceRoundStart and timeAtWhichToForceRoundStart > 0 then
					timeAtWhichToForceRoundStart = TGNS.GetSecondsSinceMapLoaded() + SECONDS_ALLOWED_BEFORE_FORCE_ROUND_START + 30 + (captainsGamesFinished == 0 and 60 or 0)
					md:ToClientConsole(client, "Captains Timer reset.")
				else
					md:ToClientConsole(client, "ERROR: No timer to reset.")
				end
			end)
			resetTimerCommand:Help("Reset the Captains pre-game countdown timer.")

			local captainsOptInOneRrCommand = self:BindCommand("sh_captainsforceone", nil, function(client)
				if captainsModeEnabled then
					md:ToClientConsole(client, "Captains mode is already enabled. No action taken by sh_captainsforceone.")
				else
					local optInClient = TGNS.FirstOrNil(TGNS.GetReadyRoomClients(TGNS.GetPlayerList()), function(c) return not TGNS.Has(readyPlayerClients, c) and not TGNS.Has(readyCaptainClients, c) end)
					if optInClient then
						if #readyCaptainClients < 2 then
							addReadyCaptainClient(optInClient)
							md:ToClientConsole(client, string.format("%s opted in as Captain.", TGNS.GetClientName(optInClient)))
						else
							addReadyPlayerClient(optInClient)
							md:ToClientConsole(client, string.format("%s opted in as Player.", TGNS.GetClientName(optInClient)))
						end
					else
						md:ToClientConsole(client, "Unable to find Ready Room player eligible for opt-in.")
					end
				end
			end)
			captainsOptInOneRrCommand:Help("Set Captains mod into DEV testing mode.")

			local captainsCommand = self:BindCommand("sh_captains", "captains", function(client, captain1Predicate, captain2Predicate)
				local player = TGNS.GetPlayer(client)
				if captainsModeEnabled then
					md:ToPlayerNotifyError(player, "Captains Game is already active.")
				else
					if not TGNS.IsGameInProgress() then
						if Shine.Plugins.mapvote:VoteStarted() then
							md:ToPlayerNotifyError(player, "Captains Game cannot be activated during a map vote.")
						else
							local playerName = TGNS.GetPlayerName(player)
							if captain1Predicate == nil or captain1Predicate == "" then
								md:ToPlayerNotifyError(player, "You must specify a first Captain.")
							elseif captain2Predicate == nil or captain2Predicate == "" then
								md:ToPlayerNotifyError(player, "You must specify a second Captain.")
							else
								local captain1Player = TGNS.GetPlayerMatching(captain1Predicate, nil)
								local captain2Player = TGNS.GetPlayerMatching(captain2Predicate, nil)
								if captain1Player ~= nil then
									if captain2Player ~= nil then
										local captain1Client = TGNS.GetClient(captain1Player)
										local captain2Client = TGNS.GetClient(captain2Player)
										enableCaptainsMode(TGNS.GetClientName(client), captain1Client, captain2Client)
									else
										md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", captain2Predicate))
									end
								else
									md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", captain1Predicate))
								end
							end
						end
					else
						md:ToPlayerNotifyError(player, "Captains Game cannot be activated during a game.")
					end
				end
			end)
			captainsCommand:AddParam{ Type = "string", Optional = true }
			captainsCommand:AddParam{ Type = "string", Optional = true }
			captainsCommand:Help("<captain1player> <captain2player> Designate two captains and activate Captains Game.")

			local planCommand = self:BindCommand("sh_plan", {"plan", "PLAN", "Plan"}, function(client, plan)
				local player = TGNS.GetPlayer(client)
				if TGNS.PlayerIsOnPlayingTeam(player) then
					if not TGNS.IsGameInProgress() then
						if TGNS.HasNonEmptyValue(plan) then
							plans[client] = plan
							displayPlansToAll()
						else
							md:ToPlayerNotifyInfo(player, "When !plan-ing, describe your plan (gorge, comm, lerk, etc).")
							md:ToPlayerNotifyInfo(player, "For example, put 'gorge' on your scoreboard row: !plan gorge")
						end
					else
						md:ToPlayerNotifyError(player, "Planning notes are not displayed during gameplay.")
					end
				else
					md:ToPlayerNotifyError(player, "You must be on a team to plan.")
				end
			end, true)
			planCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
			planCommand:Help("<plan> Announce your Captains Game plan.")

			local pickCommand = self:BindCommand( "sh_pick", "pick", function(client, playerPredicate, teamNumberCandidate)
				local player = TGNS.GetPlayer(client)
				if TGNS.IsGameInProgress() then
					md:ToPlayerNotifyError(player, "Players cannot be picked during a game.")
				elseif not captainsModeEnabled then
					md:ToPlayerNotifyError(player, "Captains Game not enabled. Cannot pick a player.")
				elseif not TGNS.Has(captainClients, client) then
					md:ToPlayerNotifyError(player, "You must be a Captain to pick a player.")
				elseif playerPredicate == nil or playerPredicate == "" then
					md:ToPlayerNotifyError(player, "You must specify a player.")
				else
					local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
					if targetPlayer then
						local targetClient = TGNS.GetClient(targetPlayer)
						if TGNS.Has(captainClients, targetClient) then
							md:ToPlayerNotifyError(player, string.format("%s is a Captain and cannot be picked.", TGNS.GetClientName(targetClient)))
						elseif client == targetClient then
							md:ToPlayerNotifyError(player, "You can pick your friends, and you can pick")
							md:ToPlayerNotifyError(player, "your nose, but you can't pick yourself...")
						else
							setAsPickedIfSpace(targetPlayer, targetClient)
							if TGNS.Has(readyPlayerClients, targetClient) then
								local teamNumber = tonumber(teamNumberCandidate)
								if TGNS.IsNumberWithNonZeroPositiveValue(teamNumber) and TGNS.IsGameplayTeamNumber(teamNumber) then
									md:ToAllNotifyInfo(string.format("%s chose %s for %s.", TGNS.GetClientName(client), TGNS.GetPlayerName(targetPlayer), TGNS.GetTeamName(teamNumber)))
									TGNS.SendToTeam(targetPlayer, teamNumber, true)
								else
									md:ToPlayerNotifyError(player, string.format("'%s' is not recognizable as Marines or Aliens.", teamNumberCandidate))
								end
							else
								md:ToAllNotifyError(string.format("%s did not sh_iwantcaptains and cannot be picked.", TGNS.GetPlayerName(targetPlayer)))
							end
						end
					else
						md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
					end
				end
			end)
			pickCommand:AddParam{ Type = "string", Optional = true }
			pickCommand:AddParam{ Type = "string", Optional = true }
			pickCommand:Help( "<player> Pick the given player for your Captains Game team." )

			local captainsDebugCommand = self:BindCommand( "sh_captainsdebug", nil, function(client)
				local clientList = TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.GetIsClientVirtual(c) end)
				local captainsClients = TGNS.Where(clientList, function(c) return TGNS.Has(readyCaptainClients, c) end)
				local optedInClients = TGNS.Where(clientList, function(c) return TGNS.Has(readyPlayerClients, c) end)
				local notOptedInClients = TGNS.Where(clientList, function(c) return not TGNS.Has(captainsClients, c) and not TGNS.Has(optedInClients, c) end)
				TGNS.SortDescending(captainsClients, TGNS.GetClientName)
				TGNS.SortDescending(optedInClients, TGNS.GetClientName)
				TGNS.SortDescending(notOptedInClients, TGNS.GetClientName)

				md:ToClientConsole(client, "")
				md:ToClientConsole(client, "--------------------------------------------------------------")
				md:ToClientConsole(client, "--------------------------------------------------------------")
				md:ToClientConsole(client, string.format(" CAPTAINS DEBUG (%s)", TGNS.GetCurrentMapName()))
				md:ToClientConsole(client, "--------------------------------------------------------------")
				md:ToClientConsole(client, string.format("Captains (%s):", #captainsClients))
				TGNS.DoFor(captainsClients, function(c)
					md:ToClientConsole(client, string.format("%s (%s)", TGNS.GetClientName(c), TGNS.GetClientTeamName(c)))
				end)
				md:ToClientConsole(client, "--------------------------------------------------------------")
				md:ToClientConsole(client, string.format("Opted-In (%s):", #optedInClients))
				TGNS.DoFor(optedInClients, function(c)
					md:ToClientConsole(client, string.format("%s%s (%s)", TGNS.IsClientAFK(c) and "!" or "", TGNS.GetClientName(c), TGNS.GetClientTeamName(c)))
				end)
				md:ToClientConsole(client, "--------------------------------------------------------------")
				md:ToClientConsole(client, string.format("Not Opted-In (%s):", #notOptedInClients))
				TGNS.DoFor(notOptedInClients, function(c)
					md:ToClientConsole(client, string.format("%s%s (%s)", TGNS.IsClientAFK(c) and "!" or "", TGNS.GetClientName(c), TGNS.GetClientTeamName(c)))
				end)
				md:ToClientConsole(client, "--------------------------------------------------------------")
				md:ToClientConsole(client, "--------------------------------------------------------------")
				md:ToClientConsole(client, "")
			end)
			captainsDebugCommand:Help( "Show Captains opt-in status..." )

			local enableCaptainCommand = self:BindCommand( "sh_maycaptain", "maycaptain", function(client, playerPredicate)
				local player = TGNS.GetPlayer(client)
				local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
				if targetPlayer then
					local targetClient = TGNS.GetClient(targetPlayer)
					md:ToAdminNotifyInfo(string.format("%s has allowed %s to use sh_iwillcaptain.", TGNS.GetClientName(client), TGNS.GetClientName(targetClient)))
					md:ToPlayerNotifyInfo(targetPlayer, string.format("%s has allowed you to use sh_iwillcaptain.", TGNS.GetClientName(client)))
					TGNS.AddTempGroup(targetClient, "iwillcaptaincommand_group")
				else
					md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
				end
			end)
			enableCaptainCommand:AddParam{ Type = "string", Optional = true, TakeRestOfLine = true }
			enableCaptainCommand:Help( "<player> Grant sh_iwillcaptain usage to a player." )


			local willCaptainsCommand = self:BindCommand("sh_iwillcaptain", "iwillcaptain", function(client)
				local player = TGNS.GetPlayer(client)
				if Shine.GetGamemode() == "ns2" then
					if captainsModeEnabled then
						md:ToPlayerNotifyError(player, "Captains Game is already active.")
					elseif #getPlayingClients() < MIN_CAPTAINS_PLAYERS and not rolandHasBeenUsed then
						md:ToPlayerNotifyError(player, string.format("The combined player count of both teams must be %s+ before you can offer to Captain.", MIN_CAPTAINS_PLAYERS))
					elseif mayVoteYet ~= true and not TGNS.IsGameInProgress() then
						md:ToPlayerNotifyError(player, "Captains voting is restricted at the moment. Console for details.")
						md:ToClientConsole(client, "Captains voting is restricted for a minute or two after a mapchange to")
						md:ToClientConsole(client, "allow all players to connect and be able to fully participate in votes.")
						md:ToClientConsole(client, "Admins can also restrict votes manually, but that typically only happens during")
						md:ToClientConsole(client, "our passworded Captains Night events on Friday nights (TGNS forums for details).")
					elseif TGNS.IsPlayerSpectator(player) then
						md:ToPlayerNotifyError(player, "You may not use this command as a spectator.")
					elseif Shine.Plugins.mapvote:VoteStarted() then
						md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
					elseif votesAllowedUntil ~= nil and votesAllowedUntil < TGNS.GetSecondsSinceMapLoaded() then
						md:ToPlayerNotifyError(player, "This map's Captains vote failed to pass.")
					elseif TGNS.IsGameInProgress() and TGNS.GetCurrentGameDurationInSeconds() > 15 and votesAllowedUntil ~= math.huge then
						md:ToPlayerNotifyError(player, "Game duration > 0:15. It's too late this game to opt-in as a Captain.")
					else
						local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
						if #playingReadyCaptainClients < 2 or TGNS.Has(readyCaptainClients, client) then
							addReadyCaptainClient(client)
						else
							md:ToPlayerNotifyError(player, "Two players have already opted in to be Captain.")
							local playingReadyPlayerClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyPlayerClients, c) end)
							if #playingReadyPlayerClients < MAX_NON_CAPTAIN_PLAYERS then
								md:ToPlayerNotifyError(player, "Opting you in as non-Captain instead...")
								addReadyPlayerClient(client)
							end
						end
					end
				else
					md:ToPlayerNotifyError(player, "Not supported in this game mode.")
				end
			end)
			willCaptainsCommand:Help("Tell you're willing to lead a team in a Captains Game.")

			local wantCaptainsCommand = self:BindCommand("sh_iwantcaptains", "iwantcaptains", function(client)
				local player = TGNS.GetPlayer(client)
				local captainsModeWasEnabledJustSecondsAgo = momentWhenCaptainsModeWasEnabled ~= nil and momentWhenCaptainsModeWasEnabled > TGNS.GetSecondsSinceMapLoaded() - RESTRICTED_OPTIN_DURATION_IN_SECONDS
				local steamId = TGNS.GetClientSteamId(client)
				local clientWasNonCaptainPlayerInRecentCaptainsGame = TGNS.Has(recentPlayerPlayerIds, steamId) and not TGNS.Has(recentCaptainPlayerIds, steamId)
				local clientLeftTeamJustSecondsAgo = momentsWhenLastLeftPlayingTeam[client] ~= nil and momentsWhenLastLeftPlayingTeam[client] >= TGNS.GetSecondsSinceMapLoaded() - RESTRICTED_OPTIN_DURATION_IN_SECONDS
				local optInEarly = function(optingInClient, failureMessage)
					local optingInSteamId = TGNS.GetClientSteamId(optingInClient)
					local isSm = TGNS.IsClientSM(optingInClient)
					local isRecentCaptain = TGNS.Has(recentCaptainPlayerIds, optingInSteamId)
					local optingInClientDidNotPlayInRecentCaptainsGame = not (TGNS.Has(recentPlayerPlayerIds, optingInSteamId) or isRecentCaptain)
					if isSm or isRecentCaptain or optingInClientDidNotPlayInRecentCaptainsGame then
						readyPlayerClients = readyPlayerClients or {}
						removeReadyRoomAfkToMakeRoomForNewReadyPlayerClient(optingInClient)
						local playingReadyPlayerClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyPlayerClients, c) end)
						if #playingReadyPlayerClients < MAX_NON_CAPTAIN_PLAYERS and not TGNS.Has(readyPlayerClients, optingInClient) then
							table.insertunique(readyPlayerClients, optingInClient)
							TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(optingInClient), Shine.Plugins.scoreboard.TOOLTIP_SOUND, {})
							md:ToAdminConsole(string.format("%s opted in early successfully.", TGNS.GetClientName(optingInClient)))
							getRolesData({TGNS.GetClientSteamId(optingInClient)})
						end
						if TGNS.Has(readyPlayerClients, optingInClient) then
							md:ToPlayerNotifyInfo(TGNS.GetPlayer(optingInClient), "You will be automatically opted-in when votes are allowed.")
						else
							md:ToPlayerNotifyError(TGNS.GetPlayer(optingInClient), "Early opt-ins are already FULL! :( -- Ask if anyone is willing to sit out?")
						end
					else
						md:ToPlayerNotifyError(TGNS.GetPlayer(optingInClient), failureMessage)
					end
				end

				// if TGNS.GetSecondsSinceMapLoaded() - (lastOptInAttemptWhen[client] or 0) < OPT_IN_THROTTLE_IN_SECONDS then
				// 	md:ToPlayerNotifyError(player, string.format("Every opt-in attempt (including this one) resets a %s-second cooldown.", OPT_IN_THROTTLE_IN_SECONDS))
				if TGNS.IsPlayerSpectator(player) then
					md:ToPlayerNotifyError(player, "You may not use this command as a spectator.")
				elseif (not rolandHasBeenUsed) and (not TGNS.PlayerIsOnPlayingTeam(player)) and not captainsModeEnabled then
					md:ToPlayerNotifyError(player, "Opting in is not allowed from the Ready Room. Join a team to opt-in to Captains.")
				elseif (not rolandHasBeenUsed) and (not TGNS.PlayerIsOnPlayingTeam(player)) and captainsModeEnabled and captainsModeWasEnabledJustSecondsAgo and not clientLeftTeamJustSecondsAgo then
					md:ToPlayerNotifyError(player, string.format("Wait %s seconds to let those who were on a team opt-in.", RESTRICTED_OPTIN_DURATION_IN_SECONDS))
				elseif mayVoteYet ~= true and votesAllowedUntil ~= math.huge and not TGNS.IsGameInProgress() then
					optInEarly(client, "Captains voting is restricted now. SMs, recent Captains, and players not active in the last Captains game may opt-in early during this time.")
				elseif Shine.Plugins.mapvote:VoteStarted() then
					md:ToPlayerNotifyError(player, "Captains Game requests cannot be managed during a map vote.")
				elseif not captainsModeEnabled and votesAllowedUntil ~= nil and votesAllowedUntil < TGNS.GetSecondsSinceMapLoaded() then
					md:ToPlayerNotifyError(player, "This map's Captains vote failed to pass.")
				elseif TGNS.IsGameInProgress() and TGNS.GetCurrentGameDurationInSeconds() > 30 and (readyPlayerClients == nil or #readyPlayerClients == 0) and votesAllowedUntil ~= math.huge then
					md:ToPlayerNotifyError(player, "Game duration > 0:30. It's too late to start opting in players.")
				else
					local playingReadyCaptainClients = TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end)
					if TGNS.Has(playingReadyCaptainClients, client) then
						md:ToPlayerNotifyError(player, "You may not undo your opt-in to be a Captain.")
					else
						if not captainsModeEnabled and #playingReadyCaptainClients < 2 then
							optInEarly(client, string.format("Two captains (%s so far) must opt-in first. SMs, recent Captains, and players not active in the last Captains game may opt-in early during this time.", #playingReadyCaptainClients))
						else
							if (not TGNS.IsClientSM(client)) and clientWasNonCaptainPlayerInRecentCaptainsGame and (momentWhenSecondCaptainOptedIn == nil or momentWhenSecondCaptainOptedIn > TGNS.GetSecondsSinceMapLoaded() - RESTRICTED_OPTIN_DURATION_IN_SECONDS) then
								md:ToPlayerNotifyError(player, "Wait for others to opt-in (console for details). SMs, recent Captains, and players not active in the last Captains game may opt-in early during this time.")
								md:ToClientConsole(client, "Details: You were a non-Captain player in this server's most recent Captains round.")
								md:ToClientConsole(client, string.format("Details: The first %s seconds of each opt-in window are reserved for SMs, recent", RESTRICTED_OPTIN_DURATION_IN_SECONDS))
								md:ToClientConsole(client, "Details: Captains, and those who didn't play in the most recent Captains game.")
							else
								addReadyPlayerClient(client)
							end
						end
					end
				end
				// lastOptInAttemptWhen[client] = TGNS.GetSecondsSinceMapLoaded()
				// if not TGNS.IsClientAdmin(client) and not TGNS.Has(readyPlayerClients, client) then
				// 	TGNS.ScheduleAction(3.5, function()
				// 		if Shine:IsValidClient(client) then
				// 			TGNS.AddTempGroup(client, "iwantcaptainscommand_group")
				// 			md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "... sh_iwantcaptains restored.")
				// 		end
				// 	end)
				// 	TGNS.RemoveTempGroup(client, "iwantcaptainscommand_group")
				// 	md:ToPlayerNotifyInfo(player, "sh_iwantcaptains 4-second cooldown started...")
				// end
			end)
			wantCaptainsCommand:Help(string.format("Tell the server you want to play a Captains Game (cooldown: %s seconds).", OPT_IN_THROTTLE_IN_SECONDS))

			local swapCaptainsCommand = self:BindCommand( "sh_swapcaptains", nil, function(client)
				local errorMessage
				if captainClients and #captainClients == 2 then
					local matchingCaptainClients = TGNS.GetClientList(function(c) return c == getPlayerChoiceCaptainClient(captainClients) or c == getTeamChoiceCaptainClient(captainClients) end)
					if #matchingCaptainClients == 2 then
						TGNS.RemoveTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
						swapCaptains()
						TGNS.AddTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
						md:ToClientConsole(client, string.format("Clients swapped. %s is now Player Choice. %s is now Team Choice.", TGNS.GetClientName(getPlayerChoiceCaptainClient(captainClients)), TGNS.GetClientName(getTeamChoiceCaptainClient(captainClients))))
					else
						errorMessage = "Unable to find two Captain clients among connected clients."
					end
				else
					errorMessage = "There are fewer than two Captains presently designated."
				end
				if errorMessage then
					md:ToClientConsole(client, string.format("ERROR: %s", errorMessage))
				end
			end)
			swapCaptainsCommand:Help( "Swap roles between the two Captains (Player Choice <-> Team Choice)." )

			local setSpawnsCommand = self:BindCommand("sh_setspawns", nil, function(client, spawnSelectionIndex)
				spawnSelectionIndex = tonumber(spawnSelectionIndex)
				local player = TGNS.GetPlayer(client)
				local ssoData = Shine.Plugins.spawnselectionoverrides:GetCurrentMapSpawnSelectionOverridesData()
				local errorMessage
				local teamChoiceCaptainClient = #captainClients > 0 and getTeamChoiceCaptainClient(captainClients) or nil
				local captainsUsage = captainsModeEnabled and teamChoiceCaptainClient == client or TGNS.IsClientAdmin(client)
				local smUsage = not captainsModeEnabled and TGNS.IsClientSM(client)
				Shared.Message("smUsage: " .. tostring(smUsage))
				if captainsUsage or smUsage then
					if not Shine.Plugins.mapvote:VoteStarted() then
						local validCaptainsUsage = captainsUsage and (captainsGamesFinished == 0 and not TGNS.IsGameInProgress())
						local gameJustEnded = false
						if gameLastEndedAt ~= nil then
							local secondsSinceGameEnded = TGNS.GetSecondsSinceMapLoaded() - gameLastEndedAt
							gameJustEnded = secondsSinceGameEnded > TGNS.ENDGAME_TIME_TO_READYROOM and secondsSinceGameEnded < TGNS.ENDGAME_TIME_TO_READYROOM + 10
						end
						local validSmUsage = smUsage and TGNS.IsGameWaitingToStart() and gameJustEnded and nextGameSpawnLocationsSummary == nil
						if validCaptainsUsage or validSmUsage then
							if spawnSelectionIndex then
								if spawnSelectionIndex >= 1 and spawnSelectionIndex <= #ssoData then
									local spawnSelectionOverride = {}
									table.insert(spawnSelectionOverride, ssoData[spawnSelectionIndex].spawnSelectionOverride)
									Shine.Plugins.spawnselectionoverrides:ForceOverrides(spawnSelectionOverride)
									setSpawnsSummaryText = ssoData[spawnSelectionIndex].summaryTextLineDelimited
									nextGameSpawnLocationsSummary = ssoData[spawnSelectionIndex].summaryText
									local clientName = TGNS.GetClientName(client)
									local clientIsCaptain = (#captainClients > 0 and getPlayerChoiceCaptainClient(captainClients) == client) or (#captainClients > 1 and getTeamChoiceCaptainClient(captainClients) == client)
									if clientIsCaptain and TGNS.ClientIsOnPlayingTeam(client) then
										local clientTeamNumber = TGNS.GetClientTeamNumber(client)
										md:ToTeamNotifyInfo(clientTeamNumber, string.format("%s (Captain) has set first-round spawns: %s", clientName, ssoData[spawnSelectionIndex].summaryText))
										local steamId = TGNS.GetClientSteamId(client)
										if not hasEarnedSetSpawnsKarma[steamId] then
											TGNS.Karma(steamId, "SetSpawns")
											hasEarnedSetSpawnsKarma[steamId] = true
										end
									elseif smUsage then
										Shared.Message("smUsage...")
										local notifyAll
										notifyAll = function()
											if nextGameSpawnLocationsSummary then
												local tgnsMd = TGNSMessageDisplayer.Create()
												tgnsMd:ToAllNotifyInfo(string.format("Next game spawns: %s (set by: %s)", nextGameSpawnLocationsSummary, clientName))
												tgnsMd:ToAllNotifyInfo(string.format("Upcoming game spawns: %s (set by: %s)", nextGameSpawnLocationsSummary, clientName))
												TGNS.ScheduleAction(15, notifyAll)
											end
										end
										notifyAll()
									else
										md:ToPlayerNotifyInfo(player, string.format("Spawn set: %s", ssoData[spawnSelectionIndex].summaryText))
									end
								else
									errorMessage = string.format("'%s' is not a valid spawn selection override index number.", spawnSelectionIndex)
								end
							else
								errorMessage = "You must specify a spawn selection override index number."
							end
						else
							errorMessage = captainsModeEnabled and "You may set spawn locations only before the first Captains round." or "SMs may set spawn locations right after a game (only one -- first wins)."
						end
					else
						errorMessage = "Mapvote started. Try again next map."
					end
				else
					errorMessage = string.format("%s may set spawn locations. No spawns have been set.", captainsModeEnabled and "Team Choice Captain" or "Supporting Members")
				end
				if errorMessage then
					md:ToPlayerNotifyError(player, errorMessage)
					md:ToClientConsole(client, string.format("ERROR: %s", errorMessage))
					md:ToClientConsole(client, "usage: sh_setspawns <spawn selection override index number>")
					md:ToClientConsole(client, " e.g.: sh_setspawns 1")
					if #ssoData > 0 then
						md:ToClientConsole(client, "Available spawn pair options:")
						TGNS.DoFor(ssoData, function(d)
							md:ToClientConsole(client, string.format("%s. %s", d.spawnSelectionIndex, d.summaryText))
						end)
					else
						md:ToPlayerNotifyError(player, "There are no spawn selection overrides configured for this map.")
					end
				end
			end, true)
			setSpawnsCommand:AddParam{ Type = "string", Optional = true }
			setSpawnsCommand:Help("Set spawns for the next game. Execute without parameters for more help.")

			local voteAllowCommand = self:BindCommand("sh_allowcaptainsvotes", nil, function(client)
				mayVoteYet = true
				votesAllowedUntil = math.huge
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Captains vote time restriction lifted for this map.")
				if momentWhenSecondCaptainOptedIn == nil then
					showVoteTimingHelperMessages("Both players selected as Captains for this map should opt-in now.")
				end
			end)
			voteAllowCommand:Help("Lift time restriction on Captains votes.")

			local voteRestrictCommand = self:BindCommand("sh_roland", nil, function(client)
				mayVoteYet = false
				votesAllowedUntil = nil
				rolandHasBeenUsed = true
				local player = TGNS.GetPlayer(client)

				TGNS.DoFor(TGNS.GetPlayerList(), function(p)
					TGNS.SendToTeam(p, kSpectatorIndex, true)
				end)
				TGNS.ScheduleAction(0.5, function()
					TGNS.DoFor(TGNS.GetPlayerList(), function(p)
						md:ToPlayerNotifyInfo(p, "Captains will resume soon.")
						md:ToPlayerNotifyInfo(p, "SMs, recent Captains, and players not active in the last Captains game: return to Ready Room and opt-in early now.")
					end)
				end)
				automaticVoteAllowAction = function() end
				local getRolesDataForAllClients = function() getRolesData(TGNS.Select(TGNS.GetClientList(), TGNS.GetClientSteamId)) end
				TGNS.ScheduleAction(0, getRolesDataForAllClients)
				TGNS.ScheduleAction(10, getRolesDataForAllClients)
			end)
			voteRestrictCommand:Help("Disallow Captains votes.")

		end

		function Plugin:PlayerSay(client, networkMessage)
			local shouldSuppressChatMessageDisplay = false
			if captainsModeEnabled and not (TGNS.IsGameInProgress() or TGNS.IsGameInCountdown()) then
				local player = TGNS.GetPlayer(client)
				local playerTeamName = TGNS.GetPlayerTeamName(player)
				if TGNS.PlayerIsOnPlayingTeam(player) then
					local teamsAreSufficientlyBalanced = math.abs(#TGNS.GetMarineClients() - #TGNS.GetAlienClients()) <= 1
					local message = StringTrim(networkMessage.message)
					if TGNS.Has({"ready", "unready"}, message) then
						if TGNS.IsGameInProgress() then
							TGNS.ScheduleAction(0, function() md:ToAllNotifyInfo("Captains may ready/unready only during the pregame.") end)
						else
							local nameOfOtherPersonOnTeamWhoIsCaptain = ""
							TGNS.DoFor(TGNS.GetTeamClients(TGNS.GetPlayerTeamNumber(player), TGNS.GetPlayerList()), function(c)
								if TGNS.Has(captainClients, c) and client ~= c then
									nameOfOtherPersonOnTeamWhoIsCaptain = TGNS.GetClientName(c)
								end
							end)
							if TGNS.HasNonEmptyValue(nameOfOtherPersonOnTeamWhoIsCaptain) then
								TGNS.ScheduleAction(0, function() md:ToPlayerNotifyError(TGNS.GetPlayer(client), string.format("%s is Captain and should ready or unready.", nameOfOtherPersonOnTeamWhoIsCaptain)) end)
								shouldSuppressChatMessageDisplay = true
							else
								if message == "ready" then
									shouldSuppressChatMessageDisplay = readyTeams[playerTeamName]
									if teamsAreSufficientlyBalanced then
										local readyTeamName = TGNS.GetPlayerTeamName(TGNS.GetPlayer(client))
										local notificationMessage = string.format("%s has readied the %s!", TGNS.GetClientName(client), readyTeamName)
										if not readyTeams[playerTeamName] then
											local forceRoundStartTimeSecondsToAllowRemaining = 60
											local bufferTimeInSeconds = 5
											if timeAtWhichToForceRoundStart - TGNS.GetSecondsSinceMapLoaded() > forceRoundStartTimeSecondsToAllowRemaining + bufferTimeInSeconds then
												timeAtWhichToForceRoundStart = TGNS.GetSecondsSinceMapLoaded() + forceRoundStartTimeSecondsToAllowRemaining
												notificationMessage = string.format("%s Timer reduced! Plan fast, %s!", notificationMessage, TGNS.GetOtherPlayingTeamName(readyTeamName))
											end
										end
										TGNS.ScheduleAction(0, function() md:ToAllNotifyInfo(notificationMessage) end)
										readyTeams[playerTeamName] = true
									else
										TGNS.ScheduleAction(0, function() md:ToPlayerNotifyError(TGNS.GetPlayer(client), "Ready halted: Team counts must match (or be off by only one) to play.") end)
									end
								elseif message == "unready" then
									shouldSuppressChatMessageDisplay = not readyTeams[playerTeamName]
									if gameStarted then
										shouldSuppressChatMessageDisplay = true
										TGNS.ScheduleAction(0, function() md:ToPlayerNotifyError(TGNS.GetPlayer(client), "UN-ready not allowed. Game is starting.") end)
									else
										if readyTeams[playerTeamName] then
											if TGNS.Has(captainClients, client) then
												readyTeams[playerTeamName] = false
												TGNS.ScheduleAction(0, function() md:ToAllNotifyInfo(string.format("%s has UN-readied the %s!", TGNS.GetClientName(client), TGNS.GetPlayerTeamName(TGNS.GetPlayer(client)))) end)
											else
												TGNS.ScheduleAction(0, function() md:ToPlayerNotifyError(TGNS.GetPlayer(client), "Only captains may unready. Team remains ready.") end)
											end
										else
											TGNS.ScheduleAction(0, function() md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Team is not ready.") end)
										end
									end
								end
							end
							if bothTeamsAreReady() then
								TGNS.ScheduleAction(5, function()
									if bothTeamsAreReady() and not gameStarted then
										gameStarted = true
										md:ToAllNotifyInfo(string.format("Both teams are ready! Round %s of 2 starts now!", captainsGamesFinished + 1))
										startGame()
									end
								end)
								if not gameStarted then
									TGNS.ScheduleAction(0, function() md:ToAllNotifyInfo("Are both teams ready? Captains: \"unready\" or prepare to play!") end)
								end
							end
						end
					end
				end
			end
			if shouldSuppressChatMessageDisplay then
				return ""
			end
		end

		function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
			local cancel = false
			if not (force or shineForce) then
				if captainsModeEnabled then
				    local client = TGNS.GetClient(player)
				    if TGNS.IsGameplayTeamNumber(newTeamNumber) then
				    	if TGNS.IsGameInProgress() then
							addReadyPlayerClient(client)
				    	end
				    	if TGNS.Has(readyPlayerClients, client) or TGNS.Has(readyCaptainClients, client) then
							if whenToAllowTeamJoins > TGNS.GetSecondsSinceMapLoaded() then
								md:ToPlayerNotifyError(player, "Captains Game! Stay in the Ready Room and listen for instruction.")
								cancel = true
							end
				    	else
				    		md:ToPlayerNotifyError(player, "Only opted-in players may join teams during Captains Games.")
				    		TGNS.RespawnPlayer(player)
				    		cancel = true
				    	end
				    end
				    local serverIsUpdatingToReadyRoom = Shine.Plugins.updatetoreadyroomhelper and Shine.Plugins.updatetoreadyroomhelper:IsServerUpdatingToReadyRoom()
				    if serverIsUpdatingToReadyRoom and captainsGamesFinished == 1 then
				    	if TGNS.IsPlayerSpectator(player) then
				    		cancel = true
				    	elseif TGNS.PlayerIsOnPlayingTeam(player) then
				    		local otherTeamNumber = TGNS.GetOtherPlayingTeamNumber(TGNS.GetPlayerTeamNumber(player))
				    		return true, otherTeamNumber
				    	end
				    end
				end
				if cancel then
					return false
				end
			end
		end

		function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
			local client = TGNS.GetClient(player)
			TGNS.RemoveTempGroup(client, "captainsgame_group")
		    if TGNS.IsPlayerReadyRoom(player) then
		    	if TGNS.Has(readyPlayerClients, client) then
		    		if captainsModeEnabled then
		    			TGNS.AddTempGroup(client, "captainsgame_group")
		    		elseif not rolandHasBeenUsed then
		    			TGNS.RemoveAllMatching(readyPlayerClients, client)
		    			md:ToPlayerNotifyInfo(player, "Leaving the team has removed your Captains opt-in.")
		    			md:ToAdminConsole(string.format("%s was opted out upon leaving %s.", TGNS.GetClientName(client), TGNS.GetTeamName(oldTeamNumber)))
		    		end
		    	end
			elseif newTeamNumber == kSpectatorIndex then
				if TGNS.Has(readyPlayerClients, client) then
					TGNS.RemoveAllMatching(readyPlayerClients, client)
					md:ToPlayerNotifyInfo(player, "Joining Spectator has removed your Captains opt-in.")
					md:ToAdminConsole(string.format("%s was opted out upon joining Spectate.", TGNS.GetClientName(client)))
				end
				if captainsModeEnabled then
					md:ToPlayerNotifyInfo(player, getCaptainsGameStateDescription())
					Shine.Plugins.scoreboard:SendTeamScoresDatas()
				end
			elseif TGNS.IsGameplayTeamNumber(newTeamNumber) then
				if captainsModeEnabled and TGNS.Has(captainClients, client) then
					Shine.Plugins.scoreboard:SetTeamScoresData(client, captainsGamesWon[client])
				end
		    end
		    if TGNS.IsGameplayTeamNumber(oldTeamNumber) then
		    	momentsWhenLastLeftPlayingTeam[client] = TGNS.GetSecondsSinceMapLoaded()
		    end

		    if captainsModeEnabled then
		    	if not TGNS.IsGameInProgress() then
			    	plans[client] = nil
				    displayPlansToAll()
		    	end
		    else
				if votesAllowedUntil ~= nil and votesAllowedUntil > TGNS.GetSecondsSinceMapLoaded() and #TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end) == 2 then
					updateCaptainsReadyProgress(client)
				end
		    end
		end

		function Plugin:ClientConfirmConnect(client)
			TGNS.ScheduleAction(6, function()
				if Shine:IsValidClient(client) then
					local message
					if captainsModeEnabled then
						message = getCaptainsGameStateDescription()
					elseif TGNS.Has(recentCaptainPlayerIds, TGNS.GetClientSteamId(client)) and votesAllowedUntil == nil then
						message = "Thanks for being a Captain recently! Recent Captains opt-in before other players."
					end
					if TGNS.HasNonEmptyValue(message) then
						md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), message)
					end
				end
			end)
			table.insert(confirmedConnectedClients, client)
			TGNS.AddTempGroup(client, "iwantcaptainscommand_group")

			if not TGNS.IsProduction() and not TGNS.GetIsClientVirtual(client) then
				-- OnConsoleAddBots(nil, 5, kTeamReadyRoom)
				-- local clients = TGNS.GetClientList()
				-- table.insert(captainClients, clients[1])
				-- table.insert(captainClients, #clients > 1 and clients[2] or clients[1])
				-- readyPlayerClients = TGNS.Take(TGNS.Where(clients, function(c) return not TGNS.Has(captainClients, c) end), MAX_NON_CAPTAIN_PLAYERS)
				-- TGNS.DoFor(readyPlayerClients, function(c)
				-- 	TGNS.AddTempGroup(c, "captainsgame_group")
				-- end)
				-- TGNS.DoFor(captainClients, function(c)
				-- 	TGNS.AddTempGroup(c, "captains_group")
				-- end)
				-- showPickables()
			end
		end

		OnServerInitialise = function(self)
			recentCaptainsData = Shine.LoadJSONFile(recentCaptainsTempfilePath) or {}
			TGNS.RemoveAllWhere(recentCaptainsData, function(d) return TGNS.GetSecondsSinceEpoch() - d.gameEnded >= TGNS.ConvertHoursToSeconds(4) end)
			TGNS.SortDescending(recentCaptainsData, function(d) return d.gameEnded end)
			Shine.SaveJSONFile(recentCaptainsData, recentCaptainsTempfilePath)
			recentCaptainPlayerIds = TGNS.Select(TGNS.Take(recentCaptainsData, 2), function(d) return d.steamId end)

			md = TGNSMessageDisplayer.Create("CAPTAINS")
			self:CreateCommands()

			mayVoteYet = false
			local whenPlayersWereLastStillConnecting
			local mayVoteYetChecker
			mayVoteYetChecker = function()
				if TGNS.GetSecondsSinceMapLoaded() < ALLOW_VOTE_MAXIMUM_LIMIT_IN_SECONDS then
					if TGNS.GetNumberOfConnectingPlayers() <= 2 then
						automaticVoteAllowAction()
					else
						TGNS.ScheduleAction(2, mayVoteYetChecker)
					end
				else
					automaticVoteAllowAction()
				end
			end
			TGNS.ScheduleAction(10, mayVoteYetChecker)

			local originalGetCanPlayerHearPlayer
			originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
				local result
				local shouldOverrideVoicecomm = captainsModeEnabled and captainsGamesFinished == 0 and TGNS.IsPlayerReadyRoom(speakerPlayer) and TGNS.IsPlayerReadyRoom(listenerPlayer) and not (Shine.Plugins.sidebar and Shine.Plugins.sidebar.IsEitherPlayerInSidebar and Shine.Plugins.sidebar:IsEitherPlayerInSidebar(listenerPlayer, speakerPlayer))
				if shouldOverrideVoicecomm then
					local speakerClient = TGNS.GetClient(speakerPlayer)
					result = TGNS.IsClientAdmin(speakerClient) or TGNS.IsClientGuardian(speakerClient) or TGNS.ClientIsInGroup(speakerClient, "captains_group")
					if result ~= true then
						if lastVoiceWarningTimes[speakerClient] == nil or lastVoiceWarningTimes[speakerClient] < Shared.GetTime() - 2 then
							md:ToPlayerNotifyError(speakerPlayer, "Others cannot hear you. Only Captains and Admins may use voicecomm while teams are being selected.")
							lastVoiceWarningTimes[speakerClient] = Shared.GetTime()
						end
					end
				else
					result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
				end
				return result
			end)

			TGNS.RegisterEventHook("GameCountdownStarted", function(secondsSinceEpoch)
				nextGameSpawnLocationsSummary = nil
			end)

			TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
				if captainsModeEnabled then
					local chairLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kMarineTeamType)):GetLocationName()
					local hiveLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kAlienTeamType)):GetLocationName()
					local spawnSelectionOverrides = {}
					local spawnSelectionOverride = {chairLocationName, hiveLocationName}
					table.insert(spawnSelectionOverrides, spawnSelectionOverride)
					Shine.Plugins.spawnselectionoverrides:ForceOverrides(spawnSelectionOverrides)
					TGNS.RemoveTempGroup(getTeamChoiceCaptainClient(captainClients), "teamchoicecaptain_group")
				end
				plans = {}
				displayPlansToAll()
			end)

			local originalGetCanJoinTeamNumber
			originalGetCanJoinTeamNumber = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanJoinTeamNumber", function(gamerulesSelf, player, teamIndex)
				local allowed, reason = originalGetCanJoinTeamNumber(gamerulesSelf, player, teamIndex)
				if captainsModeEnabled then
					allowed = true
					reason = nil
				end
				return allowed, reason
			end)

			local originalResetGame
			originalResetGame = TGNS.ReplaceClassMethod("NS2Gamerules", "ResetGame", function(gamerules)
				local teamChoiceCaptainClient = getTeamChoiceCaptainClient(captainClients)
				if captainsModeEnabled and teamChoiceCaptainClient then
					TGNS.RemoveTempGroup(teamChoiceCaptainClient, "teamchoicecaptain_group")
				end
				originalResetGame(gamerules)
				if captainsModeEnabled and teamChoiceCaptainClient and captainsGamesFinished == 0 then
					TGNS.RemoveTempGroup(teamChoiceCaptainClient, "teamchoicecaptain_group")
				end
			end)

			TGNS.DoWithConfig(function()
				local url = string.format("%s&n=%s", TGNS.Config.RecentCaptainPlayerIdsEndpointBaseUrl, TGNS.GetSimpleServerName())
				TGNS.GetHttpAsync(url, function(recentCaptainPlayerIdsResponseJson)
					local recentCaptainPlayerIdsResponse = json.decode(recentCaptainPlayerIdsResponseJson) or {}
					if recentCaptainPlayerIdsResponse.success then
						if #recentCaptainPlayerIdsResponse.recentplayers > 0 then
							TGNS.DoFor(recentCaptainPlayerIdsResponse.recentplayers, function(i)
								table.insert(recentPlayerPlayerIds, i)
							end)
						end
					else
						TGNS.DebugPrint(string.format("captains ERROR: Unable to access recentcaptainplayerids data for server %s. msg: %s | response: %s | stacktrace: %s", TGNS.GetSimpleServerName(), recentCaptainPlayerIdsResponse.msg, recentCaptainPlayerIdsResponseJson, recentCaptainPlayerIdsResponse.stacktrace))
					end
				end)
			end)

			local originalServerSetPassword = Server.SetPassword
			local function disallowPasswordAfterMidnightOnSaturdays()
				if TGNS.GetAbbreviatedDayOfWeek() == "Sat" and TGNS.GetCurrentHour() < 6 then
						Server.SetPassword("")
						Server.SetPassword = function()
							TGNS.ScheduleAction(0, function()
								md:ToAdminConsole("ERROR: Password disabled between midnight and 6AM Saturday.")
							end)
						end
				else
					Server.SetPassword = originalServerSetPassword
					TGNS.ScheduleAction(60, disallowPasswordAfterMidnightOnSaturdays)
				end
			end

			TGNS.ScheduleAction(15, function()
				if TGNS.IsProduction() then
					disallowPasswordAfterMidnightOnSaturdays()
				end
			end)

			TGNS.RegisterEventHook("OnEveryMinute", function()
				if TGNS.GetAbbreviatedDayOfWeek() == "Fri" and TGNS.GetCurrentHour() == CAPTAINS_NIGHT_START_HOUR_LOCAL_SERVER_TIME and TGNS.GetCurrentMinute() <= 1 then
					TGNS.DoFor(TGNS.GetHumanClientList(), function(c)
						if not hasEarnedCaptainsNightPunctualityKarma[c] then
							TGNS.Karma(c, "CaptainsNightPunctuality")
							hasEarnedCaptainsNightPunctualityKarma[c] = true
						end
					end)
					if not captainsEventStartPushSent then
						Shine.Plugins.push:Push("tgns-captains", "TGNS Captains Night", "It's time for Captains Night at TGNS! Password in the forums: https://www.tacticalgamer.com/forum/action/natural-selection/natural-selection-general-discussion")
						captainsEventStartPushSent = true
					end
				end
			end)


			TGNS.RegisterEventHook("AFKChanged", function(client, playerIsAfk)
				if votesAllowedUntil ~= nil and votesAllowedUntil > TGNS.GetSecondsSinceMapLoaded() and #TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(readyCaptainClients, c) end) == 2 then
					updateCaptainsReadyProgress(client)
				end
			end)
		end
	end

	function Plugin:Initialise()
		self.Enabled = true
		if Client then OnClientInitialise(Plugin) end
		if Server then OnServerInitialise(Plugin) end
		return true
	end

	function Plugin:Cleanup()
	    --Cleanup your extra stuff like timers, data etc.
	    self.BaseClass.Cleanup( self )
	end

	Shine:RegisterExtension("captains", Plugin )
end