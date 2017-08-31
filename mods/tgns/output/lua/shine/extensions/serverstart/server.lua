Plugin.HasConfig = false
-- Plugin.ConfigName = "serverstart.json"

local md = TGNSMessageDisplayer.Create()
local serverStartTempfilePath = "config://tgns/temp/serverStart.json"
local NUMBER_OF_ACTIVE_MODS_INDICATIVE_OF_A_SERVER_RESTART = 15
local NUMBER_OF_PLAYERS_BEFORE_SCHEDULED_RESTART = 22
local NUMBER_OF_HOURS_SERVER_SEEMS_TO_SURVIVE_WITHOUT_CRASHING = 16 -- 2.5
local SERVER_COMMANDLINE_START_MAP_NAME = "dev_test"

function Plugin:ClientConfirmConnect(client)
end

function Plugin:CreateCommands()
	local sh_loghttp = self:BindCommand( "sh_loghttp", nil, function(client)
		TGNS.LogHttp = not TGNS.LogHttp
		md:ToClientConsole(client, string.format("TGNS.LogHttp: %s", TGNS.LogHttp == true))
	end)
	sh_loghttp:Help( "Log HTTP requests for map duration. Expensive." )

    local warnRestartCommand = self:BindCommand("sh_warnrestart", nil, function(client)
        Shine.ScreenText.Add(41, {X = 0.5, Y = 0.35, Text = "Server restarting.\nPlease wait while\nyou reconnect\nautomatically.", Duration = 30, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true})
        TGNS.DoFor(TGNS.GetPlayerList(), function(p)
        	TGNS.SendNetworkMessageToPlayer(p, self.RECONNECT, {})
        end)
    end)
    warnRestartCommand:Help("Warn all that server is about to restart and all will reconnect.")
end

function Plugin:GetServerStartData()
    return Shine.LoadJSONFile(serverStartTempfilePath) or {}
end

function Plugin:SetServerStartData(data)
    Shine.SaveJSONFile(data, serverStartTempfilePath)
end

function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()

    TGNS.ScheduleAction(0, function()
        Shared.Message("serverstart - TGNS.GetSecondsSinceServerProcessStarted(): " .. tostring(TGNS.GetSecondsSinceServerProcessStarted()))
        if TGNS.GetSecondsSinceServerProcessStarted() < 60 then
            local serverStartData = self:GetServerStartData()
            if serverStartData.startMapName then
                local mapNameToSwitchTo = serverStartData.startMapName
                serverStartData.startMapName = nil
                self:SetServerStartData(serverStartData)
                Shared.Message("serverStartData.startMapName: " .. tostring(mapNameToSwitchTo))
                TGNS.SwitchToMap(mapNameToSwitchTo)
            else
                local serverHasJustStartedAndHasMadeAllModsActiveOnFirstMap = Server.GetNumActiveMods() >= NUMBER_OF_ACTIVE_MODS_INDICATIVE_OF_A_SERVER_RESTART
                if serverHasJustStartedAndHasMadeAllModsActiveOnFirstMap then
                    Shared.Message("Switching first map to prevent all clients from having to download all mods...")
                    TGNS.SwitchToMap(TGNS.GetCurrentMapName())
                end
                TGNS.RegisterEventHook("ClientConfirmConnect", function(client)
                    if TGNS.GetSecondsSinceServerProcessStarted() < 300 and not SERVER_COMMANDLINE_START_MAP_NAME ~= TGNS.GetCurrentMapName() then
                        Shine.ScreenText.Add(71, {X = 0.3, Y = 0.3, Text = "Scheduled server restart complete.", Duration = 10, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 3, FadeIn = 0, IgnoreFormat = true}, client)
                    end
                end)
                TGNS.ScheduleAction(10, function()
                    if TGNS.IsProduction() then
                        Shine.Plugins.push:Push("tgns-admin", "Server started.", string.format("%s on %s. Server Info: http://rr.tacticalgamer.com/ServerInfo", TGNS.GetCurrentMapName(), TGNS.GetSimpleServerName()))
                    end
                end)
            end
        end
    end)

    local mapNameNotifyNames = {"WINNER_VOTES", "CHOOSING_RANDOM_MAP", "WINNER_CYCLING", "WINNER_NEXT_MAP"}
    TGNS.ScheduleAction(5, function()
        local originalSendTranslatedNotify = Shine.Plugins.mapvote.SendTranslatedNotify
        Shine.Plugins.mapvote.SendTranslatedNotify = function(mapVoteSelf, target, name, params)
            if TGNS.Has(mapNameNotifyNames, name) then
                local votedInMapName = params.MapName
                if votedInMapName then
                    TGNS.ExecuteEventHooks("MapVoteFinished", votedInMapName)
                    local hoursSinceServerProcessStarted = TGNS.ConvertSecondsToHours(TGNS.GetSecondsSinceServerProcessStarted())
                    if votedInMapName ~= SERVER_COMMANDLINE_START_MAP_NAME and hoursSinceServerProcessStarted > NUMBER_OF_HOURS_SERVER_SEEMS_TO_SURVIVE_WITHOUT_CRASHING and Server.GetNumPlayersTotal() >= NUMBER_OF_PLAYERS_BEFORE_SCHEDULED_RESTART then
                        local serverStartData = self:GetServerStartData()
                        serverStartData.startMapName = votedInMapName
                        self:SetServerStartData(serverStartData)
                        TGNS.ScheduleAction(0, function()
                            md:ToAllNotifyInfo(string.format("Server will restart to %s. Please wait. Reconnect manually if you aren't reconnected automatically.", votedInMapName))
                        end)
                        TGNS.RestartServerProcess()
                    else
                        originalSendTranslatedNotify(mapVoteSelf, target, name, params)
                    end
                else
                    originalSendTranslatedNotify(mapVoteSelf, target, name, params)                    
                end
            else
                originalSendTranslatedNotify(mapVoteSelf, target, name, params)
            end
        end
    end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end