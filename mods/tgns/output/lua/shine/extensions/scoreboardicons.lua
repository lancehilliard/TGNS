local function PlayerCanSeeAfkStatus(scorePlayer, sendToPlayer)
	local result = false
	if scorePlayer ~= nil and sendToPlayer ~= nil then
	end
		local sendToPlayerCanKickAfkPlayers = TGNS.ClientAction(sendToPlayer, function(c)
				local playerIsAdmin = TGNS.IsClientAdmin(c)
				local playerIsGuardian = TGNS.IsClientGuardian(c)
				return playerIsAdmin or playerIsGuardian
			end
		)
		local sameTeams = TGNS.PlayersAreTeammates(scorePlayer, sendToPlayer)
		result = sameTeams or sendToPlayerCanKickAfkPlayers
	return result
end

local function prependPlayerName(playerName, icon)
	if TGNS.HasNonEmptyValue(icon) then
		return string.sub(icon .. "> " .. playerName, 0, kMaxNameLength)
	end
	return playerName
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "scoreboardicons.json"

function Plugin:Initialise()
    self.Enabled = true
	TGNSScoreboardMessageChanger.Add(TGNSScoreboardMessageChanger.Priority.HIGHEST, function(scorePlayer, sendToPlayer, scoresMessage)
		local client = TGNS.GetClient(scorePlayer)
		if client and scoresMessage and scoresMessage.playerName then
			local groupIcons = Shine.Plugins.scoreboardicons.Config.GroupIcons
			table.sort(groupIcons, function(t1, t2) return t1.sort < t2.sort end)
			local icon
			for _, groupicon in ipairs(groupIcons) do
				if TGNS.ClientIsInGroup(client, groupicon.group) then
					icon = groupicon.icon
					break
				end
			end
			if icon == nil then
				icon = Shine.Plugins.scoreboardicons.Config.CatchAll
			end
			if TGNS.IsPlayerAFK(scorePlayer) and PlayerCanSeeAfkStatus(scorePlayer, sendToPlayer) then
				icon = icon .. Shine.Plugins.scoreboardicons.Config.AFK
			end
			scoresMessage.playerName = prependPlayerName(scoresMessage.playerName, icon)
		end
	end)
	TGNS.RegisterEventHook("AfkChanged", function(player, playerIsAfk)
		TGNS.UpdateAllScoreboards()
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("scoreboardicons", Plugin )