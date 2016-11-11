local Plugin = {}
-- local md = TGNSMessageDisplayer.Create()
-- local NUMBER_OF_ACTIVE_MODS_INDICATIVE_OF_A_SERVER_RESTART = 15

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()
    -- TGNS.ScheduleAction(0, function()
    --     if TGNS.GetSecondsSinceServerProcessStarted() < 60 then
    --         local serverHasJustStartedAndHasMadeAllModsActiveOnFirstMap = Server.GetNumActiveMods() >= NUMBER_OF_ACTIVE_MODS_INDICATIVE_OF_A_SERVER_RESTART
    --         if serverHasJustStartedAndHasMadeAllModsActiveOnFirstMap then
    --             Shared.Message("Switching first map to prevent all clients from having to download all mods...")
    --             TGNS.SwitchToMap(TGNS.GetCurrentMapName())
    --         end
    --         TGNS.RegisterEventHook("ClientConfirmConnect", function(client)
    --             if TGNS.GetSecondsSinceServerProcessStarted() < 300 then
    --                 Shine.ScreenText.Add(71, {X = 0.3, Y = 0.3, Text = "This server recently crashed/started.", Duration = 10, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 3, FadeIn = 0, IgnoreFormat = true}, client)
    --             end
    --         end)
    --         TGNS.ScheduleAction(10, function()
    --             if TGNS.IsProduction() then
    --                 Shine.Plugins.push:Push("tgns-admin", "Server started.", string.format("%s on %s. Server Info: http://rr.tacticalgamer.com/ServerInfo", TGNS.GetCurrentMapName(), TGNS.GetSimpleServerName()))
    --             end
    --         end)
    --     end
    -- end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("hidefullmodlist", Plugin )