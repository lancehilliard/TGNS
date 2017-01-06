Plugin.HasConfig = false
-- Plugin.ConfigName = "newcomms.json"

local md = TGNSMessageDisplayer.Create("COMMS")
local PASSPHRASE = "I will hear"
local passedClients = {}

local function isEnforcementActive()
    return Server.GetNumPlayersTotal() >= 12 or not TGNS.IsProduction()
end

local function updatePlayerScoreboardStatus(player)
    if Shine.Plugins.scoreboard and Shine.Plugins.scoreboard.AnnouncePlayerPrefix then
        Shine.Plugins.scoreboard:AnnouncePlayerPrefix(player)
    end
end

function Plugin:ClientConfirmConnect(client)
    updatePlayerScoreboardStatus(player)
end

-- function Plugin:CreateCommands()
--     local fooCommand = self:BindCommand("sh_foo", nil, function(client)
--     end)
--     fooCommand:Help("")
-- end

function Plugin:ClientIsGated(client)
    return isEnforcementActive() and client and not TGNS.ClientIsOnPlayingTeam(client) and not TGNS.HasClientSignedPrimer(client) and not passedClients[client] and not Shine.Plugins.scoreboard:IsVouched(client) and TGNS.PlayerIsRookie(TGNS.GetPlayer(client))
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
    -- if not TGNS.IsProduction() then
    --     TGNS.HasClientSignedPrimer = function(client) return false end
    -- end
    local client = TGNS.GetClient(player)
    if TGNS.IsGameplayTeamNumber(newTeamNumber) and self:ClientIsGated(client) then
        md:ToPlayerNotifyYellow(player, string.format("Type '%s' into chat to play. Press 'y' to chat.", PASSPHRASE))
        updatePlayerScoreboardStatus(player)
        return false
    end
end

function Plugin:PlayerSay(client, networkMessage)
    local message = TGNS.ToLower(StringTrim(networkMessage.message))
    if message == TGNS.ToLower(PASSPHRASE) then
        if not TGNS.ClientIsOnPlayingTeam(client) and not TGNS.HasClientSignedPrimer(client) then
            if self:ClientIsGated(client) then
                passedClients[client] = true
            end
            md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Thank you. Join a team when you can.")
            updatePlayerScoreboardStatus(player)
            return ""
        end
    end
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end