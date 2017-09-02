local Plugin = Plugin

local hudTexts = {}
local squadNumberLastSetTimes = {}
local squadNumbers = {}
local gameState = {}
gameState.gameIsInProgressLastSetToTrue = 0
gameState.gameIsInProgressLastSetToFalse = 0
gameState.gameIsInProgress = false

TGNS.HookNetworkMessage(Plugin.GAME_IN_PROGRESS, function(message)
	gameState.gameIsInProgress = message.b
	if gameState.gameIsInProgress then
		gameState.gameIsInProgressLastSetToTrue = Shared.GetTime()
	else
		gameState.gameIsInProgressLastSetToFalse = Shared.GetTime()
		TGNS.DoFor(CHUDOptionsToDisableDuringWinOrLose, function(key)
			if CHUDOptions and CHUDOptions[key] then
				CHUDOptions[key].disabled = false
			end
		end)
		tunnelDescriptions = {}
	end
end)

TGNS.HookNetworkMessage(Plugin.SQUAD_CONFIRMED, function(message)
	squadNumberLastSetTimes[message.c] = Shared.GetTime()
	squadNumbers[message.c] = message.s
end)

function hudTexts.initializeSquadHudText()
	if hudTexts.squadNumbersHudText then
		hudTexts.squadNumbersHudText:Remove()
	end
	hudTexts.squadNumbersHudText = Shine.ScreenText.Add( "Squad", {
		X = 0.04, Y = 0.61,
		Text = "",
		Duration = math.huge,
		R = 255, G = 255, B = 255,
		Alignment = 2,
		Size = 2,
		FadeIn = 0.5
	} )

function hudTexts.squadNumbersHudText:UpdateText()
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

