Script.Load("lua/TGNSCommon.lua")

TGNSScoreboardPlayerHider = {}

local hidingPredicates = {}

local originalSendNetworkMessage = Server.SendNetworkMessage

Server.SendNetworkMessage = function(arg1, arg2, arg3, ...)
	local networkMessage = ""
	local message
	local targetPlayer
	if type(arg1) == "string" then
		networkMessage = arg1
		message = arg2
	elseif type(arg2) == "string" then
		targetPlayer = arg1
		networkMessage = arg2
		message = arg3
	end
	
	if networkMessage == "Scores" and targetPlayer and message then
		local shouldHide = TGNS.Any(hidingPredicates, function(hidingPredicate) return hidingPredicate(targetPlayer, message) end)
		if shouldHide then
			Server.SendCommand(targetPlayer, string.format("clientdisconnect %d", message.clientId) )
			return
		end
	end
	
	originalSendNetworkMessage(arg1, arg2, arg3, ...)
end

TGNSScoreboardPlayerHider.RegisterHidingPredicate = function(hidingPredicate)
	table.insert(hidingPredicates, hidingPredicate)
end