local function GetRookieCount()
	local rookieClients = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p)
			return p:GetIsRookie()
		end
	)
	local result = #rookieClients
	return result
end

local md = TGNSMessageDisplayer.Create()

local Plugin = {}

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("ClientConfirmConnect", function(client)
		local player = TGNS.GetPlayer(client)
		local playerIsRookie = player:GetIsRookie()
		local rookieShouldBeKicked = TGNS.GetPlayerCount() > 10 and GetRookieCount() > 4 and playerIsRookie
		if rookieShouldBeKicked then
			md:ToPlayerNotifyInfo(player, "To teach, we limit concurrent rookies. Please return later!")
			TGNSClientKicker.Kick(client, "To teach, we limit concurrent rookies. Please return later!", nil, nil, false)
			return false
		end
	end, TGNS.HIGHEST_EVENT_HANDLER_PRIORITY)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("rookiethrottle", Plugin )