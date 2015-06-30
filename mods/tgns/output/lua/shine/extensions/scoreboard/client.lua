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
local badgeLabels = {}
local vrConfirmed = {}
local countdownSoundEventName = "sound/tgns.fev/winorlose/countdown"
local approveSoundEventName = "sound/tgns.fev/scoreboard/approve"
local badSoundEventName = "sound/tgns.fev/laps/bad"
local legSoundEventName = "sound/tgns.fev/laps/leg"
local bestSoundEventName = "sound/tgns.fev/laps/best"
local startSoundEventName = "sound/tgns.fev/laps/start"
local gameIsInProgress = false
local serverSimpleName
local squadNumbers={}
local squadNumbersHudText
local squadNumberLastSetTimes = {}

local CaptainsCaptainFontColor = Color(0, 1, 0, 1)

TGNS.HookNetworkMessage(Shine.Plugins.scoreboard.SCOREBOARD_DATA, function(message)
	prefixes[message.i] = message.p
	isCaptainsCaptain[message.i] = message.c
end)

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
	Client.PrecacheLocalSound(approveSoundEventName)
	Client.PrecacheLocalSound(badSoundEventName)
	Client.PrecacheLocalSound(legSoundEventName)
	Client.PrecacheLocalSound(bestSoundEventName)
	Client.PrecacheLocalSound(startSoundEventName)

	local originalGUIScoreboardUpdate = GUIScoreboard.Update
	GUIScoreboard.Update = function(self, deltaTime)
		originalGUIScoreboardUpdate(self, deltaTime)

		for index, team in ipairs(self.teams) do
	        if self.visible then
	            self:UpdateTeam(team)
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
	        	{n="PlayerSquadIcon",t=SQUAD_TEXTURE_DISABLED,x=-25}
	        	,{n="PlayerApproveIcon",t=APPROVE_TEXTURE_DISABLED,x=-49}
	        	,{n="PlayerQueryIcon",t=QUERY_TEXTURE_DISABLED,x=-69}
	        	,{n="PlayerVrIcon",t=VR_TEXTURE_DISABLED,x=-89}

	    	}

			TGNS.DoFor(icons, function(i)
				if not player[i.n] then
				    local icon = GUIManager:CreateGraphicItem()
				    local position = player.Status:GetPosition()
				    position.x = position.x + i.x
				    position.y = position.y + (i.y or -10)
				    icon:SetSize(Vector(20, 20, 0))
				    icon:SetAnchor(GUIItem.Left, GUIItem.Center)
				    icon:SetPosition(position)
				    icon:SetTexture(i.t)
				    player[i.n] = icon
				    player.Background:AddChild(icon)
				    if player.IconTable then
				    	table.insert(player["IconTable"], icon)
				    end
				end
			end)	    	

			if not player.PlayerNoteItem then
				local playerNoteItem = GUIManager:CreateTextItem()
				playerNoteItem:SetFontName(GUIScoreboard.kTeamInfoFontName)
				playerNoteItem:SetAnchor(GUIItem.Left, GUIItem.Top)
				playerNoteItem:SetTextAlignmentX(GUIItem.Align_Max)
				playerNoteItem:SetTextAlignmentY(GUIItem.Align_Min)
				player.PlayerNoteItem = playerNoteItem
				player.Background:AddChild(playerNoteItem)
			end


			local guiItemsWhichShouldPreventNs2PlusHighlight = {}
			local playerIsBot = playerRecord.Ping == 0

	        local playerApproveIcon = player["PlayerApproveIcon"]



	        local playerSquadIconShouldDisplay = (teamNumber == kMarineTeamType or teamNumber == kAlienTeamType) and ((teamNumber == Client.GetLocalClientTeamNumber()) or (PlayerUI_GetIsSpecating() and Client.GetLocalClientTeamNumber() ~= kMarineTeamType and Client.GetLocalClientTeamNumber() ~= kAlienTeamType)) and not playerIsBot
	        local playerApproveIconShouldDisplay = ((clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals)
	        local playerQueryIconShouldDisplay = ((clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals)
	        local playerVrIconShouldDisplay = (((Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (teamNumber == Client.GetLocalClientTeamNumber())) and (clientIndex ~= Client.GetLocalClientIndex()) and (not playerIsBot) and showOptionals)
        	local playerNoteItemShouldDisplay = (teamNumber == kMarineTeamType or teamNumber == kAlienTeamType) and ((teamNumber == Client.GetLocalClientTeamNumber()) or (PlayerUI_GetIsSpecating() and Client.GetLocalClientTeamNumber() ~= kMarineTeamType and Client.GetLocalClientTeamNumber() ~= kAlienTeamType))
        	local playerApproveStatusItemShouldDisplay = (clientIndex == Client.GetLocalClientIndex() and showOptionals)

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
	        	playerApproveStatusItemShouldDisplay = true
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

			playerNoteItemPosition.x = playerNoteItemPosition.x - xOffset - 5
		    playerNoteItemPosition.y = playerNoteItemPosition.y + 7
			player.PlayerNoteItem:SetPosition(playerNoteItemPosition)

	        if playerApproveIcon then
	        	table.insert(guiItemsWhichShouldPreventNs2PlusHighlight, playerApproveIcon)
	        	playerApproveIcon:SetIsVisible(playerApproveIconShouldDisplay)
		        playerApproveIcon:SetTexture(isApproved[clientIndex] and APPROVE_TEXTURE_DISABLED or getTeamApproveTexture(teamNumber))
	        end
	        local playerVrIcon = player["PlayerVrIcon"]
	        if playerVrIcon then
	        	table.insert(guiItemsWhichShouldPreventNs2PlusHighlight, playerVrIcon)
	        	playerVrIcon:SetIsVisible(playerVrIconShouldDisplay)
	        	local playerVrIconShouldBeDisabled = isVring or (Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (TGNS.Contains(targetPrefix, "!") and not vrConfirmed[clientIndex])
		        playerVrIcon:SetTexture(playerVrIconShouldBeDisabled and getDisabledVrTexture(clientIndex) or getTeamVrTexture(clientIndex, teamNumber))
	        end
	        local playerQueryIcon = player["PlayerQueryIcon"]
	        if playerQueryIcon then
	        	table.insert(guiItemsWhichShouldPreventNs2PlusHighlight, playerQueryIcon)
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
	        	table.insert(guiItemsWhichShouldPreventNs2PlusHighlight, playerApproveStatusItem)
	        	playerApproveStatusItem:SetIsVisible(playerApproveStatusItemShouldDisplay)
	        	playerApproveStatusItem:SetText(tostring(approveSentTotal) .. ":" .. tostring(approveReceivedTotal))
	        	playerApproveStatusItem:SetColor(color)
	        end

	        local playerNoteItem = player["PlayerNoteItem"]
	        if playerNoteItem then
	        	playerNoteItem:SetIsVisible(playerNoteItemShouldDisplay)
	        	playerNoteItem:SetText(string.format("%s", notes[clientIndex] and notes[clientIndex] or ""))
	        	playerNoteItem:SetColor(color)
	        end
	        local playerSquadIcon = player["PlayerSquadIcon"]
	        if playerSquadIcon then
	        	table.insert(guiItemsWhichShouldPreventNs2PlusHighlight, playerSquadIcon)
	        	playerSquadIcon:SetIsVisible(playerSquadIconShouldDisplay)
	        	local playerSquadIconShouldBeDisabled = isSquading or (Client.GetLocalClientTeamNumber() == kSpectatorIndex) or gameIsInProgress
		        playerSquadIcon:SetTexture(getTeamSquadTexture(clientIndex, teamNumber, playerSquadIconShouldBeDisabled))
	        end

			if MouseTracker_GetIsVisible() then
				local mouseX, mouseY = Client.GetCursorPosScreen()
				for i = 1, #guiItemsWhichShouldPreventNs2PlusHighlight do
					local guiItem = guiItemsWhichShouldPreventNs2PlusHighlight[i]
					if GUIItemContainsPoint(guiItem, mouseX, mouseY) and guiItem:GetIsVisible() then
						player["Background"]:SetColor(updateTeam["Color"])
						break
					end
				end
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
		            local playerVrIconShouldBeDisabled = isVring or (Client.GetLocalClientTeamNumber() == kSpectatorIndex)
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
		            local playerSquadIconShouldBeDisabled = isSquading or (Client.GetLocalClientTeamNumber() == kSpectatorIndex) or (Client.GetLocalClientTeamNumber() == kAlienTeamType and gameIsInProgress)
		            if playerSquadIcon and playerSquadIcon:GetIsVisible() and GUIItemContainsPoint(playerSquadIcon, mouseX, mouseY) then
		            	local squadNumberDelta = self.MovementModifierIsPressed and -1 or 1
		            	if self.hoverMenu then
		            		self.hoverMenu:Hide()
		            	end
		            	if (not playerSquadIconShouldBeDisabled) or (Client.GetLocalClientTeamNumber() == kAlienTeamType and not isSquading) then
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
	TGNS.HookNetworkMessage(Plugin.APPROVE_ALREADY_APPROVED, function(message)
		isApproved[message.c] = true
	end)
	TGNS.HookNetworkMessage(Plugin.VR_CONFIRMED, function(message)
		vrConfirmed[message.c] = true
	end)
	TGNS.HookNetworkMessage(Plugin.SQUAD_CONFIRMED, function(message)
		squadNumberLastSetTimes[message.c] = Shared.GetTime()
		squadNumbers[message.c] = message.s
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
	end)

	TGNS.HookNetworkMessage(Plugin.ALERT_ICON, function(message)
		if Client.WindowNeedsAttention then
			Client.WindowNeedsAttention()
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



	local originalGUIMinimapUpdate
	originalGUIMinimapUpdate = Class_ReplaceMethod("GUIMinimap", "Update", function(minimapSelf, deltaTime)
		local originalScoreboardGetPlayerRecord = Scoreboard_GetPlayerRecord
		Scoreboard_GetPlayerRecord = function(clientIndex)
			local playerRecord = originalScoreboardGetPlayerRecord(clientIndex)
			if playerRecord and playerRecord.EntityTeamNumber and playerRecord.EntityTeamNumber == kMarineTeamType then
				local squadNumber = squadNumbers[playerRecord.ClientIndex] or 0
				if squadNumber ~= 0 then
					playerRecord.Name = string.format("%s (Squad %s)", playerRecord.Name, squadNumber)
				end
			end
			return playerRecord
		end
		originalGUIMinimapUpdate(minimapSelf, deltaTime)
		Scoreboard_GetPlayerRecord = originalScoreboardGetPlayerRecord
	end)



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

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end