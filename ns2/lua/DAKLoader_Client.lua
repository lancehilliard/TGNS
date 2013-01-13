//DAK Loader Client

//No sync of plugins active to clients currently, may be useful to have at some point.
//Used to load client side scripts, may be expanded if plugin sync seems useful.
//Would allow help menus and such to be generated.

Script.Load("lua/Client.lua")
Script.Load("lua/DAKLoader_Shared.lua")

/*
local originalNS2PlayerOnInit
	
originalNS2PlayerOnInit = Class_ReplaceMethod("Player", "OnInitLocalClient", 
	function(self)
	
		if self.guivotebase == nil then
            self.guivotebase = GetGUIManager():CreateGUIScript("gui/gui_votebase")
        end
		originalNS2PlayerOnInit(self)
		
	end
)

local originalNS2PlayerOnDestroy
	
originalNS2PlayerOnDestroy = Class_ReplaceMethod("Player", "OnDestroy", 
	function(self)
	
		if self.guivotebase ~= nil then
			GetGUIManager():DestroyGUIScript(self.guivotebase)
            self.guivotebase = nil
        end
		originalNS2PlayerOnDestroy(self)
		
	end
)
*/