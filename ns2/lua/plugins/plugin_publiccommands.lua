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
			for _, player in pairs(GetPlayerList()) do
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
			for _, player in pairs(GetPlayerList()) do
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
				return true
			end
			
			// Nextmap
			if kDAKConfig.PublicCommands.Commands[NEXTMAPCOMMAND] and message == kDAKConfig.PublicCommands.Commands[NEXTMAPCOMMAND].command then
				OnCommandNextMap(client)
				return true
			end
		end
	
	end
	
	table.insert(kDAKOnClientChatMessage, function(message, playerName, steamId, teamNumber, teamOnly, client) return OnChatMessage(message, playerName, steamId, teamNumber, teamOnly, client) end)
	
	///////////////
	// PM Admins //
	///////////////
	
	if kDAKConfig.PublicCommands.PMAdmins then
		local function CheckForAdminChat(client, message)
			if message and string.sub(message, 1, 1) == "@" then
				local chatMessage = string.sub(message, 2, -1)
				if chatMessage then
					PMAllPlayersWithAccess(client, chatMessage, "PMADMIN", true)
				end
				return true
			end
			return false
		end
		
		TGNSRegisterChatHook(CheckForAdminChat)
	end
end

Shared.Message("PublicCommands Loading Complete")