function hudTexts.initializeAlienLifeformsHudText()
	local updateAlienLifeformsReviewHudText = function(textObj, title, commanderCountPredicate, onosCountPredicate, fadeCountPredicate, lerkCountPredicate, gorgeCountPredicate, skulkCountPredicate, noPlansCountPredicate, footerPredicate)
		local text = ""
		if not gameState.gameIsInProgress and Shared.GetTime() - gameState.gameIsInProgressLastSetToFalse > TGNS.ENDGAME_TIME_TO_READYROOM + 1 then
			local playerIsAlien = Client.GetLocalClientTeamNumber() == kAlienTeamType
			local playerIsCommander = Scoreboard_GetPlayerData(Client.GetLocalClientIndex(), "IsCommander")
			if playerIsAlien then
				local commanderNames = {}
				local onosNames = {}
				local fadeNames = {}
				local lerkNames = {}
				local gorgeNames = {}
				local skulkNames = {}
				local noPlansNames = {}
				TGNS.DoForPairs(squadNumbers, function(clientIndex, squadNumber)
					local teamNumber = Scoreboard_GetPlayerData(clientIndex, "EntityTeamNumber")
					if teamNumber == kAlienTeamType then
						local playerName = Scoreboard_GetPlayerData(clientIndex, "Name")
						if squadNumber == 6 then
							table.insert(commanderNames, playerName)
						elseif squadNumber == 5 then
							table.insert(onosNames, playerName)
						elseif squadNumber == 4 then
							table.insert(fadeNames, playerName)
						elseif squadNumber == 3 then
							table.insert(lerkNames, playerName)
						elseif squadNumber == 2 then
							table.insert(gorgeNames, playerName)
						elseif squadNumber == 1 then
							table.insert(skulkNames, playerName)
						elseif squadNumber == 0 then
							table.insert(noPlansNames, playerName)
						end
					end
				end)
				local getNamesDisplay = function(names)
					local result = ""
					if #names >= 1 then
						local namesToDisplay = TGNS.Take(names, 3)
						if #names > 3 then
							table.insert(namesToDisplay, "...")
						end
						result = string.format("(%s)", TGNS.Join(TGNS.Select(namesToDisplay, function(n) return TGNS.Truncate(n, 3) end), ", "))
					end
					return result
				end

				local lines = {}
				table.insert(lines, title)
				table.insert(lines, commanderCountPredicate(#commanderNames) and string.format("%sx Commander %s", #commanderNames, getNamesDisplay(commanderNames)) or "")
				table.insert(lines, onosCountPredicate(#onosNames) and string.format("%sx Onos %s", #onosNames, getNamesDisplay(onosNames)) or "")
				table.insert(lines, fadeCountPredicate(#fadeNames) and string.format("%sx Fade %s", #fadeNames, getNamesDisplay(fadeNames)) or "")
				table.insert(lines, lerkCountPredicate(#lerkNames) and string.format("%sx Lerk %s", #lerkNames, getNamesDisplay(lerkNames)) or "")
				table.insert(lines, gorgeCountPredicate(#gorgeNames) and string.format("%sx Gorge %s", #gorgeNames, getNamesDisplay(gorgeNames)) or "")
				table.insert(lines, skulkCountPredicate(#skulkNames) and string.format("%sx Skulk/Wildcard %s", #skulkNames, getNamesDisplay(skulkNames)) or "")
				table.insert(lines, noPlansCountPredicate(#noPlansNames) and string.format("%sx ??? %s", #noPlansNames, getNamesDisplay(noPlansNames)) or "")
				if math.floor(Shared.GetTime()) % 2 == 0 then
					table.insert(lines, footerPredicate() and "Click your scoreboard row's circle to choose." or "")
				end

				text = TGNS.Join(lines, "\n")
			end
		end
		textObj:SetText(text)
	end

	if hudTexts.alienLifeformsReviewHudText1 then
		hudTexts.alienLifeformsReviewHudText1:Remove()
	end
	if hudTexts.alienLifeformsReviewHudText2 then
		hudTexts.alienLifeformsReviewHudText2:Remove()
	end
	hudTexts.alienLifeformsReviewHudText1 = Shine.ScreenText.Add( "AlienLifeformsReviewHudText1", {
		X = 0.70, Y = 0.35,
		Text = "",
		Duration = math.huge,
		R = 218, G = 165, B = 31,
		Alignment = TGNS.ShineTextAlignmentMin,
		Size = 2,
		FadeIn = 0
	} )
	hudTexts.alienLifeformsReviewHudText2 = Shine.ScreenText.Add( "AlienLifeformsReviewHudText2", {
		X = 0.70, Y = 0.35,
		Text = "",
		Duration = math.huge,
		R = 255, G = 0, B = 0,
		Alignment = TGNS.ShineTextAlignmentMin,
		Size = 2,
		FadeIn = 0
	} )

	local commanderCountPredicate1 = function(count) return count == 1 end
	local onosCountPredicate1 = function(count) return count > 0 end
	local fadeCountPredicate1 = function(count) return count > 0 end
	local lerkCountPredicate1 = function(count) return count > 0 end
	local gorgeCountPredicate1 = function(count) return count > 0 end
	local skulkCountPredicate1 = function(count) return true end
	local noPlansCountPredicate1 = function(count) return false end
	local footerPredicate1 = function() return false end

	local commanderCountPredicate2 = function(count) return count ~= 1 end
	local onosCountPredicate2 = function(count) return count == 0 end
	local fadeCountPredicate2 = function(count) return count == 0 end
	local lerkCountPredicate2 = function(count) return count == 0 end
	local gorgeCountPredicate2 = function(count) return count == 0 end
	local skulkCountPredicate2 = function(count) return false end
	local noPlansCountPredicate2 = function(count) return count > 0 end
	local footerPredicate2 = function() return (squadNumbers[Client.GetLocalClientIndex()] or 0) == 0 end

	function hudTexts.alienLifeformsReviewHudText1:UpdateText()
		updateAlienLifeformsReviewHudText(self.Obj, "Planned Roles:", commanderCountPredicate1, onosCountPredicate1, fadeCountPredicate1, lerkCountPredicate1, gorgeCountPredicate1, skulkCountPredicate1, noPlansCountPredicate1, footerPredicate1)
	end
	function hudTexts.alienLifeformsReviewHudText2:UpdateText()
		updateAlienLifeformsReviewHudText(self.Obj, "", commanderCountPredicate2, onosCountPredicate2, fadeCountPredicate2, lerkCountPredicate2, gorgeCountPredicate2, skulkCountPredicate2, noPlansCountPredicate2, footerPredicate2)
	end
end

function hudTexts.initializeSkillImbalanceHudText()
	if hudTexts.skillImbalanceHudText then
		hudTexts.skillImbalanceHudText:Remove()
	end
	hudTexts.skillImbalanceHudText = Shine.ScreenText.Add( "SkillImbalanceHudText", {
		X = 0.2, Y = 0.35,
		Text = "",
		Duration = math.huge,
		R = 0, G = 165, B = 0,
		Alignment = TGNS.ShineTextAlignmentCenter,
		Size = 2,
		FadeIn = 0
	} )

function hudTexts.skillImbalanceHudText:UpdateText()
		local text = ""
		if Shine.GetGamemode() == "ns2" and not captainsEnabled and not gameState.gameIsInProgress and not gameState.gameIsInCountdown and Shared.GetTime() - gameState.gameIsInProgressLastSetToFalse > TGNS.ENDGAME_TIME_TO_READYROOM + 1 and (Client.GetLocalClientTeamNumber() == kAlienTeamType or Client.GetLocalClientTeamNumber() == kMarineTeamType) then
			text = string.format("Chat 'switch' if you want to play %s.\n\nIf you see skill imbalance pre-game:\nChat 'swap' to learn how to help.\n\nDon't complain about teams. See above.", Client.GetLocalClientTeamNumber() == kAlienTeamType and "Marines" or "Aliens")
		end
		self.Obj:SetText(text)
	end
end

function Plugin:OnResolutionChanged( OldX, OldY, NewX, NewY )
	hudTexts.initializeSquadHudText()
	hudTexts.initializeAlienLifeformsHudText()
	hudTexts.initializeSkillImbalanceHudText()
end

function Plugin:Initialise()
	self.Enabled = true

	hudTexts.initializeSquadHudText()
	hudTexts.initializeAlienLifeformsHudText()
	hudTexts.initializeSkillImbalanceHudText()

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end