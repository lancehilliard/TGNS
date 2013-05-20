Script.Load("lua/TGNSCommon.lua")

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

local originalBuildScoresMessage = BuildScoresMessage

function BuildScoresMessage(scorePlayer, sendToPlayer)
	local t = originalBuildScoresMessage(scorePlayer, sendToPlayer)

	local client = Server.GetOwner(scorePlayer)
	if client and t and t.playerName then
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
		t.playerName = prependPlayerName(t.playerName, icon)
	end
	
	return t
end