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

local function prependPlayerName(playerName, text)
	if text and string.len(text) then
		return string.sub(text .. " " .. playerName, 0, kMaxNameLength)
	end
	return playerName
end

local originalBuildScoresMessage = BuildScoresMessage

function BuildScoresMessage(scorePlayer, sendToPlayer)
	local t = originalBuildScoresMessage(scorePlayer, sendToPlayer)

	local match = false
	local client = Server.GetOwner(scorePlayer)
	if client and t and t.playerName then
		if TGNS.IsPlayerAFK(scorePlayer) and PlayerCanSeeAfkStatus(scorePlayer, sendToPlayer) then
			t.playerName = prependPlayerName(t.playerName, DAK.config.scoreboardicons.AFK)
		else
			local groupIcons = DAK.config.scoreboardicons.GroupIcons
			table.sort(groupIcons, function(t1, t2) return t1.sort < t2.sort end)
			for _, groupicon in ipairs(groupIcons) do
				if TGNS.ClientIsInGroup(client, groupicon.group) then
					t.playerName = prependPlayerName(t.playerName, groupicon.icon)
					match = true
					break
				end
			end
			if not match then
				t.playerName = prependPlayerName(t.playerName, DAK.config.scoreboardicons.CatchAll)
			end
		end
	end
	
	return t
end