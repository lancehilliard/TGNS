//NS2 Automatic MapCycle

if kDAKConfig and kDAKConfig.AutoMapCycle then

	local function UpdateMapCycle(deltatime)
	
		if Shared.GetTime() > (kDAKConfig.AutoMapCycle.kAutoMapCycleDuration * 60) then
			local playerRecords = Shared.GetEntitiesWithClassname("Player")
			if playerRecords == nil or playerRecords:GetSize() <= kDAKConfig.AutoMapCycle.kMaximumPlayers then
				if kDAKConfig.AutoMapCycle.kUseStandardMapCycle then
					MapCycle_CycleMap()
				else
					local nextmap
					local MaxMaps = #kDAKConfig.AutoMapCycle.kMapCycleMaps
					if MaxMaps > 0 then
						for i = 1, 100 do
							local tmpmap = kDAKConfig.AutoMapCycle.kMapCycleMaps[math.random(1,MaxMaps)]
							if tmpmap ~= tostring(Shared.GetMapName()) then
								nextmap = tmpmap
								break
							end
						end
						MapCycle_ChangeToMap(nextmap)
					end
				end
			end
		end
		
	end
	
	DAKRegisterEventHook(kDAKOnServerUpdate, function(deltatime) return UpdateMapCycle(deltatime) end, 5)
	
end

Shared.Message("AutoMapCycle Loading Complete")