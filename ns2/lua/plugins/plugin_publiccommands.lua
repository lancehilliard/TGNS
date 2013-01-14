// PublicCommands

if kDAKConfig and kDAKConfig.PublicCommands and kDAKConfig.PublicCommands.Commands then
	Script.Load("lua/TGNSCommon.lua")
	
	// constants used to look up command string in kDAKConfig.PublicCommands.Commands table
	local TIMELEFTCOMMAND = "timeleft"
	local NEXTMAPCOMMAND = "nextmap"

	//////////////
	// Timeleft //
	//////////////
	
	local timeleftThrottle = 0
	local function OnCommandTimeleft(client)
		if client ~= nil and Shared.GetTime() - timeleftThrottle > kDAKConfig.PublicCommands.Commands[TIMELEFTCOMMAND].throttle then
			timeleftThrottle = Shared.GetTime()
			for _, player in pairs(TGNS:GetPlayerList()) do
				if player ~= nil then
					chatMessage = string.sub(string.format("%.1f Minutes Remaining.", math.max(0,((kDAKMapCycle.time * 60) - Shared.GetTime())/60)), 1, kMaxChatLength)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				end
			end
		end
		
	end

	// This command is already defined by the mapvote plugin.  If mapvote is in the plugin list, don't hook it again.
	if kDAKConfig.PublicCommands.Commands[TIMELEFTCOMMAND] and not kDAKConfig.DAKLoader.kPluginsList["mapvote"] then
		Event.Hook("Console_" .. kDAKConfig.PublicCommands.Commands[TIMELEFTCOMMAND].command,               OnCommandTimeleft)
	end
	
	/////////////
	// Nextmap //
	/////////////
	
	local nextmapThrottle = 0
	local function GetMapName(map)
		if type(map) == "table" and map.map ~= nil then
			return map.map
		end
		return map
	end
	
	local function OnCommandNextMap(client)

		if client ~= nil and Shared.GetTime() - nextmapThrottle > kDAKConfig.PublicCommands.Commands[NEXTMAPCOMMAND].throttle then
			nextmapThrottle = Shared.GetTime()
			for _, player in pairs(TGNS:GetPlayerList()) do
				if player ~= nil then
					local mapname = GetMapName(MapCycle_GetNextMapInCycle())
					if mapname ~= nil then
						chatMessage = string.sub(string.format("Next map: %s", mapname), 1, kMaxChatLength)
						Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					end
				end
			end
		end
		
	end

	if kDAKConfig.PublicCommands.Commands[NEXTMAPCOMMAND] then
		Event.Hook("Console_" .. kDAKConfig.PublicCommands.Commands[NEXTMAPCOMMAND].command,               OnCommandNextMap)
	end
	
	///////////////////
	// Hook for chat //
	///////////////////
	
	local function OnChatMessage(message, playerName, steamId, teamNumber, teamOnly, client)
	
		if client and steamId and steamId ~= 0 then
			// Timeleft
			if kDAKConfig.PublicCommands.Commands[TIMELEFTCOMMAND] and not kDAKConfig.DAKLoader.kPluginsList["mapvote"] and
				message == kDAKConfig.PublicCommands.Commands[TIMELEFTCOMMAND].command then
				OnCommandTimeleft(client)
			end
			
			// Nextmap
			if kDAKConfig.PublicCommands.Commands[NEXTMAPCOMMAND] and message == kDAKConfig.PublicCommands.Commands[NEXTMAPCOMMAND].command then
				OnCommandNextMap(client)
			end
		end
	
	end

	DAKRegisterEventHook(kDAKOnClientChatMessage, OnChatMessage, 5)

	///////////////
	// PM Admins //
	///////////////
	
	if kDAKConfig.PublicCommands.PMAdmins then
		local function CheckForAdminChat(client, message)
			if message and string.sub(message, 1, 1) == "@" then
				// Admins must direct the message to a player, message is also sent to other admins
				if DAKGetClientCanRunCommand(client, "PMADMIN") then
					local name
					local chatMessage
					_, _, name, chatMessage = string.find(message, "@([%w%p]*) (.*)")
					if name ~= nil and string.len(name) > 0 then
						local targetplayer = TGNS:GetPlayerMatchingName(name)
						if targetplayer ~= nil then
							TGNS:PMAllPlayersWithAccess(client, string.format("To %s: %s", targetplayer:GetName(), chatMessage), "PMADMIN", true, true)
							Server.SendNetworkMessage(targetplayer, "Chat", TGNS:BuildPMChatMessage(client, chatMessage, "PMADMIN", true), true)
						else
							Server.SendNetworkMessage(client:GetControllingPlayer(), "Chat", TGNS:BuildPMChatMessage(nil, string.format("'%s' does not uniquely match a player.", name), "PMADMIN", true), true)
						end
					elseif chatMessage ~= nil then
						TGNS:PMAllPlayersWithAccess(client, chatMessage, "PMADMIN", true, true)
					else
						Server.SendNetworkMessage(client:GetControllingPlayer(), "Chat", TGNS:BuildPMChatMessage(nil, "Admin usage: @<name> <message>, if name is blank only admins are messaged", "PMADMIN", true), true)
					end
				// Non admins will send the message to all admins
				else
					local chatMessage = string.sub(message, 2, -1)
					if chatMessage then
						TGNS:PMAllPlayersWithAccess(client, chatMessage, "PMADMIN", true, true)
					else
						Server.SendNetworkMessage(client:GetControllingPlayer(), "Chat", TGNS:BuildPMChatMessage(nil, "Usage: @<message>", "PMADMIN", true), true)
					end
				end
				return true
			end
			return false
		end
		
		TGNS:RegisterChatHook(CheckForAdminChat)
	end
end

Shared.Message("PublicCommands Loading Complete")
