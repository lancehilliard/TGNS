//NS2 Automatic MapCycle

if kDAKConfig and kDAKConfig.AutoMapCycle then

	local lastcheck = 0
	local checkint = 1

	local function UpdateMapCycle(deltatime)
	
		local t = Shared.GetTime()
		if lastcheck + checkint < t then
			lastcheck = t
			local playerRecords = Shared.GetEntitiesWithClassname("Player")
			if (playerRecords == nil or playerRecords:GetSize() <= kDAKConfig.AutoMapCycle.kMaximumPlayers) and t > (kDAKConfig.AutoMapCycle.kAutoMapCycleDuration * 60) then
				if kDAKConfig.AutoMapCycle.kUseStandardMapCycle then
					MapCycle_CycleMap()
				else
					local nextmap
					local MaxMaps = #kDAKConfig.AutoMapCycle.kMapCycleMaps
					if MaxMaps > 0 then
						for i = 1, 100 do //Meh
							local tmpmap = kDAKConfig.AutoMapCycle.kMapCycleMaps[math.random(1,MaxMaps)]
							if tmpmap ~= tostring(Shared.GetMapName()) then
								nextmap = tmpmap
								break
							end
						end
						MapCycle_ChangeToMap(nextmap)
					end
				end
			elseif playerRecords ~= nil and playerRecords:GetSize() > kDAKConfig.AutoMapCycle.kMaximumPlayers then
				DAKDeregisterEventHook(kDAKOnServerUpdate, UpdateMapCycle)
			end
		end
		
	end
	
	DAKRegisterEventHook(kDAKOnServerUpdate, UpdateMapCycle, 5)
	
	local function AutoConcedeOnClientDisconnect(client)
		DAKRegisterEventHook(kDAKOnServerUpdate, UpdateMapCycle, 5)
	end
	
	DAKRegisterEventHook(kDAKOnClientDisconnect, AutoConcedeOnClientDisconnect, 5)
	
end

Shared.Message("AutoMapCycle Loading Complete")