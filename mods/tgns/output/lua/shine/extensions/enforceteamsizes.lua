local md
local Plugin = {}

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local cancel = false
	if TGNS.IsGameplayTeamNumber(newTeamNumber) then
		local client = TGNS.GetClient(player)
		if not (force or shineForce) and not TGNS.GetIsClientVirtual(client) then
			local playerList = TGNS.GetPlayerList()
			if #TGNS.GetTeamClients(newTeamNumber, playerList) >= 8 then
				local otherPlayingTeamNumber = TGNS.GetOtherPlayingTeamNumber(newTeamNumber)
				if #TGNS.GetTeamClients(otherPlayingTeamNumber, playerList) < 8 then
					cancel = true
					TGNS.SendToTeam(player, otherPlayingTeamNumber)
					md:ToPlayerNotifyInfo(player, string.format("You were placed on %s to preserve 8v8.", TGNS.GetTeamName(otherPlayingTeamNumber)))
				end
			end
		end
	end
	if cancel then
		return false
	end
end

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create("TEAMS")
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("enforceteamsizes", Plugin )