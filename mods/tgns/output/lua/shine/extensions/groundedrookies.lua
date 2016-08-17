--local notifiedPlayerIds = {}
local md = TGNSMessageDisplayer.Create()

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true

    local restrictions = {
    	{advisory=function(playerName, teamName) return string.format("Rookies with fewer than 20 TGNS games may not command. %s: help %s fight from the ground!", teamName, playerName) end, test=function(player, numberOfAliveTeammates) 
    		return TGNS.PlayerIsRookie(player) and Balance.GetTotalGamesPlayed(TGNS.GetClient(player)) < 20
    	end},
    	{advisory=function(playerName, teamName) return string.format("Commanders must be voicecomm vouched when 3+ Primer signer teammates. %s: can anyone vouch %s?", teamName, playerName) end, test=function(player, numberOfAliveTeammates)
    		local client = TGNS.GetClient(player)
    		return #TGNS.Where(TGNS.GetClients(TGNS.GetPlayersOnSameTeam(player)), TGNS.HasClientSignedPrimerWithGames) >= 3 and not (Shine.Plugins.scoreboard:IsVouched(client) or TGNS.HasClientSignedPrimer(client))
    	end}
    }

	local originalGetIsPlayerValidForCommander
	originalGetIsPlayerValidForCommander = TGNS.ReplaceClassMethod("CommandStructure", "GetIsPlayerValidForCommander", function(self, player)
		local result = originalGetIsPlayerValidForCommander(self, player)
		if result and not Shine.Plugins.communityslots:IsClientRecentCommander(TGNS.GetClient(player)) then
			local playerShouldBePreventedFromCommanding
			local numberOfAliveTeammates = #TGNS.Where(TGNS.GetPlayersOnSameTeam(player), TGNS.IsPlayerAlive)
			if ((not TGNS.IsGameInProgress()) or (numberOfAliveTeammates > 2)) and Shine.Plugins.bots:GetTotalNumberOfBots() == 0 then
				TGNS.DoFor(restrictions, function(restriction)
					playerShouldBePreventedFromCommanding = restriction.test(player, playerName, numberOfAliveTeammates)
					if playerShouldBePreventedFromCommanding then
						local playerName = TGNS.GetPlayerName(player)
						local teamName = TGNS.GetPlayerTeamName(player)
						md:ToTeamNotifyError(TGNS.GetPlayerTeamNumber(player), string.format("%s: %s", playerName, restriction.advisory(playerName, teamName)))
						return playerShouldBePreventedFromCommanding
					end
				end)
			end
			result = not playerShouldBePreventedFromCommanding
		end
		return result
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("groundedrookies", Plugin )