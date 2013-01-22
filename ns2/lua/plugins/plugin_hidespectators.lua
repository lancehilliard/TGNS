// Hide Spectators

Script.Load("lua/TGNSCommon.lua")

local originalSendNetworkMessage = Server.SendNetworkMessage

Server.SendNetworkMessage = function(arg1, arg2, arg3, ...)
	local networkMessage = ""
	local message
	local target
	if type(arg1) == "string" then
		networkMessage = arg1
		message = arg2
	elseif type(arg2) == "string" then
		target = arg1
		networkMessage = arg2
		message = arg3
	end
	
	if networkMessage == "Scores" and message and message.teamNumber == kSpectatorIndex then
		if target and not TGNS:ClientAction(target, TGNS.IsClientAdmin) then
			Server.SendCommand(target, string.format("clientdisconnect %d", message.clientId) )
			return
		end
	end
	
	originalSendNetworkMessage(arg1, arg2, arg3, ...)
end

Shared.Message("Hide Spectators Loading Complete")
