local Plugin = Plugin

-- TGNS.HookNetworkMessage(Plugin.FOO, function(message)
-- end)

-- function Plugin:Foo()
-- end

local DEFAULT_WINRATE = .5
local teamWinRates = {}
teamWinRates[kMarineTeamType] = {}
teamWinRates[kAlienTeamType] = {}

TGNS.HookNetworkMessage(Shine.Plugins.pregamescoreboardsort.WINRATE, function(message)
	teamWinRates[kMarineTeamType][message.i] = message.m
	teamWinRates[kAlienTeamType][message.i] = message.a
end)

local function sortIsActive()
	return TGNS.Has({kGameState.NotStarted,kGameState.WarmUp,kGameState.PreGame}, TGNS.GetGameState()) and TGNS.Has({kMarineTeamType,kAlienTeamType}, Client.GetLocalClientTeamNumber())
end

function Plugin:Initialise()
	self.Enabled = true
	local originalGetScoreData = GetScoreData
	GetScoreData = function(teamNumberTable)
		local result = originalGetScoreData(teamNumberTable)
		
		if sortIsActive() then
			TGNS.SortDescending(result, function(s)
				local sortWeight = TGNS.Has({kMarineTeamType,kAlienTeamType}, s.EntityTeamNumber) and (teamWinRates[s.EntityTeamNumber] and teamWinRates[s.EntityTeamNumber][s.ClientIndex] or DEFAULT_WINRATE) or 50000
				return sortWeight
			end)
		end
		return result
	end

local originalGUIScoreboardUpdateTeam = GUIScoreboard.UpdateTeam
	GUIScoreboard.UpdateTeam = function(self, updateTeam)
		originalGUIScoreboardUpdateTeam(self, updateTeam)
		local teamNumber = updateTeam["TeamNumber"]
		if sortIsActive() and TGNS.Has({kMarineTeamType,kAlienTeamType}, teamNumber) and #updateTeam["PlayerList"] > 1 then
		    local teamNameGUIItem = updateTeam["GUIs"]["TeamName"]
		    local teamNameGUIItemText = teamNameGUIItem:GetText()
			local truncatedTeamNameGUIItemText = string.sub(teamNameGUIItemText, 1, string.len(teamNameGUIItemText) - 1)
		    local teamHeaderText = string.format("%s, swap-sorted)", truncatedTeamNameGUIItemText)
		    teamNameGUIItem:SetText(teamHeaderText)
		end
	end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end