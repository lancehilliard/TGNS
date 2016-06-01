local Plugin = {}

Plugin.SCOREBOARD_DATA = "scoreboard_SCOREBOARD_DATA"
Plugin.APPROVE_REQUESTED = "scoreboard_APPROVE_REQUESTED"
Plugin.APPROVE_MAY_TRY_AGAIN = "scoreboard_APPROVE_MAY_TRY_AGAIN"
Plugin.APPROVE_RESET = "scoreboard_APPROVE_RESET"
Plugin.APPROVE_RECEIVED_TOTAL = "scoreboard_APPROVE_RECEIVED_TOTAL"
Plugin.APPROVE_SENT_TOTAL = "scoreboard_APPROVE_SENT_TOTAL"
Plugin.APPROVE_ALREADY_APPROVED = "scoreboard_APPROVE_ALREADY_APPROVED"
Plugin.QUERY_REQUESTED = "scoreboard_QUERY_REQUESTED"
Plugin.QUERY_ALLOWED = "scoreboard_QUERY_ALLOWED"
Plugin.VR_REQUESTED = "scoreboard_VR_REQUESTED"
Plugin.VR_ALLOWED = "scoreboard_VR_ALLOWED"
Plugin.VR_CONFIRMED = "scoreboard_VR_CONFIRMED"
--Plugin.BADGE_QUERY_REQUESTED = "scoreboard_BADGE_QUERY_REQUESTED"
Plugin.BADGE_QUERY_ALLOWED = "scoreboard_BADGE_QUERY_ALLOWED"
--Plugin.BADGE_DISPLAY_LABEL = "scoreboard_BADGE_DISPLAY_LABEL"
Plugin.TOGGLE_CUSTOM_NUMBERS_COLUMN = "scoreboard_TOGGLE_CUSTOM_NUMBERS_COLUMN"
Plugin.TOGGLE_OPTIONALS = "scoreboard_TOGGLE_OPTIONALS"
Plugin.PLAYER_NOTE = "scoreboard_PLAYER_NOTE"
Plugin.HAS_JETPACK = "scoreboard_HAS_JETPACK"
Plugin.HAS_JETPACK_RESET = "scoreboard_HAS_JETPACK_RESET"
Plugin.SHOW_TEAM_MESSAGES = "scoreboard_SHOW_TEAM_MESSAGES"
Plugin.WINORLOSE_WARNING = "scoreboard_WINORLOSE_WARNING"
Plugin.GAME_IN_PROGRESS = "scoreboard_GAME_IN_PROGRESS"
Plugin.GAME_IN_COUNTDOWN = "scoreboard_GAME_IN_COUNTDOWN"
Plugin.REQUEST_AFKRR = "scoreboard_REQUEST_AFKRR"
Plugin.SERVER_SIMPLE_NAME = "scoreboard_SERVER_SIMPLE_NAME"
Plugin.ALERT_ICON = "scoreboard_ALERT_ICON"
Plugin.TEAM_SCORES_DATA = "scoreboard_TEAM_SCORES_DATA"
Plugin.WYZ = "scoreboard_WYZ"
Plugin.SQUAD_ALLOWED = "scoreboard_SQUAD_ALLOWED"
Plugin.SQUAD_REQUESTED = "scoreboard_SQUAD_REQUESTED"
Plugin.SQUAD_CONFIRMED = "scoreboard_SQUAD_CONFIRMED"
Plugin.LAPS_BAD = "scoreboard_LAPS_BAD"
Plugin.LAPS_LEG = "scoreboard_LAPS_LEG"
Plugin.LAPS_BEST = "scoreboard_LAPS_BEST"
Plugin.LAPS_START = "scoreboard_LAPS_START"
Plugin.DESIGNATION = "scoreboard_DESIGNATION"
Plugin.ARMORDECAY1 = "scoreboard_ARMORDECAY1"
Plugin.ARMORLESS_HARVESTERS = "scoreboard_ARMORLESS_HARVESTERS"
Plugin.CHATTING_OR_MENUING_STARTED_RECENTLY = "scoreboard_CHATTING_OR_MENUING_STARTED_RECENTLY"
Plugin.RECENT_CAPTAINS = "scoreboard_RECENT_CAPTAINS"
Plugin.TOOLTIP_SOUND = "scoreboard_TOOLTIP_SOUND"
Plugin.SERVER_ADDRESS = "scoreboard_SERVER_ADDRESS"
Plugin.RECORDING_BOUNDARY = "scoreboard_RECORDING_BOUNDARY"

