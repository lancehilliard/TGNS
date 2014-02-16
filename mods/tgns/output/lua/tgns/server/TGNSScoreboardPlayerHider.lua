-- TGNSScoreboardPlayerHider = {}
-- local hidingPredicates = {}
-- local originalSendNetworkMessage = Server.SendNetworkMessage

-- Server.SendNetworkMessage = function(arg1, arg2, arg3, ...)
-- 	local networkMessage = ""
-- 	local message
-- 	local targetPlayer
-- 	local foo
-- 	if type(arg1) == "string" then
-- 		networkMessage = arg1
-- 		message = arg2
-- 		if arg3 ~= nil then
-- 			foo = function(arg1, arg2, arg3, ...) originalSendNetworkMessage(arg1, arg2, arg3) end
-- 		else
-- 			foo = function(arg1, arg2, arg3, ...) originalSendNetworkMessage(arg1, arg2) end
-- 		end
-- 	elseif type(arg2) == "string" then
-- 		targetPlayer = arg1
-- 		networkMessage = arg2
-- 		message = arg3
-- 		foo = function(arg1, arg2, arg3, ...) originalSendNetworkMessage(arg1, arg2, arg3, ...) end
-- 	end

-- 	if networkMessage == "Scores" and targetPlayer and message then
-- 		local shouldHide = TGNS.Any(hidingPredicates, function(hidingPredicate) return hidingPredicate(targetPlayer, message) end)
-- 		if shouldHide then
-- 			Server.SendCommand(targetPlayer, string.format("clientdisconnect %d", message.clientId) )
-- 			return
-- 		end
-- 	end

-- 	foo(arg1, arg2, arg3, ...)
-- end

-- TGNSScoreboardPlayerHider.RegisterHidingPredicate = function(hidingPredicate)
-- 	table.insert(hidingPredicates, hidingPredicate)
-- end