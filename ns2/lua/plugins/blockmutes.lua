Script.Load("lua/TGNSCommon.lua")
local function OnMutePlayer(client, networkMessage)
	return true // returing true cancels further processing of the event
end

TGNS.RegisterNetworkMessageHook("MutePlayer", OnMutePlayer, 1) // lowest priority so that other plugins hooking 'MutePlayer' won't be canceled