TGNS.RegisterNetworkMessage(Plugin.SCOREBOARD_DATA, {i="integer", p="string(6)", c="boolean", s="boolean", b="boolean", w="boolean", m="boolean", cg="boolean", gg="boolean", pg="boolean", t="string(100)", u1="boolean", u2="boolean", u3="boolean", u4="boolean", u5="boolean", u6="boolean", streaming="string(100)", sk="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_MAY_TRY_AGAIN, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_RESET, {})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_RECEIVED_TOTAL, {t="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_SENT_TOTAL, {t="integer"})
TGNS.RegisterNetworkMessage(Plugin.APPROVE_ALREADY_APPROVED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.QUERY_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.QUERY_ALLOWED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.VR_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.VR_ALLOWED, {})
TGNS.RegisterNetworkMessage(Plugin.VR_CONFIRMED, {c="integer"})
--TGNS.RegisterNetworkMessage(Plugin.BADGE_QUERY_REQUESTED, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.BADGE_QUERY_ALLOWED, {c="integer"})
--TGNS.RegisterNetworkMessage(Plugin.BADGE_DISPLAY_LABEL, {n="string(100)",l="string(100)"})
TGNS.RegisterNetworkMessage(Plugin.TOGGLE_CUSTOM_NUMBERS_COLUMN, {t="boolean"})
TGNS.RegisterNetworkMessage(Plugin.TOGGLE_OPTIONALS, {t="boolean"})
TGNS.RegisterNetworkMessage(Plugin.PLAYER_NOTE, {c="integer", n="string(10)"})
TGNS.RegisterNetworkMessage(Plugin.HAS_JETPACK, {c="integer", h="boolean"})
TGNS.RegisterNetworkMessage(Plugin.HAS_JETPACK_RESET, {})
TGNS.RegisterNetworkMessage(Plugin.SHOW_TEAM_MESSAGES, {s="boolean"})
TGNS.RegisterNetworkMessage(Plugin.WINORLOSE_WARNING, {})
TGNS.RegisterNetworkMessage(Plugin.GAME_IN_PROGRESS, {b="boolean"})
TGNS.RegisterNetworkMessage(Plugin.GAME_IN_COUNTDOWN, {b="boolean"})
TGNS.RegisterNetworkMessage(Plugin.REQUEST_AFKRR, {c="integer"})
TGNS.RegisterNetworkMessage(Plugin.SERVER_SIMPLE_NAME, {n="string(20)"})
TGNS.RegisterNetworkMessage(Plugin.ALERT_ICON, {});
TGNS.RegisterNetworkMessage(Plugin.TEAM_SCORES_DATA, {mn="string(30)", an="string(30)",ms="integer",as="integer"});
TGNS.RegisterNetworkMessage(Plugin.WYZ, {});
TGNS.RegisterNetworkMessage(Plugin.SQUAD_ALLOWED, {});
TGNS.RegisterNetworkMessage(Plugin.SQUAD_REQUESTED, {c="integer",d="integer"});
TGNS.RegisterNetworkMessage(Plugin.SQUAD_CONFIRMED, {c="integer",s="integer"});
TGNS.RegisterNetworkMessage(Plugin.LAPS_BAD, {})
TGNS.RegisterNetworkMessage(Plugin.LAPS_LEG, {})
TGNS.RegisterNetworkMessage(Plugin.LAPS_BEST, {})
TGNS.RegisterNetworkMessage(Plugin.LAPS_START, {})
TGNS.RegisterNetworkMessage(Plugin.DESIGNATION, {c="string(2)"})
TGNS.RegisterNetworkMessage(Plugin.ARMORDECAY1, {})
TGNS.RegisterNetworkMessage(Plugin.ARMORLESS_HARVESTERS, {l="string(100)"})
TGNS.RegisterNetworkMessage(Plugin.CHATTING_OR_MENUING_STARTED_RECENTLY, {})
TGNS.RegisterNetworkMessage(Plugin.RECENT_CAPTAINS, {c="string(500)"})
TGNS.RegisterNetworkMessage(Plugin.TOOLTIP_SOUND, {})
TGNS.RegisterNetworkMessage(Plugin.SERVER_ADDRESS, {a="string(100)"})
TGNS.RegisterNetworkMessage(Plugin.RECORDING_BOUNDARY, {b="string(100)",d="float", t="string(100)", p="string(30)", s="integer"})

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("scoreboard", Plugin )