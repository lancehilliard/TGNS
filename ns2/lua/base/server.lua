//DAK loader/Base Config

if Server then

	//Going to finally move to a single global variable DAK, with functions being nested under that.  Should have done this originally TBH.
	DAK = { }

	DAK.revisions = { }							//List used to track revisions of plugins
	DAK.events = { }							//List used to track events, used by event hook system.
	DAK.networkmessagefunctions = { }			//List used to track network message functions, can be used to replace functions raised on network message recieving.
	DAK.registerednetworkmessages = { }			//List used to track network messages to their corresponding functions.
	DAK.chatcommands = { }						//List of chat commands.
	DAK.gameid = { }							//Used to track client joins for game IDs
	DAK.gaggedplayers = { }						//Used to track gagged clients

	DAK.revisions["loader"] = "0.1.302a"
	
	Script.Load("lua/dkjson.lua")
	Script.Load("lua/base/class.lua")
	Script.Load("lua/base/globals.lua")
	Script.Load("lua/base/configfileutility.lua")
	Script.Load("lua/base/serveradmin.lua")
	Script.Load("lua/base/config.lua")
	Script.Load("lua/base/settings.lua")
	
	if decoda_name == "Server" then
		//When this global exists, assume workshop (meh)
		//Script.Load("lua/base/shared.lua")
		//Shared file just offers net msg definitions required for menus.
	end

	Script.Load("lua/base/eventhooks.lua")
	Script.Load("lua/base/serveradmincommands.lua")
	Script.Load("lua/base/language.lua")
	Script.Load("lua/base/pluginloader.lua")
	
end