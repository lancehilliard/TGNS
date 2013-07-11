Script.Load("lua/TGNSCommon.lua")
Script.Load("lua/TGNSScoreboardMessageChanger.lua")

local function PlayerCanSeeAfkStatus(scorePlayer, sendToPlayer)
	local result = false
	if scorePlayer ~= nil and sendToPlayer ~= nil then
	end
		local sendToPlayerCanKickAfkPlayers = TGNS.ClientAction(sendToPlayer, function(c)
				local playerIsAdmin = TGNS.IsClientAdmin(c)
				local playerIsTempAdmin = TGNS.IsClientTempAdmin(c)
				return playerIsAdmin or playerIsTempAdmin
			end
		)
		local sameTeams = TGNS.PlayersAreTeammates(scorePlayer, sendToPlayer)
		result = sameTeams or sendToPlayerCanKickAfkPlayers
	return result
end

local function prependPlayerName(playerName, icon)
	if icon and string.len(icon) then
		return string.sub(icon .. "> " .. playerName, 0, kMaxNameLength)
	end
	return playerName
end

TGNSScoreboardMessageChanger.Add(TGNSScoreboardMessageChanger.Priority.HIGHEST, function(scorePlayer, sendToPlayer, scoresMessage)
	local client = TGNS.GetClient(scorePlayer)
	if client and scoresMessage and scoresMessage.playerName then
		local groupIcons = DAK.config.scoreboardicons.GroupIcons
		table.sort(groupIcons, function(t1, t2) return t1.sort < t2.sort end)
		local icon
		for _, groupicon in ipairs(groupIcons) do
			if TGNS.ClientIsInGroup(client, groupicon.group) then
				icon = groupicon.icon
				break
			end
		end
		if icon == nil then
			icon = DAK.config.scoreboardicons.CatchAll
		end
		if TGNS.IsPlayerAFK(scorePlayer) and PlayerCanSeeAfkStatus(scorePlayer, sendToPlayer) then
			icon = icon .. DAK.config.scoreboardicons.AFK
		end
		if TGNS.IsClientSM(client) then
			icon = string.upper(icon)
		end
		scoresMessage.playerName = prependPlayerName(scoresMessage.playerName, icon)
	end
end)