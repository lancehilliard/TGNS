local Plugin = Plugin
local prefixes = {}
local isCaptainsCaptain = {}
local isApproved = {}
local isQuerying = {}
local isVring = false
local isSquading = false
local isQueryingBadge = {}
local approveReceivedTotal = 0
local approveSentTotal = 0
local APPROVE_TEXTURE_DISABLED = "ui/approve/chevron-disabled.dds"
local QUERY_TEXTURE_DISABLED = "ui/query/contactcard-disabled.dds"
local SQUAD_TEXTURE_DISABLED = "ui/squads/squad-disabled-squad0.dds"
local lastUpdatedPingsWhen = {}
local pings = {}
local showCustomNumbersColumn = true
local showOptionals = false
local notes = {}
local hasJetPacks = {}
local showTeamMessages = true
-- local badgeLabels = {}
local vrConfirmed = {}
local countdownSoundEventName = "sound/tgns.fev/winorlose/countdown"
local tooltipSoundEventName = "sound/NS2.fev/common/hud_on"
local approveSoundEventName = "sound/tgns.fev/scoreboard/approve"
local badSoundEventName = "sound/tgns.fev/laps/bad"
local legSoundEventName = "sound/tgns.fev/laps/leg"
local bestSoundEventName = "sound/tgns.fev/laps/best"
local startSoundEventName = "sound/tgns.fev/laps/start"
local armorDecay1SoundEventName = "sound/tgns.fev/harvesterdecay/armordecay1"
local gameIsInProgressLastChanged
local gameIsInProgress = false
local serverSimpleName
local squadNumbers={}
local squadNumbersHudText
local squadNumberLastSetTimes = {}
local WELCOME_MESSAGES = { "Welcome to Tactical Gamer Natural Selection (TGNS)!",
						  "If you enjoy mature, respectful play, please ask about our reserved slots.",
						  "To learn more about TGNS, press 'M' and click 'Info'. Enjoy! :)" }
local EXTRA_SECONDS_TO_DISPLAY_BANNER_AFTER_TEXT_MESSAGES = 25
local communityDesignationCharacter = '?'
local welcomeBannerImageName
local armorlessMatureHarvesterEntityIds = {}
local startedUntrackableAfkActivityAt = 0
local wasInUntrackableAfkActivity = false
local isUsingSvi = {}
local hasAfkRelevantActivity
local afkRelevantActivityAnnouncedAt = 0
local recentCaptainsClientIndexes = {}
local failsBkaPrerequisite = {}
local hasWelder = {}
local hasMines = {}
local hasClusterGrenade = {}
local hasGasGrenade = {}
local hasPulseGrenade = {}

local CaptainsCaptainFontColor = Color(0, 1, 0, 1)
local guiItemTooltipText
local hoverBadge

TGNS.HookNetworkMessage(Shine.Plugins.scoreboard.SCOREBOARD_DATA, function(message)
	prefixes[message.i] = message.p
	isCaptainsCaptain[message.i] = message.c
	isUsingSvi[message.i] = message.s
	failsBkaPrerequisite[message.i] = message.b
	hasWelder[message.i] = message.w
	hasMines[message.i] = message.m
	hasClusterGrenade[message.i] = message.cg
	hasGasGrenade[message.i] = message.gg
	hasPulseGrenade[message.i] = message.pg
end)

TGNS.HookNetworkMessage(Plugin.TOGGLE_CUSTOM_NUMBERS_COLUMN, function(message)
	showCustomNumbersColumn = message.t
end)

TGNS.HookNetworkMessage(Plugin.RECENT_CAPTAINS, function(message)
	recentCaptainsClientIndexes = TGNS.Split(",", message.c)
end)


TGNS.HookNetworkMessage(Plugin.ALERT_ICON, function(message)
	if Client.WindowNeedsAttention then
		Client.WindowNeedsAttention()
	end
end)

TGNS.HookNetworkMessage(Plugin.SQUAD_CONFIRMED, function(message)
	squadNumberLastSetTimes[message.c] = Shared.GetTime()
	squadNumbers[message.c] = message.s
end)

TGNS.HookNetworkMessage(Plugin.VR_CONFIRMED, function(message)
	vrConfirmed[message.c] = true
end)

local function inProgressGameShouldProhibitSquadChanging(teamNumber)
	local result = gameIsInProgress and (Shared.GetTime() - gameIsInProgressLastChanged > 30) and teamNumber == kAlienTeamType
	return result
end

local function getTeamApproveTexture(teamNumber)
	local result = string.format("ui/approve/chevron-team%s.dds", teamNumber)
	return result
end

local function getTeamSquadTexture(clientIndex, teamNumber, shouldBeDisabled)
	local teamDescriptor = string.format("%s%s", shouldBeDisabled and "disabled" or "team", teamNumber)
	local result = string.format("ui/squads/squad-%s-squad%s.dds", teamDescriptor, squadNumbers[clientIndex] or 0)
	return result
end

local function getTeamVrTexture(clientIndex, teamNumber)
	local result = vrConfirmed[clientIndex] and string.format("ui/vr/vr-checked-team%s.dds", teamNumber) or string.format("ui/vr/vr-team%s.dds", teamNumber)
	return result
end

local function getDisabledVrTexture(clientIndex)
	local result = vrConfirmed[clientIndex] and "ui/vr/vr-checked-disabled.dds" or VR_TEXTURE_DISABLED
	return result
end

local function getTeamQueryTexture(teamNumber)
	local result = string.format("ui/query/contactcard-team%s.dds", teamNumber)
	return result
end

local function initializeSquadHudText()
	if squadNumbersHudText then
		squadNumbersHudText:Remove()
	end
	squadNumbersHudText = Shine.ScreenText.Add( "Squad", {
		X = 0.04, Y = 0.61,
		Text = "",
		Duration = math.huge,
		R = 255, G = 255, B = 255,
		Alignment = 2,
		Size = 2,
		FadeIn = 0.5
	} )

	function squadNumbersHudText:UpdateText()
		local text = ""
		local squadNumberLastSetTime = squadNumberLastSetTimes[Client.GetLocalClientIndex()] or 0
		local secondsSinceSquadNumberLastSet = math.floor(Shared.GetTime() - squadNumberLastSetTime)
		local shouldHideSquadNumberToCauseBlinkingEffect = (secondsSinceSquadNumberLastSet < 6 and secondsSinceSquadNumberLastSet % 2 == 0) or (secondsSinceSquadNumberLastSet > 10)
		local squadNumber = squadNumbers[Client.GetLocalClientIndex()] or 0
		local isCommander = Scoreboard_GetPlayerData(Client.GetLocalClientIndex(), "IsCommander")
		if squadNumber ~= 0 and not isCommander and not shouldHideSquadNumberToCauseBlinkingEffect then
			if Client.GetLocalClientTeamNumber() == kMarineTeamType then
				text = string.format("\nSquad %s", squadNumber)
			else
				local plannedLifeFormNames = {"Skulk", "Gorge", "Lerk", "Fade", "Onos", "KHAMM"}
				text = string.format("\n%s", plannedLifeFormNames[squadNumber])
			end
		end
		self.Obj:SetText(text)
	end
