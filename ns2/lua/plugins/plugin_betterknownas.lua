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

	local function ShowCurrentBka(client, targetSteamId)
		local steamId = client:GetUserId()
		local bkaData = LoadBkaData(targetSteamId)
		local player = TGNS:GetPlayerMatchingSteamId(targetSteamId)
		ServerAdminPrint(client, "[BKA] ")
		if player ~= nil then
			ServerAdminPrint(client, "[BKA] For: " .. player:GetName())
			ServerAdminPrint(client, "[BKA] ")
		end
		ServerAdminPrint(client, "[BKA] BKA:")
		if bkaData == nil or bkaData.BKA == nil or string.len(bkaData.BKA) == 0 then
			ServerAdminPrint(client, "[BKA]     (none)")
		else
			ServerAdminPrint(client, "[BKA]     " .. bkaData.BKA)
		end
		ServerAdminPrint(client, "[BKA] AKAs:")
		if bkaData == nil or bkaData.AKAs == nil or #bkaData.AKAs == 0 then
			ServerAdminPrint(client, "[BKA]     (none)")
		else
			for i = 1, #bkaData.AKAs, 1 do
				local name = bkaData.AKAs[i]
				ServerAdminPrint(client, "[BKA]     " .. name)
			end
		end
	end
    
	local function ShowUsage(client, targetSteamId) 
		ServerAdminPrint(client, "[BKA]")
		ServerAdminPrint(client, "[BKA] Usage:")
		ServerAdminPrint(client, "[BKA]     sv_aka <target> <aka>")
		ServerAdminPrint(client, "[BKA]     sv_bka <target> <bka>")
		ServerAdminPrint(client, "[BKA] Notes:")
		ServerAdminPrint(client, "[BKA] * Keep the BKA/AKA short.")
		ServerAdminPrint(client, "[BKA] * BKA is enforced.")
		ServerAdminPrint(client, "[BKA] * <bka> of 'clear' removes enforced BKA name")
		ServerAdminPrint(client, "[BKA] * <aka> of 'clear' removes all AKA names")
		if targetSteamId ~= nil then
			ShowCurrentBka(client, targetSteamId)
		end
		ServerAdminPrint(client, "[BKA]")
	end

	local function AddAka(targetSteamId, newBkaName, allowClearParameterToRemoveAllAkaValues)
		local newBkaData = { steamId = targetSteamId, AKAs = {}, BKA = "" }
		table.insert(newBkaData.AKAs, newBkaName)
		local existingBkaData = LoadBkaData(targetSteamId)
		if newBkaName ~= "clear" or not allowClearParameterToRemoveAllAkaValues then
			if existingBkaData ~= nil then
				if existingBkaData.AKAs ~= nil and #existingBkaData.AKAs > 0 then
					for i = 1, #existingBkaData.AKAs, 1 do
						local existingName = existingBkaData.AKAs[i]
						if existingName ~= newBkaName then
							table.insert(newBkaData.AKAs, existingName)
						end
					end
				end
			end
		end
		if (existingBkaData ~= nil) then
			newBkaData.BKA = existingBkaData.BKA
		end
		SaveBka(newBkaData)
	end
	
	local function svAka(client, playerName, ...)
		local targetPlayer = TGNS:GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = Server.GetOwner(targetPlayer)
			if targetClient ~= nil then
				local targetSteamId = targetClient:GetUserId()
				local newBkaName = GetBkaName(...)
				if newBkaName ~= "" then
					AddAka(targetSteamId, newBkaName, true)
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
	DAKCreateServerAdminCommand("Console_sv_aka", svAka, "<target> <aka> Adds an AKA name to the target.")

	local function svBka(client, playerName, ...)
		local targetPlayer = TGNS:GetPlayerMatching(playerName, nil)
		if targetPlayer ~= nil then
			local targetClient = Server.GetOwner(targetPlayer)
			if targetClient ~= nil then
				local targetSteamId = targetClient:GetUserId()
				local newBkaName = GetBkaName(...)
				if newBkaName ~= "" then
					local existingBkaData = LoadBkaData(targetSteamId)
					local newBkaData = { steamId = targetSteamId, AKAs = {}, BKA = "" }
					if existingBkaData ~= nil then
						if existingBkaData.AKAs ~= nil then
							for i = 1, #existingBkaData.AKAs, 1 do
								local existingName = existingBkaData.AKAs[i]
								table.insert(newBkaData.AKAs, existingName)
							end
						end
					end
					if newBkaName ~= "clear" then
						newBkaData.BKA = newBkaName
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
	
	local function EvaluatePlayerName(player, name)
	    local client = Server.GetOwner(player)
		if client ~= nil then
			local steamId = client:GetUserId()
			local bkaData = LoadBkaData(steamId)
			if bkaData ~= nil and bkaData.BKA ~= nil and string.len(bkaData.BKA) > 0 then
				local bkaName = "[" .. bkaData.BKA .. "]"
				local playerNameStartsWithBkaName = string.sub(name,1,string.len(bkaName))==bkaName
				if not playerNameStartsWithBkaName then
					local chatMessage = string.format("Your name must start with '%s' before you play.", bkaName)
					Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. kDAKConfig.DAKLoader.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
					TGNS:PMAllPlayersWithAccess(nil, name .. " needs to add '" .. bkaName .. "' BKA value to playername.", "sv_bka", false)
					return false
				end
			end
		end
		return true
	end

	local function BkaOnTeamJoin(self, player, newTeamNumber, force)
		local result = not (newTeamNumber == kTeamReadyRoom or EvaluatePlayerName(player, player:GetName()))
		return result
	end
	DAKRegisterEventHook(kDAKOnTeamJoin, BkaOnTeamJoin, 5)

	function BkaOnCommandSetName(client, name)
		local player = client:GetControllingPlayer()
		name=TrimName(name)
		if name ~= kDefaultPlayerName and string.len(name) > 0 then
			local playerTeamNumber = player:GetTeamNumber()
			if playerTeamNumber == kMarineTeamType or playerTeamNumber == kAlienTeamType then
				local gamerules = GetGamerules()
				if gamerules then
					if EvaluatePlayerName(player, name) == false then
						gamerules:JoinTeam(player, kTeamReadyRoom)
					end
				end
			end
			local steamId = client:GetUserId()
			AddAka(steamId, name, false)
		end
	end
	Event.Hook("Console_name", BkaOnCommandSetName)

end

Shared.Message("BetterKnownAs Loading Complete")