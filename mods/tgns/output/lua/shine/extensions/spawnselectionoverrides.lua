local md
local forcedSpawnSelectionOverrides
local currentMapSpawnSelectionOverridesData
local BRIEF_SUMMARY_TRUNCATE_LENGTH = 5

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "spawnselectionoverrides.json"

function Plugin:ForceOverrides(spawnSelectionOverrides)
	forcedSpawnSelectionOverrides = spawnSelectionOverrides
end

function Plugin:GetCurrentMapSpawnSelectionOverridesData()
	local result = currentMapSpawnSelectionOverridesData
	if not result then
		result = {}
		local currentMapSpawnSelectionsConfig = self.Config.spawnSelections[TGNS.GetCurrentMapName()]
		if currentMapSpawnSelectionsConfig then
			TGNS.DoFor(currentMapSpawnSelectionsConfig, function(s, index)
				local techPointLocationNamesLower = TGNS.Select(TGNS.GetTechPointLocationNames(), function(n) return TGNS.ToLower(n) end)
				if TGNS.Has(techPointLocationNamesLower, TGNS.ToLower(s[1])) and TGNS.Has(techPointLocationNamesLower, TGNS.ToLower(s[2])) and s[1] ~= s[2] then
					local data = {}
					data.spawnSelectionOverride = {s[1], s[2]}
					data.briefSummaryText = string.format("M: %s | A: %s", TGNS.Truncate(s[1], BRIEF_SUMMARY_TRUNCATE_LENGTH), TGNS.Truncate(s[2], BRIEF_SUMMARY_TRUNCATE_LENGTH))
					data.summaryText = string.format("Marines: %s | Aliens: %s", s[1], s[2])
					data.summaryTextLineDelimited = string.format("Marines: %s\nAliens: %s", s[1], s[2])

					data.spawnSelectionIndex = index
					table.insert(result, data)
				else
					TGNS.DebugPrint(string.format("spawnselectionoverrides ERROR: %s spawnSelectionOverride %s/%s was discarded.", TGNS.GetCurrentMapName(), s[1], s[2]))
				end
			end)
			if #result == 0 then
				TGNS.DebugPrint(string.format("%s has spawnSelectionOverrides, but none is usable.", TGNS.GetCurrentMapName()))
			end
		end
		currentMapSpawnSelectionOverridesData = result
	end
	return result
end

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create("CUSTOMSPAWNS")

	local originalResetGame
	originalResetGame = TGNS.ReplaceClassMethod("NS2Gamerules", "ResetGame", function(gamerules)
		local success, result = xpcall(function()
			if self.Config.enableForBuildNumber == Shared.GetBuildNumber() then
				if TGNS.GetHumanPlayerCount() > 0 then
				    local spawnSelections = forcedSpawnSelectionOverrides or TGNS.Select(self:GetCurrentMapSpawnSelectionOverridesData(), function(d) return d.spawnSelectionOverride end)
					if TGNS.Any(spawnSelections) then
						Server.spawnSelectionOverrides = TGNS.Select(spawnSelections, function(s)
							local spawnSelectionOverride = {}
							spawnSelectionOverride.marineSpawn = TGNS.ToLower(s[1])
							spawnSelectionOverride.alienSpawn = TGNS.ToLower(s[2])
							return spawnSelectionOverride
						end)
					end
				end
			else
				md:ToAdminNotifyError(string.format("Disabled! Configured for Build %s, but running Build %s.", self.Config.enableForBuildNumber, Shared.GetBuildNumber()))
			end
		end, debug.traceback)
		if not success then
			TGNS.EnhancedLog(string.format("spawnselectionoverrides ERROR (%s): %s", Shared.GetTime(), result))
		end
		originalResetGame(gamerules)
		-- TGNS.ScheduleAction(2, function()
		-- 	local chairLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kMarineTeamType)):GetLocationName()
		-- 	local hiveLocationName = TGNS.GetFirst(TGNS.GetEntitiesForTeam("CommandStructure", kAlienTeamType)):GetLocationName()
		-- 	md:ToAllNotifyInfo(string.format("Marines: %s - Aliens: %s", chairLocationName, hiveLocationName))
		-- end)
	end)

	-- TGNS.ScheduleAction(5, function()
	-- 	if Server.spawnSelectionOverrides ~= nil then
	-- 		Shared.Message("-- Map-original " .. TGNS.GetCurrentMapName() .. " Server.spawnSelectionOverrides: ")
	-- 		TGNS.DoForPairs(Server.spawnSelectionOverrides, function(k,v)
	-- 			Shared.Message("---- " .. v.marineSpawn .. ", " .. v.alienSpawn)
	-- 		end)
	-- 	else
	-- 		Shared.Message("-- No Server.spawnSelectionOverrides")
	-- 	end
	-- end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("spawnselectionoverrides", Plugin )