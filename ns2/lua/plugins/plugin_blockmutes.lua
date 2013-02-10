// Block Mutes

if kDAKConfig and kDAKConfig.BlockMutes then
	Script.Load("lua/TGNSCommon.lua")

	local function OnMutePlayer(client, networkMessage)
		return true // returing true cancels further processing of the event
	end

	TGNS.RegisterNetworkMessageHook("MutePlayer", OnMutePlayer, 1) // lowest priority so that other plugins hooking 'MutePlayer' wont be canceled
end

Shared.Message("Block Mutes Loading Complete")