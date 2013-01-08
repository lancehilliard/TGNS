//BetterKnownAs

if kDAKConfig and kDAKConfig.BetterKnownAs then
	Script.Load("lua/TGNSCommon.lua")

	local bkaFilenamePath = "config://bka/"
    
	local function GetBkaName(...)
		local result = ""
		local concatenation = StringConcatArgs(...)
		if concatenation then
			result = concatenation
		end
		return result
	end
	
	local function GetBkaFilename(steamId)
		local result = bkaFilenamePath .. steamId .. ".json"
		return result
	end
    
	local function SaveBka(bkaData)
		local bkaFilename = GetBkaFilename(bkaData.steamId)
		local bkaFile = io.open(bkaFilename, "w+")
		if bkaFile then
			bkaFile:write(json.encode(bkaData))
			bkaFile:close()
		end
	end
    
	local function LoadBkaData(steamId)
		local result = nil
		local bkaFilename = GetBkaFilename(steamId)
		local bkaFile = io.open(bkaFilename, "r")
		if bkaFile then
			result = json.decode(bkaFile:read("*all")) or { }
			bkaFile:close()
		end
		return result
	end

	local function GetMostRecentBka(bkaData)
		local result = nil
			if bkaData ~= nil and bkaData.names ~= nil and #bkaData.names > 0 then
				result = bkaData.names[0]
			end
		return result
	end
	
	local function ShowCurrentBka(client, targetSteamId)
		ServerAdminPrint(client, "[BKA] Current BKA:")
		local steamId = client:GetUserId()
		local bkaData = LoadBkaData(targetSteamId)
		if bkaData == nil or bkaData.names == nil or #bkaData.names == 0 then
			ServerAdminPrint(client, "[BKA]     (none)")
		else
			for i = 1, #bkaData.names, 1 do
				local name = bkaData.names[i]
				ServerAdminPrint(client, "[BKA]     " .. name)
			end
		end
	end
    
	local function ShowUsage(client, targetSteamId) 
		ServerAdminPrint(client, "[BKA]")
		ServerAdminPrint(client, "[BKA] Usage:")
		ServerAdminPrint(client, "[BKA]     sv_bka <target> <bka>")
		ServerAdminPrint(client, "[BKA] Notes:")
		ServerAdminPrint(client, "[BKA] * Keep the BKA short.")
		ServerAdminPrint(client, "[BKA] * Most recent (highest) BKA is enforced.")
		ServerAdminPrint(client, "[BKA] * <bka> of 'clear' removes all BKA names")
		if targetSteamId ~= nil then
			ShowCurrentBka(client, targetSteamId)
		end
		ServerAdminPrint(client, "[BKA]")
	end
	
	local function svBka(client, playerName, ...)
		local targetPlayer = GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = Server.GetOwner(targetPlayer)
			if targetClient ~= nil then
				local targetSteamId = targetClient:GetUserId()
				local newBkaName = GetBkaName(...)
				if newBkaName ~= "" then
					local newBkaData = { steamId = targetSteamId, names = {} }
					if newBkaName ~= "clear" then
						table.insert(newBkaData.names, newBkaName)
						local existingBkaData = LoadBkaData(targetSteamId)
						if existingBkaData ~= nil then
							if existingBkaData.names ~= nil then
								for i = 1, #existingBkaData.names, 1 do
									local existingName = existingBkaData.names[i]
									if existingName ~= newBkaName then
										table.insert(newBkaData.names, existingName)
									end
								end
							end
						end
					end
					SaveBka(newBkaData)
					ShowCurrentBka(client, targetSteamId)
				else
					ShowUsage(client, targetSteamId)
				end
			else
				ServerAdminPrint(client, string.format("'%s' uniquely matches a player, but no client found.", playerName))
			end
		else
			if playerName == nil then
				ShowUsage(client, nil)
			else
				ServerAdminPrint(client, string.format("'%s' does not uniquely match a player.", playerName))
			end
			
		end
	end
	DAKCreateServerAdminCommand("Console_sv_bka", svBka, "<target> <bka> Adds a BKA name to the target.")
	
	local function BkaOnTeamJoin(player, newTeamNumber, force)
		local result = true
		local client = Server.GetOwner(player)
		local steamId = client:GetUserId()
		local bkaData = LoadBkaData(steamId)
		if bkaData ~= nil and bkaData.names ~= nil and #bkaData.names > 0 then
			local bkaName = "[" .. bkaData.names[1] .. "]"
			local playerNameStartsWithBkaName = string.sub(player.name,1,string.len(bkaName))==bkaName
			if not playerNameStartsWithBkaName then
				local chatMessage = string.format("Your name must start with '%s' before you play.", bkaName)
				Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
				result = false
			end
		end
		return result
	end
	table.insert(kDAKOnTeamJoin, function(player, newTeamNumber, force) return BkaOnTeamJoin(player, newTeamNumber, force) end)

end

Shared.Message("BetterKnownAs Loading Complete")