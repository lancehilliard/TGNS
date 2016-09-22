--local notifiedPlayerIds = {}
local md = TGNSMessageDisplayer.Create()
local exemptRookies = {}

local Plugin = {}

function Plugin:CreateCommands()
	local exemptCommand = self:BindCommand( "sh_letrookiecommand", nil, function(client, playerPredicate)
		local player = TGNS.GetPlayer(client)
		if playerPredicate == nil or playerPredicate == "" then
			md:ToPlayerNotifyError(player, "You must specify a player.")
		else
			local targetPlayer = TGNS.GetPlayerMatching(playerPredicate, nil)
			if targetPlayer ~= nil then
				local targetClient = TGNS.GetClient(targetPlayer)
				if targetClient then
					if TGNS.PlayerIsRookie(targetPlayer) then
						exemptRookies[targetClient] = true
						md:ToPlayerNotifyInfo(player, string.format("%s may command.", TGNS.GetClientName(targetClient)))
					else
						md:ToPlayerNotifyError(player, string.format("%s is not a Rookie.", TGNS.GetClientName(targetClient)))
					end
				else
					md:ToPlayerNotifyError(player, string.format("Error locating %s client.", TGNS.GetPlayerName(targetPlayer)))
				end
			else
				md:ToPlayerNotifyError(player, string.format("'%s' does not uniquely match a player.", playerPredicate))
			end
		end
	end, true)
	exemptCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	exemptCommand:Help( "<player> Allow player to command." )
end

function Plugin:Initialise()
    self.Enabled = true

    local restrictions = {
    	{advisory=function(playerName, teamName) return string.format("Rookies with fewer than 20 TGNS games may not command. %s: help %s fight from the ground!", teamName, playerName) end, test=function(player, numberOfAliveTeammates) 
    		local client = TGNS.GetClient(player)
    		local playerIsExempt = client and exemptRookies[client] or false
    		return (TGNS.PlayerIsRookie(player) and not playerIsExempt) and Balance.GetTotalGamesPlayed(TGNS.GetClient(player)) < 20
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
	self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("groundedrookies", Plugin )