//DAK loader Client

//No sync of plugins active to clients currently, may be useful to have at some point.
//Used to load client side scripts, may be expanded if plugin sync seems useful.
//Would allow help menus and such to be generated.
//Dont think that plugins need to be syncd, menu system designed is almost fully server side so client needs very little information. - Client should always load shared defs.

DAK = { }
DAK.__index = DAK

Script.Load("lua/base/class.lua")

local MenuMessageTag = "#^DAK"

local function OnClientLoaded()
	if guimenubase == nil then
		guimenubase = GetGUIManager():CreateGUIScriptSingle("gui/GUIMenuBase")			
	end
	local originalNS2PlayerGetCameraViewCoordsOverride
	originalNS2PlayerGetCameraViewCoordsOverride = DAK:Class_ReplaceMethod("Player", "GetCameraViewCoordsOverride", 
		function(self, cameraCoords)

			if self.countingDown and self:GetGameStarted() then
				return cameraCoords
			else
				return originalNS2PlayerGetCameraViewCoordsOverride(self, cameraCoords)
			end
			
		end
	)
	local originalNS2PlayerGetDrawWorld
	originalNS2PlayerGetDrawWorld = DAK:Class_ReplaceMethod("Player", "GetDrawWorld", 
		function(self, isLocal)

			if self.countingDown and self:GetGameStarted() then
				return not self:GetIsLocalPlayer() or self:GetIsThirdPerson()
			else
				return originalNS2PlayerGetDrawWorld(self, isLocal)
			end
			
		end
	)
	Shared.ConsoleCommand("registerclientmenus")
end

Event.Hook("LoadComplete", OnClientLoaded)

local function OnClientDisconnected()
	if guimenubase ~= nil then
		GetGUIManager():DestroyGUIScriptSingle("gui/GUIMenuBase")
	end
end

Event.Hook("ClientDisconnected", OnClientDisconnected)

local function MenuUpdate(Message)
	local GUIMenuBase = GetGUIManager():GetGUIScriptSingle("gui/GUIMenuBase")
	if GUIMenuBase then
		GUIMenuBase:MenuUpdate(Message)
	end
end

local function OnServerAdminPrint(messageTable)
	if messageTable ~= nil and messageTable.message ~= nil then
		if string.sub(messageTable.message, 0, string.len(MenuMessageTag)) == MenuMessageTag then
			MenuUpdate(string.sub(messageTable.message, string.len(MenuMessageTag) + 1))
		else
			Shared.Message(messageTable.message)
		end
	end
end

local originalNS2ClientHookNetworkMessage

originalNS2ClientHookNetworkMessage = DAK:Class_ReplaceMethod("Client", "HookNetworkMessage", 
	function(message, func)

		if message == "ServerAdminPrint" then
			originalNS2ClientHookNetworkMessage(message, OnServerAdminPrint)
		else
			originalNS2ClientHookNetworkMessage(message, func)
		end
		
	end
)