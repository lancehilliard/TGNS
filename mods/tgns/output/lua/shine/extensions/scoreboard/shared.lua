local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "scoreboard.json"

Plugin.SCOREBOARD_DATA = "scoreboard_SCOREBOARD_DATA"
Plugin.APPROVE_REQUESTED = "scoreboard_APPROVE_REQUESTED"
Plugin.APPROVE_MAY_TRY_AGAIN = "scoreboard_APPROVE_MAY_TRY_AGAIN"
Plugin.APPROVE_RESET = "scoreboard_APPROVE_RESET"
Plugin.APPROVE_RECEIVED_TOTAL = "scoreboard_APPROVE_RECEIVED_TOTAL"
Plugin.APPROVE_SENT_TOTAL = "scoreboard_APPROVE_SENT_TOTAL"
Plugin.APPROVE_ALREADY_APPROVED = "scoreboard_APPROVE_ALREADY_APPROVED"

TGNS.RegisterNetworkMessage(Plugin.SCOREBOARD_DATA, {i="integer", p="string(6)", c="boolean"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_MAY_TRY_AGAIN, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_RESET, {})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_RECEIVED_TOTAL, {t="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_SENT_TOTAL, {t="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_ALREADY_APPROVED, {c="integer"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("scoreboard", Plugin )