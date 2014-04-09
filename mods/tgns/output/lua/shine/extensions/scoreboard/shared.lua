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
Plugin.QUERY_REQUESTED = "scoreboard_QUERY_REQUESTED"
Plugin.QUERY_ALLOWED = "scoreboard_QUERY_ALLOWED"
Plugin.BADGE_QUERY_REQUESTED = "scoreboard_BADGE_QUERY_REQUESTED"
Plugin.BADGE_QUERY_ALLOWED = "scoreboard_BADGE_QUERY_ALLOWED"
Plugin.TOGGLE_CUSTOM_NUMBERS_COLUMN = "scoreboard_TOGGLE_CUSTOM_NUMBERS_COLUMN"
Plugin.TOGGLE_OPTIONALS = "scoreboard_TOGGLE_OPTIONALS"
Plugin.PLAYER_NOTE = "scoreboard_PLAYER_NOTE"
Plugin.HAS_JETPACK = "scoreboard_HAS_JETPACK"
Plugin.HAS_JETPACK_RESET = "scoreboard_HAS_JETPACK_RESET"
Plugin.SHOW_TEAM_MESSAGES = "scoreboard_SHOW_TEAM_MESSAGES"

TGNS.RegisterNetworkMessage(Plugin.SCOREBOARD_DATA, {i="integer", p="string(6)", c="boolean"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_MAY_TRY_AGAIN, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_RESET, {})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_RECEIVED_TOTAL, {t="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_SENT_TOTAL, {t="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_ALREADY_APPROVED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.QUERY_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.QUERY_ALLOWED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.BADGE_QUERY_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.BADGE_QUERY_ALLOWED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.TOGGLE_CUSTOM_NUMBERS_COLUMN, {t="boolean"})
TGNS.RegisterNetworkMessage(Plugin.TOGGLE_OPTIONALS, {t="boolean"})
TGNS.RegisterNetworkMessage(Plugin.PLAYER_NOTE, {c="integer", n="string(10)"})
TGNS.RegisterNetworkMessage(Plugin.HAS_JETPACK, {c="integer", h="boolean"})
TGNS.RegisterNetworkMessage(Plugin.HAS_JETPACK_RESET, {})
TGNS.RegisterNetworkMessage(Plugin.SHOW_TEAM_MESSAGES, {s="boolean"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("scoreboard", Plugin )