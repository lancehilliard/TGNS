//NS2 Menu Base GUI Implementation

local kRunningMenus = { }

//GUIMenuBase
//MenuFunction(client, OptionSelected)
//MenuUpdateFunction(ClientGameID, kMenuBaseUpdateMessage)

//Would need a reasonable amount of additional dev time to update voting related plugins to optionally use the GUI.  Need to make sure consistency is maintained with text commands still working.

local function UpdateMenus(deltatime)

	for i = #kRunningMenus, 1, -1 do
		if kRunningMenus[i] ~= nil and kRunningMenus[i].UpdateTime ~= nil then
			if (Shared.GetTime() - kRunningMenus[i].UpdateTime) >= DAK.config.guimenubase.kMenuUpdateRate then
				local newMenuBaseUpdateMessage = kRunningMenus[i].MenuUpdateFunction(kRunningMenus[i].clientGameId, kRunningMenus[i].MenuBaseUpdateMessage)
				//Always send updated message, even if nil - Will force update client side to hide menu/whatever.
				Server.SendNetworkMessage(DAK:GetPlayerMatchingGameId(kRunningMenus[i].clientGameId), "GUIMenuBase", newMenuBaseUpdateMessage, false)						
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
		DAK:DeregisterEventHook("OnServerUpdate", UpdateMenus)
	end

end

function CreateGUIMenuBase(id, OnMenuFunction, OnMenuUpdateFunction)

	if id == nil or id == 0 or tonumber(id) == nil then return false end
	for i = #kRunningMenus, 1, -1 do
		if kRunningMenus[i] ~= nil and kRunningMenus[i].clientGameId == id then
			return false
		end
	end
	
	local GameMenu = {UpdateTime = math.max(Shared.GetTime() - DAK.config.guimenubase.kMenuUpdateRate, 0), MenuFunction = OnMenuFunction, MenuUpdateFunction = OnMenuUpdateFunction, MenuBaseUpdateMessage = nil, clientGameId = id}
	if #kRunningMenus == 0 then
		DAK:RegisterEventHook("OnServerUpdate", UpdateMenus, 7)
		//Want increased pri on this to make sure it runs before other events that may use information from it...
	end
	table.insert(kRunningMenus, GameMenu)
	return true
	
end

function CreateMenuBaseNetworkMessage()
	local kVoteUpdateMessage = { }
	kVoteUpdateMessage.header = ""
	kVoteUpdateMessage.option1 = ""
	kVoteUpdateMessage.option1desc = ""
	kVoteUpdateMessage.option2 = ""
	kVoteUpdateMessage.option2desc = ""
	kVoteUpdateMessage.option3 = ""
	kVoteUpdateMessage.option3desc = ""
	kVoteUpdateMessage.option4 = ""
	kVoteUpdateMessage.option4desc = ""
	kVoteUpdateMessage.option5 = ""
	kVoteUpdateMessage.option5desc = ""
	kVoteUpdateMessage.footer = ""
	kVoteUpdateMessage.inputallowed = false
	kVoteUpdateMessage.menutime = Shared.GetTime()
	return kVoteUpdateMessage
end

local function OnMessageBaseMenu(client, menuMessage)

	if menuMessage ~= nil then
		local CGID = DAK:GetGameIdMatchingClient(client)
		for i = #kRunningMenus, 1, -1 do
			if kRunningMenus[i].clientGameId == CGID then
				kRunningMenus[i].MenuFunction(client, menuMessage.optionselected)
				kRunningMenus[i] = nil
				break
			end
		end
		//Shared.Message(string.format("Recieved selection %s", menuMessage.optionselected))
	end
	
end

Server.HookNetworkMessage("GUIMenuBaseSelected", OnMessageBaseMenu)