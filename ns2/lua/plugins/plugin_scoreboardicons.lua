// Scoreboard Icons
if kDAKConfig and kDAKConfig.ScoreboardIcons then
	Script.Load("lua/TGNSCommon.lua")

	local originalBuildScoresMessage = BuildScoresMessage

	function BuildScoresMessage(scorePlayer, sendToPlayer)
		local t = originalBuildScoresMessage(scorePlayer, sendToPlayer)

		local label = ""
		local client = Server.GetOwner(scorePlayer)
		if client and t and t.playerName then
			for group, icon in pairs(kDAKConfig.ScoreboardIcons.GroupIcons) do
				if DAKGetClientIsInGroup(client, group) then
					t.playerName = string.sub(icon .. " " .. t.playerName, 0, kMaxNameLength)
					break
				end
			end
		end
		return t
	end

end

Shared.Message("Scoreboard Icons Loading Complete")
