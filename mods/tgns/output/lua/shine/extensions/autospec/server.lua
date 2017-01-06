Plugin.HasConfig = true
Plugin.ConfigName = "autospec.json"

local md = TGNSMessageDisplayer.Create("AUTOSPEC")
local autoSpecTempfilePath = "config://tgns/temp/autospec.json"
local autoSpecSteamIds = {}
local confirmedConnected = {}

-- function Plugin:CreateCommands()
--     local fooCommand = self:BindCommand("sh_foo", nil, function(client)
--     end)
--     fooCommand:Help("")
-- end

local function addAndSave(steamId)
    TGNS.InsertDistinctly(autoSpecSteamIds, steamId)
    Shine.SaveJSONFile(autoSpecSteamIds, autoSpecTempfilePath)
end

local function removeAndSave(steamId)
    TGNS.RemoveAllMatching(autoSpecSteamIds, steamId)
    Shine.SaveJSONFile(autoSpecSteamIds, autoSpecTempfilePath)
end

function Plugin:ClientConfirmConnect(client)
    confirmedConnected[client] = true
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
    local steamId = TGNS.GetClientSteamId(TGNS.GetClient(player))
    if newTeamNumber == kSpectatorIndex then
        addAndSave(steamId)
    elseif TGNS.Has(autoSpecSteamIds, steamId) then
        removeAndSave(steamId)
    end
end

function Plugin:PlayerNameChange(player, newName, oldName)
    local client = TGNS.GetClient(player)
    local steamId = TGNS.GetClientSteamId(client)
    if oldName == kDefaultPlayerName and TGNS.Has(autoSpecSteamIds, steamId) and not confirmedConnected[client] then
        TGNS.SendToTeam(TGNS.GetPlayer(client), kSpectatorIndex, true)
        removeAndSave(steamId)
    end
end


function Plugin:ClientDisconnect(client)
    local steamId = TGNS.GetClientSteamId(client)
    if TGNS.Has(autoSpecSteamIds, steamId) then
        removeAndSave(steamId)
    end
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

    autoSpecSteamIds = Shine.LoadJSONFile(autoSpecTempfilePath) or {}
    TGNS.DoFor(self.Config.SendToSpectateOnConnect, function(steamId)
        TGNS.InsertDistinctly(autoSpecSteamIds, steamId)
    end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end