local md
local originalResetGame
local originalSpawnSelectionOverrides

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "spawnselectionoverrides.json"

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create("SPAWNS")

	originalResetGame = TGNS.ReplaceClassMethod("NS2Gamerules", "ResetGame", function(gamerules)
		local success, result = xpcall(function()
		    local spawnSelections = self.Config.spawnSelections[TGNS.GetCurrentMapName()]
			if spawnSelections then
				local spawnSelectionOverrides = {}
				TGNS.DoFor(spawnSelections, function(s)
					local techPointLocationNamesLower = TGNS.Select(TGNS.GetTechPointLocationNames(), function(n) return TGNS.ToLower(n) end)
					if TGNS.Has(techPointLocationNamesLower, TGNS.ToLower(s[1])) and TGNS.Has(techPointLocationNamesLower, TGNS.ToLower(s[2])) and s[1] ~= s[2] then
						local spawnSelectionOverride = {}
						spawnSelectionOverride.marineSpawn = TGNS.ToLower(s[1])
						spawnSelectionOverride.alienSpawn = TGNS.ToLower(s[2])
						table.insert(spawnSelectionOverrides, spawnSelectionOverride)
					else
						TGNS.EnhancedLog(string.format("SPAWNS ERROR: %s spawnSelection %s/%s was not used.", TGNS.GetCurrentMapName(), s[1], s[2]))
					end
				end)
				if originalSpawnSelectionOverrides == nil then
					originalSpawnSelectionOverrides = Server.spawnSelectionOverrides
				end
				if #spawnSelectionOverrides >= 1 then
					Server.spawnSelectionOverrides = spawnSelectionOverrides
					if #spawnSelectionOverrides == 1 then
						md:ToAdminNotifyInfo(string.format("SPAWNS NOTICE: %s only has 1 spawnSelectionOverride.", TGNS.GetCurrentMapName()))
					end
				else
					md:ToAdminNotifyError(string.format("SPAWNS ERROR: %s has spawnSelectionOverrides, but none is usable.", TGNS.GetCurrentMapName()))
				end
		    end
		end, debug.traceback)
		if not success then
			TGNS.EnhancedLog(string.format("spawnselectionoverrides Error (%s): %s", Shared.GetTime(), result))
		end
		originalResetGame(gamerules)
		-- TGNS.ScheduleAction(2, function()
		-- 	local chairLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kMarineTeamType)):GetLocationName()
		-- 	local hiveLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kAlienTeamType)):GetLocationName()
		-- 	md:ToAllNotifyInfo(string.format("Marines: %s - Aliens: %s", chairLocationName, hiveLocationName))
		-- end)
	end)

	-- TGNS.ScheduleAction(5, function()
	-- 	if originalSpawnSelectionOverrides ~= nil then
	-- 		Shared.Message("-- Map-original " .. TGNS.GetCurrentMapName() .. " Server.spawnSelectionOverrides: ")
	-- 		TGNS.DoForPairs(originalSpawnSelectionOverrides, function(k,v)
	-- 			Shared.Message("---- " .. v.marineSpawn .. ", " .. v.alienSpawn)
	-- 		end)
	-- 	end
	-- end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("spawnselectionoverrides", Plugin )