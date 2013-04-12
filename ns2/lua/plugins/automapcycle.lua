//NS2 Automatic MapCycle

local lastcheck = DAK.config.automapcycle.kAutoMapCycleDuration * 60
local checkint = 60

local function UpdateMapCycle(deltatime)

	local t = Shared.GetTime()
	if lastcheck < t then
		lastcheck = t + checkint
		local CurPlayers = Server.GetNumPlayers()
		if CurPlayers <= DAK.config.automapcycle.kMaximumPlayers and t > (DAK.config.automapcycle.kAutoMapCycleDuration * 60) then
			if DAK.config.automapcycle.kUseStandardMapCycle then
				MapCycle_CycleMap()
			else
				local nextmap
				local MaxMaps = #DAK.config.automapcycle.kMapCycleMaps
				if MaxMaps > 0 then
					for i = 1, 100 do //Meh
						local tmpmap = DAK.config.automapcycle.kMapCycleMaps[math.random(1,MaxMaps)]
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

DAK:RegisterEventHook("OnServerUpdate", UpdateMapCycle, 5, "automapcycle")