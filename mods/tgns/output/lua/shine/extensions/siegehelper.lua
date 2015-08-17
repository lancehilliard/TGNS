local md = TGNSMessageDisplayer.Create()
local isSiege = false
local siegeAdvisory = "Alltalk enabled during siege play. Siege is used only to seed the server until we have enough for normal 8v8 NS2 play."

local function showSiegeAdvisory(client)
	if Shine:IsValidClient(client) then
		md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), siegeAdvisory)
		-- md:ToClientConsole(client, "------------")
		-- md:ToClientConsole(client, " TGNS BOTS")
		-- md:ToClientConsole(client, "------------")
		-- md:ToClientConsole(client, string.format("Bots are used on TGNS to seed the server to %s non-AFK human players.", PLAYER_COUNT_THRESHOLD))
		-- md:ToClientConsole(client, string.format("When the server reaches %s non-AFK human players, the aliens surrender and humans-only NS2 play begins.", PLAYER_COUNT_THRESHOLD))
		-- md:ToClientConsole(client, "During TGNS bots play: marines spawn more quickly than in normal NS2 play")
		-- md:ToClientConsole(client, "During TGNS bots play: marines receive personal resources more quickly than in normal NS2 play")
		-- md:ToClientConsole(client, "During TGNS bots play: marines spawn more quickly than in normal NS2 play")
		-- md:ToClientConsole(client, "During TGNS bots play: marines receive catpacks when killing bots")
		-- md:ToClientConsole(client, "During TGNS bots play: marines receive a clip of ammo when killing bots")
		-- md:ToClientConsole(client, "During TGNS bots play: alien hives have more health")
		-- md:ToClientConsole(client, "During TGNS bots play: aliens get one free persistent crag")
		-- md:ToClientConsole(client, "During TGNS bots play: alltalk is enabled")
		-- md:ToClientConsole(client, "Many thanks to TAW|Leech for contributing to our skulk bot brain code!")
	end
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "siegehelper.json"

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
end

function Plugin:ClientConfirmConnect(client)
	if isSiege and not TGNS.GetIsClientVirtual(client) then
		showSiegeAdvisory(client)
		TGNS.ScheduleAction(5, function() showSiegeAdvisory(client) end)
		TGNS.ScheduleAction(12, function() showSiegeAdvisory(client) end)
		TGNS.ScheduleAction(20, function() showSiegeAdvisory(client) end)
		TGNS.ScheduleAction(40, function() showSiegeAdvisory(client) end)
	end
end


function Plugin:Initialise()
    self.Enabled = true
    -- TGNS.ExecuteServerCommand(string.format("sh_alltalk %s", TGNS.Contains(TGNS.GetCurrentMapName(), "siege") and "on" or "off"))
    TGNS.ScheduleAction(5, function()
    	if TGNS.Contains(TGNS.GetCurrentMapName(), "siege") then
    		Shine.Plugins.communityslots.Config.PublicSlots = 20
    		isSiege = true
    	end
    end)
    local originalGetCanPlayerHearPlayer
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		if isSiege and not (Shine.Plugins.sidebar and Shine.Plugins.sidebar.IsEitherPlayerInSidebar and Shine.Plugins.sidebar:IsEitherPlayerInSidebar(listenerPlayer, speakerPlayer)) then
			result = true
		end
		return result
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("siegehelper", Plugin )