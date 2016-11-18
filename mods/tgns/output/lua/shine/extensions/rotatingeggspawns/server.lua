Plugin.HasConfig = false
-- Plugin.ConfigName = "rotatingeggspawns.json"

local pityEggGivenWhen = {}

function Plugin:ClientConfirmConnect(client)
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

    TGNS.ScheduleAction(5, function()
	    if LocateUpValue then
	    	local _, GetNumEggs = LocateUpValue(Hive.UpdateSpawnEgg, "GetNumEggs", {LocateRecurse = true})
	    	local originalSharedSortEntitiesByDistance = Shared.SortEntitiesByDistance
			local parent, originalUpdateEggGeneration = LocateUpValue(AlienTeam.Update, "UpdateEggGeneration", {LocateRecurse = true})
			local function UpdateEggGeneration(alienTeamSelf)
				Shared.SortEntitiesByDistance = function(origin, entities)
					originalSharedSortEntitiesByDistance(origin, entities)
					if #entities > 0 then
						local hiveEligibleForPityEgg = TGNS.FirstOrNil(entities, function(hive) return GetNumEggs(hive) == 0 and Shared.GetTime() - (pityEggGivenWhen[hive] or 0) > 30 end)
						if hiveEligibleForPityEgg then
							TGNS.SortAscending(entities, function(hive) return hiveEligibleForPityEgg == hive and 0 or 1 end)
							Shared.Message(string.format("pityEggGivenWhen[hiveEligibleForPityEgg] %s: %s", hiveEligibleForPityEgg:GetLocationName(), Shared.GetTime()))
							pityEggGivenWhen[hiveEligibleForPityEgg] = Shared.GetTime()
						end
					end
				end
				originalUpdateEggGeneration(alienTeamSelf)
				Shared.SortEntitiesByDistance = originalSharedSortEntitiesByDistance
			end
			ReplaceUpValue(parent, "UpdateEggGeneration", UpdateEggGeneration, {LocateRecurse = true})
	    end
    end)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end