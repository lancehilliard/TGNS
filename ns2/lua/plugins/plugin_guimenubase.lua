//NS2 Menu Base GUI Implementation

local kRunningMenus = { }

//GUIMenuBase
//MenuFunction(client, OptionSelected)
//MenuUpdateFunction(ClientGameID, kMenuBaseUpdateMessage)

//Need to investigate what happens when network message is sent to client that client has no information regarding - can they even connect to the server, and does it cause errors?
//If it will work without clients having that specific message, then this can be an optional install on clients/not cause too many problems with consistency checks and modded server flags.
//Would need a reasonable amount of additional dev time to update voting related plugins to optionally use the GUI.  Need to make sure consistency is maintained with text commands still working.

local function UpdateMenus(deltatime)

	for i = #kRunningMenus, 1, -1 do
		if kRunningMenus[i] ~= nil and kRunningMenus[i].UpdateTime ~= nil then
			if (Shared.GetTime() - kRunningMenus[i].UpdateTime) >= kDAKConfig.GUIMenuBase.kMenuUpdateRate then
				local newMenuBaseUpdateMessage = kRunningMenus[i].MenuUpdateFunction(kRunningMenus[i].clientGameId, kRunningMenus[i].MenuBaseUpdateMessage)
				//Always send updated message, even if nil - Will force update client side to hide menu/whatever.
				Server.SendNetworkMessage(GetPlayerMatchingGameId(kRunningMenus[i].clientGameId), "GUIMenuBase", newMenuBaseUpdateMessage, false)						
				kRunningMenus[i].MenuBaseUpdateMessage = newMenuBaseUpdateMessage
				if newMenuBaseUpdateMessage ~= nil and  newMenuBaseUpdateMessage.menutime ~= nil and newMenuBaseUpdateMessage.menutime ~= 0 then
					kRunningMenus[i].UpdateTime = Shared.GetTime()
				else
					kRunningMenus[i] = nil
				end
			end
		else
			kRunningMenus[i] = nil
		end
	end
	if #kRunningMenus == 0 then
		DAKDeregisterEventHook("kDAKOnServerUpdate", UpdateMenus)
	end

end

function CreateGUIMenuBase(id, OnMenuFunction, OnMenuUpdateFunction)

	if id == nil or id == 0 or tonumber(id) == nil then return false end
	for i = #kRunningMenus, 1, -1 do
		if kRunningMenus[i] ~= nil and kRunningMenus[i].clientGameId == id then
			return false
		end
	end
	
	local GameMenu = {UpdateTime = Shared.GetTime(), MenuFunction = OnMenuFunction, MenuUpdateFunction = OnMenuUpdateFunction, MenuBaseUpdateMessage = nil, clientGameId = id}
	if #kRunningMenus == 0 then
		DAKRegisterEventHook("kDAKOnServerUpdate", UpdateMenus, 7)
		//Want increased pri on this to make sure it runs before other events that may use information from it...
	end
	table.insert(kRunningMenus, GameMenu)
	return true
	
end

local function OnMessageBaseMenu(client, menuMessage)

	if menuMessage ~= nil then
		local CGID = GetGameIdMatchingClient(client)
		for i = #kRunningMenus, 1, -1 do
			if kRunningMenus[i].clientGameId == CGID then
				kRunningMenus[i].MenuFunction(client, menuMessage.optionselected)
				kRunningMenus[i] = nil
				break
			end
		end
		Shared.Message(string.format("Recieved selection %s", menuMessage.optionselected))
	end
	
end

Server.HookNetworkMessage("GUIMenuBaseSelected", OnMessageBaseMenu)