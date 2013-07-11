Script.Load("lua/TGNSCommon.lua")

local changers = {}

TGNSScoreboardMessageChanger = {}
TGNSScoreboardMessageChanger.Priority = {}
TGNSScoreboardMessageChanger.Priority.HIGHEST = 1
TGNSScoreboardMessageChanger.Priority.VERY_HIGH = 2
TGNSScoreboardMessageChanger.Priority.NORMAL = 3
TGNSScoreboardMessageChanger.Priority.VERY_LOW = 4
TGNSScoreboardMessageChanger.Priority.LOWEST = 5

local originalBuildScoresMessage = BuildScoresMessage

function BuildScoresMessage(scorePlayer, sendToPlayer)
	local scoresMessage = originalBuildScoresMessage(scorePlayer, sendToPlayer) // see lua/NetworkMessages.lua:BuildScoresMessage
	TGNS.DoFor(changers, function(c)
		c.func(scorePlayer, sendToPlayer, scoresMessage)
	end)
	return scoresMessage
end

TGNSScoreboardMessageChanger.Add = function(priority, changerAction)
	table.insert(changers, { func = changerAction, p = priority })
	TGNS.SortAscending(changers, function(c) return c.p end)
end
