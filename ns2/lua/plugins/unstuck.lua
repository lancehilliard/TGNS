//NS2 Unstuck Plugin

local UnstuckClientTracker = { }
local LastUnstuckTracker = { }

local function UnstuckClient(client, player, PEntry)

	if PEntry.Orig ~= player:GetOrigin() then
		DAK:DisplayMessageToClient(client, "UnstuckMoved")
	else
		local TechID = kTechId.Skulk
		if player:GetIsAlive() then
			TechID = player:GetTechId()
		end
		PEntry.Orig.x = PEntry.Orig.x + (math.random(-1,1) * DAK.config.unstuck.kUnstuckAmount)
		PEntry.Orig.z = PEntry.Orig.z + (math.random(-1,1) * DAK.config.unstuck.kUnstuckAmount)
		local extents = LookupTechData(TechID, kTechDataMaxExtents)
		local capsuleHeight, capsuleRadius = GetTraceCapsuleFromExtents(extents)
		local range = 6
		for t = 1, 100 do //Persistance...
			local spawnPoint = GetRandomSpawnForCapsule(capsuleHeight, capsuleRadius, PEntry.Orig, 2, range, EntityFilterAll())
			if spawnPoint then
				local validForPlayer = GetIsPlacementForTechId(spawnPoint, true, TechID)
				local notNearResourcePoint = #GetEntitiesWithinRange("ResourcePoint", spawnPoint, 2) == 0
				if notNearResourcePoint then
					SpawnPlayerAtPoint(player, spawnPoint)
					break
				end
			end
		end
		DAK:DisplayMessageToClient(client, "Unstuck")
	end

end

local function ProcessStuckUsers(deltatime)

	if #UnstuckClientTracker > 0 then
		local playerRecords = Shared.GetEntitiesWithClassname("Player")
		for i = #UnstuckClientTracker, 1, -1 do
			local PEntry = UnstuckClientTracker[i]
			if PEntry ~= nil then
				if PEntry.Time and PEntry.Time < Shared.GetTime() then
					for _, player in ientitylist(playerRecords) do
						if player ~= nil then
							local client = Server.GetOwner(player)
							if client ~= nil then
								if PEntry.ID == client:GetUserId() then
									//Client still active, unstuck them
									UnstuckClient(client, player, PEntry)
									LastUnstuckTracker[PEntry.ID] = Shared.GetTime()
									UnstuckClientTracker[i] = nil
								end
							else
								UnstuckClientTracker[i] = nil
							end
						else
							UnstuckClientTracker[i] = nil
						end
					end
				end
			else
				UnstuckClientTracker[i] = nil
			end
		end
	end
	if #UnstuckClientTracker == 0 then
		DAK:DeregisterEventHook("OnServerUpdate", ProcessStuckUsers)
	end
	
end

DAK:RegisterEventHook("OnServerUpdate", ProcessStuckUsers, 5, "unstuck")

local function RegisterClientStuck(client)
	if client ~= nil then
		local ID = client:GetUserId()
		if LastUnstuckTracker[ID] == nil or LastUnstuckTracker[ID] + DAK.config.unstuck.kTimeBetweenUntucks < Shared.GetTime() then
			local player = client:GetControllingPlayer()
			local PEntry = { ID = client:GetUserId(), Orig = player:GetOrigin(), Time = Shared.GetTime() + DAK.config.unstuck.kMinimumWaitTime }
			DAK:DisplayMessageToClient(client, "UnstuckIn", DAK.config.unstuck.kMinimumWaitTime)
			if #UnstuckClientTracker == 0 then
				DAK:RegisterEventHook("OnServerUpdate", ProcessStuckUsers, 5, "unstuck")
			end
			table.insert(UnstuckClientTracker, PEntry)
		else
			DAK:DisplayMessageToClient(client, "UnstuckRecently", (LastUnstuckTracker[ID] + DAK.config.unstuck.kTimeBetweenUntucks) - Shared.GetTime())
		end
	end
end

Event.Hook("Console_stuck",               RegisterClientStuck)
Event.Hook("Console_unstuck",               RegisterClientStuck)

DAK:RegisterChatCommand(DAK.config.unstuck.kUnstuckChatCommands, RegisterClientStuck, false)