end

function Plugin:OnResolutionChanged( OldX, OldY, NewX, NewY )
	initializeSquadHudText()
end

function Plugin:Initialise()
	self.Enabled = true

	Client.PrecacheLocalSound(countdownSoundEventName)
	Client.PrecacheLocalSound(tooltipSoundEventName)
	Client.PrecacheLocalSound(approveSoundEventName)
	Client.PrecacheLocalSound(badSoundEventName)
	Client.PrecacheLocalSound(legSoundEventName)
	Client.PrecacheLocalSound(bestSoundEventName)
	Client.PrecacheLocalSound(startSoundEventName)
	Client.PrecacheLocalSound(armorDecay1SoundEventName)

	local originalGUIScoreboardUpdate = GUIScoreboard.Update
	GUIScoreboard.Update = function(self, deltaTime)
		originalGUIScoreboardUpdate(self, deltaTime)

        if self.visible then

        	guiItemTooltipText = nil
        	hoverBadge = nil

			for index, team in ipairs(self.teams) do
	            self:UpdateTeam(team)
		    end


            if guiItemTooltipText and self.badgeNameTooltip and not self.hoverMenu.background:GetIsVisible() and not MainMenu_GetIsOpened() then
				self.badgeNameTooltip:SetText(guiItemTooltipText)
				self.badgeNameTooltip.protectedText = guiItemTooltipText
                self.badgeNameTooltip:Show(0)
            else
                if not hoverBadge then
	                self.badgeNameTooltip:Hide(nil, true)
                end
            end


        else
	    	if self.badgeNameTooltip and self.badgeNameTooltip.background:GetIsVisible() then
	    		self.badgeNameTooltip:Hide(0, true)
			end
        end


	end

	local originalGUIScoreboardUpdateTeam = GUIScoreboard.UpdateTeam
	GUIScoreboard.UpdateTeam = function(self, updateTeam)
		originalGUIScoreboardUpdateTeam(self, updateTeam)

		if self.visible then
	        local gameTime = PlayerUI_GetGameLengthTime()
	        local minutes = math.floor( gameTime / 60 )
	        local seconds = math.floor( gameTime - minutes * 60 )
	        local serverName = Client.GetServerIsHidden() and "Hidden" or Client.GetConnectedServerName()

	        local ingamePlayersCount = 0
		    for teamsIndex, team in ipairs(self.teams) do
		    	local playerList = team["PlayerList"]
		    	local teamScores = team["GetScores"]()
		    	//local currentPlayerIndex = 1
				for playerListIndex, player in ipairs(playerList) do
					local playerRecord = teamScores[playerListIndex]
					if playerRecord and playerRecord.Ping > 0 then
						ingamePlayersCount = ingamePlayersCount + 1
					end
					//currentPlayerIndex = currentPlayerIndex + 1
				end
		    end
	        local numPlayersConnecting = PlayerUI_GetNumConnectingPlayers()
	        local gameTimeText = string.format("%s | %s - (%d %s%s) - %d:%02d", serverName, Shared.GetMapName(), ingamePlayersCount, ingamePlayersCount == 1 and Locale.ResolveString("SB_PLAYER") or Locale.ResolveString("SB_PLAYERS"), numPlayersConnecting > 0 and string.format(", %d %s", numPlayersConnecting, Locale.ResolveString("SB_CONNECTING")) or "", minutes, seconds)
	        self.gameTime:SetText(gameTimeText)
		end

		local playerList = updateTeam["PlayerList"]
		local teamScores = updateTeam["GetScores"]()
		local teamNumber = updateTeam["TeamNumber"]
		local currentPlayerIndex = 1
		local totalAfkCount = 0
		for index, player in pairs(playerList) do
	        local playerRecord = teamScores[currentPlayerIndex]
	        local clientIndex = playerRecord.ClientIndex
	        if showCustomNumbersColumn then
	        	player["Number"]:SetIsVisible(true)
		        local prefix = prefixes[clientIndex]
		        player["Number"]:SetText(TGNS.HasNonEmptyValue(prefix) and prefix or "")
		        local numberColor = Color(0.5, 0.5, 0.5, 1)
		        if isCaptainsCaptain[clientIndex] == true then
		        	numberColor = CaptainsCaptainFontColor
		        end
		        player["Number"]:SetColor(numberColor)
	        end

   	        local icons = {
	        	{n="PlayerSquadIcon",t=SQUAD_TEXTURE_DISABLED,x=-25,l=function(teamNumber)
			        local circleName = "Player Circle"
			        local circleCycleName = "squads and lifeforms"
			        if teamNumber == kMarineTeamType then
			        	circleName = "Squad Circle"
			        	circleCycleName = "squad assignments"
			        elseif teamNumber == kAlienTeamType then
			        	circleName = "Lifeform Circle"
			        	circleCycleName = "planned lifeforms"
			        end
	        		return circleName .. "\n\nClick to cycle through\n" .. circleCycleName .. "."
	        	end}
	        	,{n="PlayerApproveIcon",t=APPROVE_TEXTURE_DISABLED,l="Approve Chevron\n\nClick to approve this player for any reason!\n\nAlso: if a player has an unchecked Voicecomm Vouch Bubble,\nclick this when you're SURE they can hear team voicecomm.\nThis lets the whole team see that the player has been vouched!"}
	        	,{n="PlayerQueryIcon",t=QUERY_TEXTURE_DISABLED,l="Contact Card\n\nClick to see player\nidentity information."}
	        	,{n="PlayerVrIcon",t=VR_TEXTURE_DISABLED,l="Voicecomm Vouch Bubble\n\nClick to warn anyone not\nresponding to team voicecomm.\n\nAlso: a checkmark in the bubble means someone already\nvouched that this player can hear team voicecomm."}
	        	,{n="PlayerWelderIcon",t="ui/badges/marines/Welder.dds",x=-140,l="Welder\n\nThis player has a Welder."}
	        	,{n="PlayerMinesIcon",t="ui/badges/marines/Mines.dds",x=-160,l="Mines\n\nThis player has Mines."}
	        	,{n="PlayerPulseGrenadeIcon",t="ui/badges/marines/Pulse.dds",x=-180,l="Pulse Grenades\n\nThis player has Pulse Grenades."}
	        	,{n="PlayerGasGrenadeIcon",t="ui/badges/marines/Gas.dds",x=-180,l="Gas Grenades\n\nThis player has Gas Grenades."}
	        	,{n="PlayerClusterGrenadeIcon",t="ui/badges/marines/Cluster.dds",x=-180,l="Cluster Grenades\n\nThis player has Cluster Grenades."}
	    	}

			TGNS.DoFor(icons, function(i)
				if player[i.n] then
					if i.x then
						local icon = player[i.n]
						local iconPosition = icon:GetPosition()
						local statusPosition = player.Status:GetPosition()
						iconPosition.x = statusPosition.x + i.x
						icon:SetPosition(iconPosition)
					end
				else
				    local icon = GUIManager:CreateGraphicItem()
				    --local position = player.Status:GetPosition()
				    --position.x = position.x + i.x
				    --position.y = position.y + (i.y or -10)
				    icon:SetSize(Vector(20, 20, 0))
				    icon:SetAnchor(GUIItem.Left, GUIItem.Center)
				    -- icon:SetPosition(position)
				    icon:SetTexture(i.t)
				    icon.tooltipText = i.l
				    player[i.n] = icon
				    player.Background:AddChild(icon)
				    if player.IconTable then
				    	table.insert(player["IconTable"], icon)
				    end
				end
			end)

			if teamNumber == 0 and player.Status:GetText():find("Spec") then
				local shouldShowSvi = isUsingSvi[Client.GetLocalClientIndex()] and isUsingSvi[clientIndex] and Client.GetLocalClientTeamNumber() == kSpectatorIndex
				player.Status:SetText(shouldShowSvi and "Spec(SVI)" or "Spectator")
			end

			if teamNumber == 0 and failsBkaPrerequisite[clientIndex] then
				player.Name:SetColor(Color(0/255,191/255,255/255))
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


			local guiItems = {}
			local playerIsBot = playerRecord.Ping == 0

	        local playerApproveIcon = player["PlayerApproveIcon"]



	        local playerSquadIconShouldDisplay = (teamNumber == kMarineTeamType or teamNumber == kAlienTeamType) and ((teamNumber == Client.GetLocalClientTeamNumber()) or (PlayerUI_GetIsSpecating() and Client.GetLocalClientTeamNumber() ~= kMarineTeamType and Client.GetLocalClientTeamNumber() ~= kAlienTeamType)) and not playerIsBot
	        local playerApproveIconShouldDisplay = ((clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals)
	        local playerQueryIconShouldDisplay = ((clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals)
	        local playerVrIconShouldDisplay = (((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber())) and (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals)
        	local playerNoteItemShouldDisplay = (teamNumber == kMarineTeamType or teamNumber == kAlienTeamType) and ((teamNumber == Client.GetLocalClientTeamNumber()) or (PlayerUI_GetIsSpecating() and Client.GetLocalClientTeamNumber() ~= kMarineTeamType and Client.GetLocalClientTeamNumber() ~= kAlienTeamType))
        	--local playerApproveStatusItemShouldDisplay = (clientIndex == Client.GetLocalClientIndex() and showOptionals)
        	local playerWelderIconShouldDisplay = (((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber() and teamNumber == kMarineTeamType)) and hasWelder[clientIndex])
        	local playerMinesIconShouldDisplay = (((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber() and teamNumber == kMarineTeamType)) and hasMines[clientIndex])
        	local playerClusterGrenadeIconShouldDisplay = (((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber() and teamNumber == kMarineTeamType)) and hasClusterGrenade[clientIndex])
        	local playerGasGrenadeIconShouldDisplay = (((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber() and teamNumber == kMarineTeamType)) and hasGasGrenade[clientIndex])
        	local playerPulseGrenadeIconShouldDisplay = (((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber() and teamNumber == kMarineTeamType)) and hasPulseGrenade[clientIndex])
        	local playerNote = notes[clientIndex]

        	local targetPrefix = prefixes[clientIndex] or ""
	        if playerVrIconShouldDisplay then
        		local targetPrefixFiltered = TGNS.Replace(targetPrefix, "!", "")
        		targetPrefixFiltered = TGNS.Replace(targetPrefixFiltered, "*", "")
        		playerVrIconShouldDisplay = not TGNS.HasNonEmptyValue(targetPrefixFiltered)
	        end

        	if Shared.GetDevMode() then
		        playerSquadIconShouldDisplay = true
		        playerApproveIconShouldDisplay = true
		        playerQueryIconShouldDisplay = true
		        playerVrIconShouldDisplay = true
	        	playerNoteItemShouldDisplay = true
	        	--playerApproveStatusItemShouldDisplay = true
	        	playerWelderIconShouldDisplay = true
	        	playerMinesIconShouldDisplay = true
	        	playerClusterGrenadeIconShouldDisplay = true
	        	playerGasGrenadeIconShouldDisplay = true
	        	playerPulseGrenadeIconShouldDisplay = true
	        	playerNote = playerNote or "test"
        	end

        	if player.SteamFriend then
			    local steamFriendPosition = player.Ping:GetPosition()
			    steamFriendPosition.x = steamFriendPosition.x + 26
			    steamFriendPosition.y = steamFriendPosition.y - 10
			    player.SteamFriend:SetPosition(steamFriendPosition)
			    player.SteamFriend:SetIsVisible(playerRecord.IsSteamFriend or Shared.GetDevMode() or Client.GetLocalClientIndex() == clientIndex)
			    if player.IconTable then
			    	table.removevalue(player.IconTable, player.SteamFriend)
			    end
        	end


	        if TGNS.Contains(targetPrefix, "!") then
	        	totalAfkCount = totalAfkCount + 1
	        end

			local playerNoteItemPosition = player.Status:GetPosition()
			local xOffset = 0
			local addOffsetIf = function(boolean) if boolean then xOffset = xOffset + 20 end end
			addOffsetIf(playerSquadIconShouldDisplay)
			addOffsetIf(playerApproveIconShouldDisplay)
			addOffsetIf(playerQueryIconShouldDisplay)
			addOffsetIf(playerVrIconShouldDisplay)

			-- addOffsetIf(playerWelderIconShouldDisplay)
			-- addOffsetIf(playerMinesIconShouldDisplay)
			-- addOffsetIf(playerClusterGrenadeIconShouldDisplay)
			-- addOffsetIf(playerGasGrenadeIconShouldDisplay)
			-- addOffsetIf(playerPulseGrenadeIconShouldDisplay)

			playerNoteItemPosition.x = playerNoteItemPosition.x - xOffset - 5
		    playerNoteItemPosition.y = playerNoteItemPosition.y + 7
			player.PlayerNoteItem:SetPosition(playerNoteItemPosition)

	        if playerApproveIcon then
	        	table.insert(guiItems, playerApproveIcon)
	        	playerApproveIcon:SetIsVisible(playerApproveIconShouldDisplay)
		        playerApproveIcon:SetTexture(isApproved[clientIndex] and APPROVE_TEXTURE_DISABLED or getTeamApproveTexture(teamNumber))
	        end
	        local playerVrIcon = player["PlayerVrIcon"]
	        if playerVrIcon then
	        	table.insert(guiItems, playerVrIcon)
	        	playerVrIcon:SetIsVisible(playerVrIconShouldDisplay)
	        	local playerVrIconShouldBeDisabled = isVring or (TGNS.Contains(targetPrefix, "!") and not vrConfirmed[clientIndex])
		        playerVrIcon:SetTexture(playerVrIconShouldBeDisabled and getDisabledVrTexture(clientIndex) or getTeamVrTexture(clientIndex, teamNumber))
	        end
	        local playerQueryIcon = player["PlayerQueryIcon"]
	        if playerQueryIcon then
	        	table.insert(guiItems, playerQueryIcon)
	        	playerQueryIcon:SetIsVisible(playerQueryIconShouldDisplay)
		        playerQueryIcon:SetTexture(isQuerying[clientIndex] and QUERY_TEXTURE_DISABLED or getTeamQueryTexture(teamNumber))
	        end
	        local playerWelderIcon = player["PlayerWelderIcon"]
	        if playerWelderIcon then
	        	table.insert(guiItems, playerWelderIcon)
	        	playerWelderIcon:SetIsVisible(playerWelderIconShouldDisplay)
	        end
	        local playerMinesIcon = player["PlayerMinesIcon"]
	        if playerMinesIcon then
	        	table.insert(guiItems, playerMinesIcon)
	        	playerMinesIcon:SetIsVisible(playerMinesIconShouldDisplay)
	        end
	        local playerClusterGrenadeIcon = player["PlayerClusterGrenadeIcon"]
	        if playerClusterGrenadeIcon then
	        	table.insert(guiItems, playerClusterGrenadeIcon)
	        	playerClusterGrenadeIcon:SetIsVisible(playerClusterGrenadeIconShouldDisplay)
	        end
	        local playerGasGrenadeIcon = player["PlayerGasGrenadeIcon"]
	        if playerGasGrenadeIcon then
	        	table.insert(guiItems, playerGasGrenadeIcon)
	        	playerGasGrenadeIcon:SetIsVisible(playerGasGrenadeIconShouldDisplay)
	        end
	        local playerPulseGrenadeIcon = player["PlayerPulseGrenadeIcon"]
	        if playerPulseGrenadeIcon then
	        	table.insert(guiItems, playerPulseGrenadeIcon)
	        	playerPulseGrenadeIcon:SetIsVisible(playerPulseGrenadeIconShouldDisplay)
	        end


		    local color = GUIScoreboard.kSpectatorColor
		    if teamNumber == kTeam1Index then
		        color = GUIScoreboard.kBlueColor
		    elseif teamNumber == kTeam2Index then
		        color = GUIScoreboard.kRedColor
		    end
	        -- local playerApproveStatusItem = player["PlayerApproveStatusItem"]
	        -- if playerApproveStatusItem then
	        -- 	table.insert(guiItems, playerApproveStatusItem)
	        -- 	playerApproveStatusItem:SetIsVisible(playerApproveStatusItemShouldDisplay)
	        -- 	playerApproveStatusItem:SetText(tostring(approveSentTotal) .. ":" .. tostring(approveReceivedTotal))
	        -- 	playerApproveStatusItem:SetColor(color)
	        -- end

	        local playerNoteItem = player["PlayerNoteItem"]
	        if playerNoteItem then
	        	playerNoteItem:SetIsVisible(playerNoteItemShouldDisplay)
	        	playerNoteItem:SetText(string.format("%s", playerNote and playerNote or ""))
	        	playerNoteItem:SetColor(color)
	        end
	        local playerSquadIcon = player["PlayerSquadIcon"]
	        if playerSquadIcon then
	        	table.insert(guiItems, playerSquadIcon)
	        	playerSquadIcon:SetIsVisible(playerSquadIconShouldDisplay)
	        	local playerSquadIconShouldBeDisabled = isSquading or (Client.GetLocalClientTeamNumber() == kSpectatorIndex) or inProgressGameShouldProhibitSquadChanging(teamNumber)
		        playerSquadIcon:SetTexture(getTeamSquadTexture(clientIndex, teamNumber, playerSquadIconShouldBeDisabled))
	        end

			if MouseTracker_GetIsVisible() and not guiItemTooltipText and not hoverBadge then
				local mouseX, mouseY = Client.GetCursorPosScreen()
				for i = 1, #guiItems do
					local guiItem = guiItems[i]
					if GUIItemContainsPoint(guiItem, mouseX, mouseY) and guiItem:GetIsVisible() then
						guiItemTooltipText = type(guiItem.tooltipText) == "function" and guiItem.tooltipText(teamNumber) or guiItem.tooltipText
						break
					end
				end
                for i = 1, #player.BadgeItems do
                    local badgeItem = player.BadgeItems[i]
                    if GUIItemContainsPoint(badgeItem, mouseX, mouseY) and badgeItem:GetIsVisible() then
                        hoverBadge = true
                        break
                    end
                end

			end

			if TGNS.Has(recentCaptainsClientIndexes, tostring(clientIndex)) and teamNumber == 0 and not player.Status:GetText():find("Spec") then
				player["Background"]:SetColor(Color(17/255,115/255,17/255))
			end

			if self.hoverMenu then
				self.hoverMenu:RemoveButtonByText("Mute text")
				if gameIsInProgress and (Client.GetLocalClientTeamNumber() == kMarineTeamType or Client.GetLocalClientTeamNumber() == kAlienTeamType) then
					self.hoverMenu:RemoveButtonByText("Hive profile")
					self.hoverMenu:RemoveButtonByText("NS2Stats profile")
				end
			end

	        currentPlayerIndex = currentPlayerIndex + 1
		end

		if totalAfkCount > 0 then
		    local teamNameGUIItem = updateTeam["GUIs"]["TeamName"]
		    local teamNameGUIItemText = teamNameGUIItem:GetText()
			local truncatedTeamNameGUIItemText = string.sub(teamNameGUIItemText, 1, string.len(teamNameGUIItemText) - 1)
		    local teamHeaderText = string.format("%s, with %d AFK)", truncatedTeamNameGUIItemText, totalAfkCount)
		    teamNameGUIItem:SetText(teamHeaderText)
		end

		if gameIsInProgress and (Client.GetLocalClientTeamNumber() == kMarineTeamType or Client.GetLocalClientTeamNumber() == kAlienTeamType) and teamNumber == Client.GetLocalClientTeamNumber() then

		    local teamInfo = GetEntitiesForTeam("TeamInfo", Client.GetLocalClientTeamNumber())
		    if teamInfo and #teamInfo > 0 then
			    local numResourceNodes = teamInfo[1]:GetNumResourceTowers()
				local resourceNodesName = Client.GetLocalClientTeamNumber() == kMarineTeamType and "Extractor" or "Harvester"
		    	local teamInfoGUIItem = updateTeam["GUIs"]["TeamInfo"]
		    	local originalTeamInfoGuiItemText = teamInfoGUIItem:GetText()
			    teamInfoGUIItem:SetText(string.format("%s (%s)", originalTeamInfoGuiItemText, Pluralize(numResourceNodes, resourceNodesName)))
		    end
		end
	end

	local originalGUIScoreboardSendKeyEvent = GUIScoreboard.SendKeyEvent
	GUIScoreboard.SendKeyEvent = function(self, key, down)


		if self.hoverMenu then
			if self.hoverPlayerClientIndex ~= 0 then
				local isCommander = Scoreboard_GetPlayerData(self.hoverPlayerClientIndex, "IsCommander")
				local teamNumber = Scoreboard_GetPlayerData(self.hoverPlayerClientIndex, "EntityTeamNumber")
				local textColor = Color(1, 1, 1, 1)
				local teamColorBg
				local teamColorHighlight
				local groupLabelColor = Color(0, 0, 0, 0)
				
				if isCommander then
					teamColorBg = GUIScoreboard.kCommanderFontColor
				elseif teamNumber == 1 then
					teamColorBg = GUIScoreboard.kBlueColor
				elseif teamNumber == 2 then
					teamColorBg = GUIScoreboard.kRedColor
				else
					teamColorBg = GUIScoreboard.kSpectatorColor
				end
				
				teamColorHighlight = teamColorBg * 0.60
				teamColorBg = teamColorBg * 0.4					

				local targetPrefix = prefixes[self.hoverPlayerClientIndex] or ""
				local targetIsSelf = GetSteamIdForClientIndex(self.hoverPlayerClientIndex) == Client.GetSteamId()
				local targetIsEligibleForAfkRr = teamNumber == Client.GetLocalClientTeamNumber() and not gameIsInProgress and TGNS.Contains(targetPrefix, "!") and (Client.GetLocalClientTeamNumber() == kMarineTeamType or Client.GetLocalClientTeamNumber() == kAlienTeamType)
				local buttons = {
					{text="TGNS"}
				  , {text="  Portal: My Badges", callback=function(data) Client.ShowWebpage("http://rr.tacticalgamer.com/Badges/Manage") end, condition=targetIsSelf}
				  , {text="  Portal: My Settings", callback=function(data) Client.ShowWebpage("http://rr.tacticalgamer.com/My/Settings") end, condition=targetIsSelf}
				  , {text="  Send to RR (pre-game AFK)", callback=function(data) TGNS.SendNetworkMessage(Plugin.REQUEST_AFKRR, {c=self.hoverPlayerClientIndex}) end, condition=targetIsEligibleForAfkRr}
				  , {text="  Admin Feedback", callback=function(data) Client.ShowWebpage(string.format("http://rr.tacticalgamer.com/Feedback/Index?i=%s&n=%s&s=%s", data.ns2id, url_encode(data.playerName), url_encode(data.serverSimpleName))) end, condition=not targetIsSelf}
				}
				local ns2id = GetSteamIdForClientIndex(self.hoverPlayerClientIndex)
				local playerName = Scoreboard_GetPlayerData(self.hoverPlayerClientIndex, "Name")
				for i = 1, #buttons do
					local button = buttons[i]
					self.hoverMenu:RemoveButtonByText(button.text)
					if button.condition == nil or button.condition then
						local bgColor = button.callback and teamColorBg or groupLabelColor
						local highlightColor = button.callback and teamColorHighlight or groupLabelColor
						button.callback = button.callback or function() end
						self.hoverMenu:AddButton(button.text, bgColor, highlightColor, textColor, function() button.callback({ns2id=ns2id,playerName=playerName,serverSimpleName=serverSimpleName}) end)
					end
				end
			end
		end

			if (GetIsBinding(key, "MovementModifier")) then
				self.MovementModifierIsPressed = down
			end


		local result = originalGUIScoreboardSendKeyEvent(self, key, down)
		if result then
			local mouseX, mouseY = Client.GetCursorPosScreen()
		    for t = 1, #self.teams do

		        local playerList = self.teams[t]["PlayerList"]
		        for p = 1, #playerList do

		            local playerItem = playerList[p]
	                local clientIndex = playerItem["ClientIndex"]
		            local playerApproveIcon = playerItem["PlayerApproveIcon"]
		            if playerApproveIcon and playerApproveIcon:GetIsVisible() and GUIItemContainsPoint(playerApproveIcon, mouseX, mouseY) then
		            	if self.hoverMenu then
		            		self.hoverMenu:Hide()
		            	end
		            	if not isApproved[clientIndex] then
			                isApproved[clientIndex] = true
			                TGNS.SendNetworkMessage(Plugin.APPROVE_REQUESTED, {c=clientIndex})
		            	end
		            end
		            local playerQueryIcon = playerItem["PlayerQueryIcon"]
		            if playerQueryIcon and playerQueryIcon:GetIsVisible() and GUIItemContainsPoint(playerQueryIcon, mouseX, mouseY) then
		            	if self.hoverMenu then
		            		self.hoverMenu:Hide()
		            	end
		            	if not isQuerying[clientIndex] then
			                isQuerying[clientIndex] = true
			                TGNS.SendNetworkMessage(Plugin.QUERY_REQUESTED, {c=clientIndex})
		            	end
		            end
		            local playerVrIcon = playerItem["PlayerVrIcon"]
		            local playerVrIconShouldBeDisabled = isVring
		            if playerVrIcon and playerVrIcon:GetIsVisible() and GUIItemContainsPoint(playerVrIcon, mouseX, mouseY) then
		            	if self.hoverMenu then
		            		self.hoverMenu:Hide()
		            	end
		            	if not playerVrIconShouldBeDisabled then
			                isVring = true
			                TGNS.SendNetworkMessage(Plugin.VR_REQUESTED, {c=clientIndex})
		            	end
		            end
		            local playerSquadIcon = playerItem["PlayerSquadIcon"]
		            local playerSquadIconShouldBeDisabled = isSquading or (Client.GetLocalClientTeamNumber() == kSpectatorIndex) or inProgressGameShouldProhibitSquadChanging(Client.GetLocalClientTeamNumber())
		            if playerSquadIcon and playerSquadIcon:GetIsVisible() and GUIItemContainsPoint(playerSquadIcon, mouseX, mouseY) then
		            	local squadNumberDelta = self.MovementModifierIsPressed and -1 or 1
		            	if self.hoverMenu then
		            		self.hoverMenu:Hide()
		            	end
		            	if (not playerSquadIconShouldBeDisabled) then
			                isSquading = true
			                TGNS.SendNetworkMessage(Plugin.SQUAD_REQUESTED, {c=clientIndex,d=squadNumberDelta})
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
	TGNS.HookNetworkMessage(Plugin.DESIGNATION, function(message)
		communityDesignationCharacter = message.c
		local welcomeBannerImageNameModifier = communityDesignationCharacter == "S" and "_s" or (communityDesignationCharacter == "P" and "_p" or "")
		welcomeBannerImageName = string.format("ui/welcome/readyroom1%s.dds", welcomeBannerImageNameModifier)
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_ALREADY_APPROVED, function(message)
		isApproved[message.c] = true
	end)
	TGNS.HookNetworkMessage(Plugin.APPROVE_RESET, function(message)
		isApproved = {}
	end)
	TGNS.HookNetworkMessage(Plugin.QUERY_ALLOWED, function(message)
		isQuerying[message.c] = false
	end)
	TGNS.HookNetworkMessage(Plugin.SQUAD_ALLOWED, function(message)
		isSquading = false
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
	TGNS.HookNetworkMessage(Plugin.TOGGLE_OPTIONALS, function(message)
		showOptionals = message.t
	end)
	TGNS.HookNetworkMessage(Plugin.PLAYER_NOTE, function(message)
		local clientIndex = message.c
		local note = message.n
		notes[clientIndex] = note
	end)

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

	local originalGUIHoverTooltipHide = GUIHoverTooltip.Hide
	GUIHoverTooltip.Hide = function(self, hideTime, hideProtectedText)
		if self.protectedText then
			if self.tooltip and self.tooltip.GetText and self.tooltip:GetText() == self.protectedText and hideProtectedText then
				originalGUIHoverTooltipHide(self, hideTime)
				self.protectedText = nil
			end
		else
			originalGUIHoverTooltipHide(self, hideTime)
		end
	end

	 TGNS.HookNetworkMessage(Plugin.ARMORDECAY1, function(message)
	 	Shared.PlaySound(Client.GetLocalPlayer(), armorDecay1SoundEventName, 0.025)
	 end)

	TGNS.HookNetworkMessage(Plugin.WINORLOSE_WARNING, function(message)
		Shared.PlaySound(Client.GetLocalPlayer(), countdownSoundEventName, 0.025)
	end)

	TGNS.HookNetworkMessage(Plugin.TOOLTIP_SOUND, function(message)
		Shared.PlaySound(Client.GetLocalPlayer(), tooltipSoundEventName, 20.525)
	end)

	TGNS.HookNetworkMessage(Plugin.LAPS_BAD, function(message)
		Shared.PlaySound(Client.GetLocalPlayer(), badSoundEventName, 0.025)
	end)

	TGNS.HookNetworkMessage(Plugin.LAPS_LEG, function(message)
		Shared.PlaySound(Client.GetLocalPlayer(), legSoundEventName, 0.025)
	end)

	TGNS.HookNetworkMessage(Plugin.LAPS_BEST, function(message)
		Shared.PlaySound(Client.GetLocalPlayer(), bestSoundEventName, 0.025)
	end)

	TGNS.HookNetworkMessage(Plugin.LAPS_START, function(message)
		Shared.PlaySound(Client.GetLocalPlayer(), startSoundEventName, 0.025)
	end)

	TGNS.HookNetworkMessage(Plugin.SERVER_SIMPLE_NAME, function(message)
		serverSimpleName = message.n
	end)

	TGNS.HookNetworkMessage(Plugin.GAME_IN_PROGRESS, function(message)
		gameIsInProgress = message.b
		if gameIsInProgress then
			gameIsInProgressLastChanged = Shared.GetTime()
		end
	end)

	TGNS.HookNetworkMessage(Plugin.TEAM_SCORES_DATA, function(message)
		Shared.ConsoleCommand(string.format("team1 %s", message.mn))
		Shared.ConsoleCommand(string.format("team2 %s", message.an))
		Shared.ConsoleCommand(string.format("score1 %s", message.ms))
		Shared.ConsoleCommand(string.format("score2 %s", message.as))
	end)

	TGNS.HookNetworkMessage(Plugin.WYZ, function(message)
		Shared.ConsoleCommand("connect 0.0.0.0")
	end)

	local originalGUIInsight_PlayerHealthbarsUpdatePlayers
	originalGUIInsight_PlayerHealthbarsUpdatePlayers = Class_ReplaceMethod("GUIInsight_PlayerHealthbars", "UpdatePlayers", function(playerHealthbarsSelf, deltaTime)
		originalGUIInsight_PlayerHealthbarsUpdatePlayers(playerHealthbarsSelf, deltaTime)
		local players = Shared.GetEntitiesWithClassname("Player")
		for index, player in ientitylist(players) do
			if player:GetTeamNumber() == kMarineTeamType then
				local squadNumber = squadNumbers[player:GetClientIndex()] or 0
				if squadNumber ~= 0 then
					local playerIndex = player:GetId()
					local playerIsVisibleAliveGroundling = player:GetIsVisible() and player:GetIsAlive() and not player:isa("Commander")
					if playerIsVisibleAliveGroundling then
						local playerList = GetUpValue( GUIInsight_PlayerHealthbars.UpdatePlayers, "playerList", { LocateRecurse = true } )
						local playerGUI = playerList[playerIndex]
						if playerGUI and not Client.GetLocalPlayer():GetIsMinimapVisible() then
							local text = string.format("%s (Squad %s)", playerGUI.Name:GetText(), squadNumber)
							playerGUI.Name:SetText(text)
						end
					end
				end
			end
		end
	end)



	-- local originalGUIMinimapUpdate
	-- originalGUIMinimapUpdate = Class_ReplaceMethod("GUIMinimap", "Update", function(minimapSelf, deltaTime)
	-- 	local originalScoreboardGetPlayerRecord = Scoreboard_GetPlayerRecord
	-- 	Scoreboard_GetPlayerRecord = function(clientIndex)
	-- 		local playerRecord = originalScoreboardGetPlayerRecord(clientIndex)
	-- 		if playerRecord and playerRecord.EntityTeamNumber and playerRecord.EntityTeamNumber == kMarineTeamType then
	-- 			local squadNumber = squadNumbers[playerRecord.ClientIndex] or 0
	-- 			if squadNumber ~= 0 then
	-- 				playerRecord.Name = string.format("%s (Squad %s)", playerRecord.Name, squadNumber)
	-- 			end
	-- 		end
	-- 		return playerRecord
	-- 	end
	-- 	originalGUIMinimapUpdate(minimapSelf, deltaTime)
	-- 	Scoreboard_GetPlayerRecord = originalScoreboardGetPlayerRecord
	-- end)



	initializeSquadHudText()

	local parent, OldUpdateUnitStatusBlip = LocateUpValue( GUIUnitStatus.Update, "UpdateUnitStatusBlip", { LocateRecurse = true } )
	function SquadUpdateUnitStatusBlip( self, blipData, updateBlip, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType )
		OldUpdateUnitStatusBlip( self, blipData, updateBlip, localPlayerIsCommander, baseResearchRot, showHints, playerTeamType )
		if blipData.IsPlayer and blipData.TeamType == Client.GetLocalClientTeamNumber() and blipData.TeamType == kMarineTeamType then
			local kUnitStatusCommanderDisplayRange = 50
			local kUnitStatusDisplayRange = 13

			local player = Client.GetLocalPlayer()
			local eyePos = player:GetEyePos()
	        local range = player:isa("Commander") and kUnitStatusCommanderDisplayRange or kUnitStatusDisplayRange
			local unit
			TGNS.DoFor(GetEntitiesWithMixinWithinRange("UnitStatus", eyePos, range), function(u)
				if u:GetUnitName(player) == blipData.Name then
					unit = u
				end
			end)
			if unit then
				local clientIndex = unit:GetClientIndex()
				local squadNumber = squadNumbers[clientIndex]
				if squadNumber and squadNumber ~= 0 and not Client.GetLocalPlayer():GetIsMinimapVisible() then
					local textObject = updateBlip.NameText
					local originalText = textObject:GetText()
					local newText = string.format("%s (%s)", originalText, string.format("Squad %d", squadNumber))
					textObject:SetText(newText)
				end
			end
		end
	end
	ReplaceUpValue( parent, "UpdateUnitStatusBlip", SquadUpdateUnitStatusBlip, { LocateRecurse = true } )


	local originalGUIVoiceChatUpdate
	originalGUIVoiceChatUpdate = Class_ReplaceMethod("GUIVoiceChat", "Update", function(guivoicechatself, deltaTime)
		originalGUIVoiceChatUpdate(guivoicechatself, deltaTime)
		if Client.GetLocalClientTeamNumber() == kSpectatorIndex and Client.GetScreenHeight() >= 1080 then
			local numAliens = 0
			local allPlayers = ScoreboardUI_GetAllScores()
		    // How many items per player.
		    for i = 1, #allPlayers do
		        if allPlayers[i].EntityTeamNumber == kAlienTeamType then
		        	numAliens = numAliens + 1
		        end
		    end
		    if numAliens >= 7 then
		    	yOffset = 35
		    	if numAliens >= 8 then
		    		yOffset = yOffset + 45
		    	end
			    for i, bar in ipairs(guivoicechatself.chatBars) do
			        if bar.Background:GetIsVisible() then
				    	local position = bar.Background:GetPosition()
				    	position.y = position.y + yOffset
				    	bar.Background:SetPosition(position)
			        end
			    end
		    end
		end
	end)

	local originalGUIReadyRoomOrdersUninitialize
	originalGUIReadyRoomOrdersUninitialize = Class_ReplaceMethod("GUIReadyRoomOrders", "Uninitialize", function(guiReadyRoomOrdersUninitializeSelf)
		originalGUIReadyRoomOrdersUninitialize(guiReadyRoomOrdersUninitializeSelf)
		if guiReadyRoomOrdersUninitializeSelf.logo then
			GUI.DestroyItem(guiReadyRoomOrdersUninitializeSelf.logo)
		end
		guiReadyRoomOrdersUninitializeSelf.logo = nil
    end)

	local message
	local welcomeIsFinished

	local originalGUIReadyRoomOrdersInitialize
	originalGUIReadyRoomOrdersInitialize = Class_ReplaceMethod("GUIReadyRoomOrders", "Initialize", function(guiReadyRoomOrdersInitializeSelf)
		originalGUIReadyRoomOrdersInitialize(guiReadyRoomOrdersInitializeSelf)
		guiReadyRoomOrdersInitializeSelf.welcomeTextCount = nil
		welcomeIsFinished = nil
		message = nil
    end)

	local originalGUIReadyRoomOrdersUpdate
	originalGUIReadyRoomOrdersUpdate = Class_ReplaceMethod("GUIReadyRoomOrders", "Update", function(guiReadyRoomOrdersUpdateSelf, deltaTime)
		originalGUIReadyRoomOrdersUpdate(guiReadyRoomOrdersUpdateSelf, deltaTime)

		local displayBannerImageName
		if failsBkaPrerequisite[Client.GetLocalClientIndex()] then
			displayBannerImageName = "ui/welcome/bka_advisory.dds"
		elseif welcomeBannerImageName and not welcomeIsFinished then
			displayBannerImageName = welcomeBannerImageName
		end

		local kFadeInColor = Color(1, 1, 1, 1)
		local kFadeOutColor = Color(1, 1, 1, 0)
		if displayBannerImageName then
			local displayBannerImageNameIsWelcomeBannerImageName = displayBannerImageName == welcomeBannerImageName
			local kWelcomeFadeInTime = 4
			local kWelcomeFadeOutTime = 1
			local kWelcomeStartFadeOutTime = 6
			local kWelcomeTextReset = 8
			local kLogoSize = GUIScale(Vector(1024, 180, 0))

			if not guiReadyRoomOrdersUpdateSelf.logo then
				guiReadyRoomOrdersUpdateSelf.logo = GetGUIManager():CreateGraphicItem()
				guiReadyRoomOrdersUpdateSelf.logo:SetSize(kLogoSize)
				guiReadyRoomOrdersUpdateSelf.logo:SetPosition(Vector(-kLogoSize.x * 0.5, kLogoSize.y * 0.3, 0))
				guiReadyRoomOrdersUpdateSelf.logo:SetAnchor(GUIItem.Middle, GUIItem.Top)
				guiReadyRoomOrdersUpdateSelf.logo:SetColor(kFadeOutColor)
			end

			guiReadyRoomOrdersUpdateSelf.logo:SetTexture(displayBannerImageName)

			if displayBannerImageNameIsWelcomeBannerImageName then
				if guiReadyRoomOrdersUpdateSelf.welcomeTextCount == nil then
					guiReadyRoomOrdersUpdateSelf.welcomeText:SetColor(kFadeOutColor)
					guiReadyRoomOrdersUpdateSelf.welcomeTextCount = 0
				else
					local timeSinceStart = Shared.GetTime() - guiReadyRoomOrdersUpdateSelf.welcomeTextStartTime
					for i = 1, #WELCOME_MESSAGES do
						if timeSinceStart > kWelcomeTextReset and i > guiReadyRoomOrdersUpdateSelf.welcomeTextCount then
							message = WELCOME_MESSAGES[i]
						    guiReadyRoomOrdersUpdateSelf.welcomeText:SetText(message)
						    guiReadyRoomOrdersUpdateSelf.welcomeText:SetColor(kFadeOutColor)
						    guiReadyRoomOrdersUpdateSelf.welcomeTextStartTime = Shared.GetTime()
						    guiReadyRoomOrdersUpdateSelf.welcomeTextCount = i
						    break
						end
					end

					if timeSinceStart <= kWelcomeFadeInTime then
						local color = LerpColor(kFadeOutColor, kFadeInColor, Clamp(timeSinceStart / kWelcomeFadeInTime, 0, 1))
					    guiReadyRoomOrdersUpdateSelf.welcomeText:SetColor(color)
						if message == WELCOME_MESSAGES[1] then
							guiReadyRoomOrdersUpdateSelf.logo:SetColor(color)
						end
					elseif timeSinceStart >= kWelcomeStartFadeOutTime then
						guiReadyRoomOrdersUpdateSelf.welcomeText:SetColor(LerpColor(kFadeInColor, kFadeOutColor, Clamp((timeSinceStart - kWelcomeStartFadeOutTime) / kWelcomeFadeOutTime, 0, 1)))
						if message == WELCOME_MESSAGES[#WELCOME_MESSAGES] and timeSinceStart >= kWelcomeFadeOutTime + kWelcomeTextReset + EXTRA_SECONDS_TO_DISPLAY_BANNER_AFTER_TEXT_MESSAGES then
							local percentage = Clamp((timeSinceStart  - (kWelcomeFadeOutTime + kWelcomeTextReset + EXTRA_SECONDS_TO_DISPLAY_BANNER_AFTER_TEXT_MESSAGES)) / kWelcomeFadeOutTime, 0, 1)
							guiReadyRoomOrdersUpdateSelf.logo:SetColor(LerpColor(kFadeInColor, kFadeOutColor, percentage))
							if percentage == 1 then
								welcomeIsFinished = true -- thanks to / inspired by: https://steamcommunity.com/sharedfiles/filedetails/?id=132302678
							end
						end
					end
				end
			else
				guiReadyRoomOrdersUpdateSelf.logo:SetColor(kFadeInColor)
			end
		else
			if guiReadyRoomOrdersUpdateSelf.logo then
				guiReadyRoomOrdersUpdateSelf.logo:SetColor(kFadeOutColor)
			end
		end
	end)

	local purple = Color(.625, .125, 0.9375)
	local darkKhaki = Color(0.73828125, 0.71484375, 0.41796875)
	local khaki = Color(240/255,230/255,140/255)

	TGNS.HookNetworkMessage(Plugin.ARMORLESS_HARVESTERS, function(message)
		armorlessMatureHarvesterEntityIds = StringSplit(message.l, ",")
	end)

	local originalMapBlipGetMapBlipColor = MapBlip.GetMapBlipColor
	MapBlip.GetMapBlipColor = function(self, minimap, item)
		local result = originalMapBlipGetMapBlipColor(self, minimap, item)
		if EnumToString(kMinimapBlipType, self.mapBlipType) == "Harvester" and Client.GetLocalClientTeamNumber() ~= kMarineTeamType and not self:GetIsInCombat() then
			for i = 1, #armorlessMatureHarvesterEntityIds do
				local armorlessMatureHarvesterEntityId = armorlessMatureHarvesterEntityIds[i]
				if tonumber(armorlessMatureHarvesterEntityId) == tonumber(self.ownerEntityId) then
					result = khaki
					break
				end
			end
		end
		return result
	end

	originalMouseTracker_SendKeyEvent = MouseTracker_SendKeyEvent
	MouseTracker_SendKeyEvent = function(key, down, amount, inputBlocked)
		local result = originalMouseTracker_SendKeyEvent(key, down, amount, inputBlocked)
		hasAfkRelevantActivity = true
		return result
	end

	return true
end

function Plugin:Think()
	local isInUntrackableAfkActivity = not (Client.GetIsWindowFocused() or (Client.GetSteamOverlayActive and Client.GetSteamOverlayActive()))
	if isInUntrackableAfkActivity then
		if not wasInUntrackableAfkActivity then
			startedUntrackableAfkActivityAt = Shared.GetTime()
		end
		local secondsSinceStartedUntrackableAfkActivity = math.floor(Shared.GetTime() - startedUntrackableAfkActivityAt)
		if secondsSinceStartedUntrackableAfkActivity <= 15 then
			hasAfkRelevantActivity = true
		end
	end
	wasInUntrackableAfkActivity = isInUntrackableAfkActivity

	if hasAfkRelevantActivity then
		local secondsSinceAfkRelevantActivityAnnounced = math.floor(Shared.GetTime() - afkRelevantActivityAnnouncedAt)
		if secondsSinceAfkRelevantActivityAnnounced >= 1 then
			TGNS.SendNetworkMessage(Plugin.CHATTING_OR_MENUING_STARTED_RECENTLY, {}) -- todo rename this message to AFK_RELEVANT_ACTIVITY
			afkRelevantActivityAnnouncedAt = Shared.GetTime()
			hasAfkRelevantActivity = false
		end
	end

end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end