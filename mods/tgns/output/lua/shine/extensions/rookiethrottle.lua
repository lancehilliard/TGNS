local function GetPlayingRookieCount()
	local rookieClients = TGNS.GetMatchingClients(TGNS.GetPlayers(TGNS.GetPlayingClients(TGNS.GetPlayerList())), function(c,p)
			return p:GetIsRookie()
	end)
	local result = #rookieClients
	return result
end

local md = TGNSMessageDisplayer.Create()

local Plugin = {}

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	if TGNS.IsGameplayTeamNumber(newTeamNumber) then
		local playerIsRookie = player:GetIsRookie()
		if playerIsRookie then
			local tooManyRookies = TGNS.GetPlayerCount() > 10 and GetPlayingRookieCount() > 4
			if tooManyRookies then
				md:ToPlayerNotifyError(player, "To teach, we limit concurrent rookies. Please spectate for now!")
				return false
			end
		end
	end
end

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("rookiethrottle", Plugin )