//NS2 Automatic AFK Kicker

local AFKClientTracker = { }
local lastAFKUpdate = 0

local function DisconnectClientForIdling(client)
	local language = DAKGetClientLanguageSetting(client)
	local kAFKKickDisconnectReason = DAKGetLanguageSpecificMessage("kAFKKickDisconnectReason", language)
	client.disconnectreason = string.format(kAFKKickDisconnectReason, kDAKConfig.AFKKicker.kAFKKickDelay)
	Server.DisconnectClient(client)
end

function GetIsPlayerAFK(player)

	local client = Server.GetOwner(player)
	if client ~= nil then
		for i = #AFKClientTracker, 1, -1 do
			local PEntry = AFKClientTracker[i]
			if PEntry ~= nil and PEntry.ID == client:GetUserId() then
				if player:GetViewAngles() == PEntry.MVec and player:GetOrigin() == PEntry.POrig then
					return true
				end
			end
		end	
	end
	return false
	
end

local function AFKOnClientConnect(client)

	if client:GetIsVirtual() then
		//Bots dont get afk'd
	end
	
	if client ~= nil then
		local player = client:GetControllingPlayer()
		if player ~= nil and client ~= nil then
			local PEntry = { ID = client:GetUserId(), MVec = player:GetViewAngles(), POrig = player:GetOrigin(), Time = Shared.GetTime() + kDAKConfig.AFKKicker.kAFKKickDelay, Active = true, Warn1 = false, Warn2 = false, kick = false }
			table.insert(AFKClientTracker, PEntry)
		end
	end
	
end

DAKRegisterEventHook("kDAKOnClientDelayedConnect", AFKOnClientConnect, 5)

local function UpdateAFKClient(client, PEntry, player)
	if player ~= nil then
	
		if DAKGetClientCanRunCommand(client, "sv_afkimmune") then
			return PEntry
		end
	
		local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
		PEntry.Active = true
		if player:GetViewAngles() ~= PEntry.MVec or (player:GetOrigin() ~= PEntry.POrig and player:GetIsOverhead()) or #playerList < kDAKConfig.AFKKicker.kAFKKickMinimumPlayers then
			PEntry.MVec = player:GetViewAngles()
			PEntry.POrig = player:GetOrigin()
			PEntry.Time = Shared.GetTime() + kDAKConfig.AFKKicker.kAFKKickDelay
			if PEntry.Warn2 or PEntry.Warn1 or PEntry.kick then
				PEntry.kick = false
				PEntry.Warn2 = false
				PEntry.Warn1 = false
				DAKDisplayMessageToClient(client, "kAFKKickReturnMessage")
			end
			return PEntry
		end
		
		if PEntry.kick and PEntry.Time < Shared.GetTime() then
			DAKDisplayMessageToClient(client, "kAFKKickMessage", player:GetName(), kDAKConfig.AFKKicker.kAFKKickDelay)
			DisconnectClientForIdling(client)
			return nil
		end
		
		if not PEntry.Warn1 and PEntry.Time < (Shared.GetTime() + kDAKConfig.AFKKicker.kAFKKickWarning1) then
			DAKDisplayMessageToClient(client, "kAFKKickWarningMessage1", kDAKConfig.AFKKicker.kAFKKickWarning1)
			PEntry.Warn1 = true
		end
		
		if not PEntry.Warn2 and PEntry.Time < (Shared.GetTime() + kDAKConfig.AFKKicker.kAFKKickWarning2) then
			DAKDisplayMessageToClient(client, "kAFKKickWarningMessage2", kDAKConfig.AFKKicker.kAFKKickWarning2)
			PEntry.Warn2 = true
		end
		
		if PEntry.Warn2 and PEntry.Warn1 and PEntry.Time < Shared.GetTime() then
			DAKDisplayMessageToClient(client, "kAFKKickClientMessage", kDAKConfig.AFKKicker.kAFKKickDelay)
			PEntry.kick = true
		end
		
		return PEntry
	end

end

local function AFKOnClientDisconnect(client)    

	if #AFKClientTracker > 0 then
		for i = 1, #AFKClientTracker do
			local PEntry = AFKClientTracker[i]
			if PEntry ~= nil and client ~= nil then
				if PEntry.ID == client:GetUserId() then
					AFKClientTracker[i] = nil
					break
				end
			end
		end
	end
	
end

DAKRegisterEventHook("kDAKOnClientDisconnect", AFKOnClientDisconnect, 5)

local function ProcessPlayingUsers(deltatime)

	if #AFKClientTracker > 0 and lastAFKUpdate + kDAKConfig.AFKKicker.kAFKKickCheckDelay < Shared.GetTime() then
		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		for i = #AFKClientTracker, 1, -1 do
			local PEntry = AFKClientTracker[i]
			if PEntry ~= nil then
				PEntry.Active = false
				for _, player in ientitylist(playerRecords) do
					if player ~= nil then
						local client = Server.GetOwner(player)
						if client ~= nil then
							if PEntry.ID == client:GetUserId() then
								AFKClientTracker[i] = UpdateAFKClient(client, PEntry, player)
							end
						end
					end
				end
				if not PEntry.Active then
					AFKClientTracker[i] = nil
				end
			else
				AFKClientTracker[i] = nil
			end
		end
		lastAFKUpdate = Shared.GetTime()
	end
	
end

DAKRegisterEventHook("kDAKOnServerUpdate", ProcessPlayingUsers, 5)