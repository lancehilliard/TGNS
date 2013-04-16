//DAK loader/Base Config

if Server then

	DAK = { }
	DAK.__index = DAK
	DAK.events = { }							//List used to track events, used by event hook system.
	DAK.scriptoverrides = { }					//List used to track script replacements/blocks.
	DAK.timedcalledbacks = { }					//List used to track timed calledbacks.
	DAK.activemoddedclients = { }				//Tracks what clients have ack'd that they have the client side workshop mod.
	DAK.runningmenus = { }						//List of currently open client menus.
	DAK.activemenuitems = { }					//List of active menu items.
	DAK.networkmessagefunctions = { }			//List used to track network message functions, can be used to replace functions raised on network message recieving.
	DAK.registerednetworkmessages = { }			//List used to track network messages to their corresponding functions.
	DAK.chatcommands = { }						//List of chat commands.
	DAK.gameid = { }							//Used to track client joins for game IDs
	DAK.gaggedplayers = { }						//Used to track gagged clients
	DAK.enabled = true							//Can be used to block most DAK events, or indicate errors.
	DAK.version = "0.1.415a"
	
	local Scripts = { }
	table.insert(Scripts, "lua/dkjson.lua")
	table.insert(Scripts, "lua/base/class.lua")
	table.insert(Scripts, "lua/base/globals.lua")
	table.insert(Scripts, "lua/base/eventfunctions.lua")
	table.insert(Scripts, "lua/base/menufunctions.lua")
	table.insert(Scripts, "lua/base/playerfunctions.lua")
	table.insert(Scripts, "lua/base/configfileutility.lua")
	table.insert(Scripts, "lua/base/serveradmin.lua")
	table.insert(Scripts, "lua/base/config.lua")
	table.insert(Scripts, "lua/base/settings.lua")
	table.insert(Scripts, "lua/base/eventhooks.lua")
	table.insert(Scripts, "lua/base/serveradmincommands.lua")
	table.insert(Scripts, "lua/base/language.lua")
	table.insert(Scripts, "lua/base/pluginloader.lua")
	
	for i, script in pairs(Scripts) do
		Script.Load(script)
	end
	
	if DAK.enabled then
		Shared.Message("DAK successfully loaded!")
	end
	
end