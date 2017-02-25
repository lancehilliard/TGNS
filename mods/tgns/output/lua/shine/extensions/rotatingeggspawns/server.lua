Plugin.HasConfig = false
-- Plugin.ConfigName = "rotatingeggspawns.json"

local pityEggGivenWhen = {}

function Plugin:ClientConfirmConnect(client)
end

-- function Plugin:CreateCommands()
-- 	local killAllEggsCommand = self:BindCommand( "sh_killalleggs", nil, function(client)
-- 		local eggs = GetEntitiesForTeam("Egg", 2)
-- 	    for index, egg in ipairs(eggs) do
-- 	    	egg:Kill()        
-- 	    end
-- 	end)
-- 	killAllEggsCommand:Help("Kill all eggs.")
-- end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

    TGNS.ScheduleAction(5, function()
	    if LocateUpValue then
	    	local _, GetNumEggs = LocateUpValue(Hive.UpdateSpawnEgg, "GetNumEggs", {LocateRecurse = true})
	    	local originalSharedSortEntitiesByDistance = Shared.SortEntitiesByDistance
	    	local modifiedSortEntitiesByDistance = function(origin, entities)
				originalSharedSortEntitiesByDistance(origin, entities)
				if #entities > 0 then
					local firstCurrentHiveOrigin = entities[1]:GetOrigin()
					local desiredSpawnPoints = TGNS.Select(TGNS.GetAlienPlayers(TGNS.GetPlayerList()), function(p) return p.desiredSpawnPoint or firstCurrentHiveOrigin end)
					local desiredSpawnPointsCount = #desiredSpawnPoints
					if desiredSpawnPointsCount > 0 then
						local desiredSpawnPointsSum = Vector(0, 0, 0)
						TGNS.DoFor(desiredSpawnPoints, function(spawnPoint) desiredSpawnPointsSum = desiredSpawnPointsSum + spawnPoint end)
						local desiredSpawnPointsAverage = desiredSpawnPointsSum / desiredSpawnPointsCount
						TGNS.SortAscending(entities, function(hive)
							local distance = (desiredSpawnPointsAverage - Vector(hive:GetOrigin())):GetLength()
							local eggCountModifier = 100000
							if GetNumEggs(hive) == 0 then
								if Shared.GetTime() - (pityEggGivenWhen[hive] or 0) > 30 then
									pityEggGivenWhen[hive] = Shared.GetTime()
									eggCountModifier = 0
								end
							end
							local result = distance + eggCountModifier
							return result
						end)
					end
				end
			end
			-- local parent, originalUpdateEggGeneration = LocateUpValue(AlienTeam.Update, "UpdateEggGeneration", {LocateRecurse = true})
			-- local function UpdateEggGeneration(alienTeamSelf)
			-- 	Shared.SortEntitiesByDistance = modifiedSortEntitiesByDistance
			-- 	originalUpdateEggGeneration(alienTeamSelf)
			-- 	Shared.SortEntitiesByDistance = originalSharedSortEntitiesByDistance
			-- end
			-- ReplaceUpValue(parent, "UpdateEggGeneration", UpdateEggGeneration, {LocateRecurse = true})
			local originalAlienTeamUpdateEggGeneration = AlienTeam.UpdateEggGeneration
			AlienTeam.UpdateEggGeneration = function(alienTeamSelf)
				Shared.SortEntitiesByDistance = modifiedSortEntitiesByDistance
				originalAlienTeamUpdateEggGeneration(alienTeamSelf)
				Shared.SortEntitiesByDistance = originalSharedSortEntitiesByDistance
			end

	    end
    end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end