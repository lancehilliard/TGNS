local TdMapName = "ns2_tgns_td"
local NetworkMessageNames = {WaveInProgress = "td_WaveInProgress", RecentlyWelded = "td_RecentlyWelded"}
local waveInProgress
local recentlyWeldedTime = {}
local recentWeldTimespanInSeconds = 3
local recentWeldEffectEnabled
-- kCatPackDuration = 60

TGNS.RegisterNetworkMessage(NetworkMessageNames.WaveInProgress, {i="boolean"})
TGNS.RegisterNetworkMessage(NetworkMessageNames.RecentlyWelded, {i="integer", t="float"})

local function wasRecentlyWelded(player)
	local result = false
	if player and player.GetTeamNumber and player.GetClientIndex then
		result = player:GetTeamNumber() == kMarineTeamType and Shared.GetTime() - (recentlyWeldedTime[player:GetClientIndex()] or 0) < recentWeldTimespanInSeconds
	end
	return result
end

Event.Hook("MapPostLoad", function()
	if Shared.GetMapName() == TdMapName then
	 	local originalMarineSetOrigin
		originalMarineSetOrigin = Class_ReplaceMethod("Marine", "SetOrigin", function(marineSelf, newOrigin)
			if not waveInProgress then
				originalMarineSetOrigin(marineSelf, newOrigin)
			end
		end)



	 -- 	local originalLOSMixinOnUpdate
		-- originalLOSMixinOnUpdate = Class_ReplaceMethod("LOSMixin", "OnUpdate", function(losMixinSelf, deltaTime)
		-- 	losMixinSelf.sighted = true
		-- 	originalLOSMixinOnUpdate(marineSelf, deltaTime)
		-- end)

		Grenade.kMinLifeTime = 0

		Class_ReplaceMethod("Player", "GetCanTakeDamageOverride", function(playerSelf)
			return false
		end)

		local originalMarineOnUpdateAnimationInput = Marine.OnUpdateAnimationInput
		Marine.OnUpdateAnimationInput = function(marineSelf, modelMixin)
			local originalMarineSelfCatpackboost = marineSelf.catpackboost
			marineSelf.catpackboost = true
			originalMarineOnUpdateAnimationInput(marineSelf, modelMixin)
			marineSelf.catpackboost = originalMarineSelfCatpackboost
		end


		local originalLOSMixinOnUpdate = LOSMixin.OnUpdate
		LOSMixin.OnUpdate = function(losMixinSelf, deltaTime)
			if originalLOSMixinOnUpdate then
				if losMixinSelf.GetIsAlive and losMixinSelf:GetIsAlive() then
					losMixinSelf.sighted = true
				end
				originalLOSMixinOnUpdate(losMixinSelf, deltaTime)
			end
		end

		local originalFlamethrowerFirePrimary = Flamethrower.FirePrimary
		Flamethrower.FirePrimary = function(flamethrowerSelf, player, bullets, range, penetration)
			local originalGetRange = flamethrowerSelf.GetRange
			flamethrowerSelf.GetRange = function(flamethrowerSelfSelf)
				local result = originalGetRange(flamethrowerSelfSelf)
				if wasRecentlyWelded(player) then
					result = result * 2
				end
				return result
			end
			originalFlamethrowerFirePrimary(flamethrowerSelf, player, bullets, range, penetration)
			flamethrowerSelf.GetRange = originalGetRange
		end

		local originalBuildTechData = BuildTechData
		BuildTechData = function()
			local result = originalBuildTechData()
			TGNS.DoFor(result, function(d)
				if d[kTechDataId] == kTechId.Sentry then
					d[kTechDataBuildRequiresMethod] = function(techId, origin, normal, commander) return true end
					d[kTechDataSupply] = 5
				elseif d[kTechDataId] == kTechId.SentryBattery then
					d[kTechDataBuildRequiresMethod] = function(techId, origin, normal, commander) return true end
					-- d[kTechDataCostKey] = 1
				end
				if not TGNS.Has({kTechId.MedPack, kTechId.AmmoPack, kTechId.CatPack}, d[kTechDataId]) then
					local originalBuildRequiresMethod = d[kTechDataBuildRequiresMethod]
					d[kTechDataBuildRequiresMethod] = function()
						local result = originalBuildRequiresMethod and originalBuildRequiresMethod() or true
						if result and waveInProgress then
							result = false
						end
						return result
					end
				end
			end)
			return result
		end
		kTechData = nil
		ClearCachedTechData()

		local originalLookupTechData = LookupTechData
		LookupTechData = function(techId, fieldName, default)
			local result
			if fieldName == kTechDataBuildMethodFailedMessage and waveInProgress then
				result = "Wave in progress."
			else
				result = originalLookupTechData(techId, fieldName, default)
			end
			return result
		end

		if Client then
			local originalMarineOutlineMixinOnUpdate = MarineOutlineMixin.OnUpdate
			MarineOutlineMixin.OnUpdate = function(marineOutlineMixinSelf, deltaTime)
				-- Shared.Message("marineOutlineMixinSelf:GetRenderModel(): " .. tostring(marineOutlineMixinSelf:GetRenderModel()))
				local originalClientGetOutlinePlayers = Client.GetOutlinePlayers
				local originalClientGetLocalClientTeamNumber = Client.GetLocalClientTeamNumber
				local originalkEquipmentOutlineColorTSFBlue = kEquipmentOutlineColor.TSFBlue
				--local originalMarineOutlineMixinSelfGetRenderModel = marineOutlineMixinSelf.GetRenderModel
				if wasRecentlyWelded(marineOutlineMixinSelf) then
					-- Shared.Message("wasRecentlyWelded(marineOutlineMixinSelf): " .. tostring(wasRecentlyWelded(marineOutlineMixinSelf)))
					Client.GetOutlinePlayers = function()
						return true
					end
					Client.GetLocalClientTeamNumber = function()
						return kSpectatorIndex
					end
					kEquipmentOutlineColor.TSFBlue = kEquipmentOutlineColor.Yellow
					-- marineOutlineMixinSelf.GetRenderModel = function(marineOutlineMixinSelfSelf)
					-- 	return marineOutlineMixinSelfSelf:GetActiveWeapon():GetRenderModel()
					-- end
				end
				originalMarineOutlineMixinOnUpdate(marineOutlineMixinSelf, deltaTime)
				Client.GetOutlinePlayers = originalClientGetOutlinePlayers
				Client.GetLocalClientTeamNumber = originalClientGetLocalClientTeamNumber
				kEquipmentOutlineColor.TSFBlue = originalkEquipmentOutlineColorTSFBlue
				--marineOutlineMixinSelf.GetRenderModel = originalMarineOutlineMixinSelfGetRenderModel
				-- Shared.Message("Shared.GetTime(): " .. tostring(Shared.GetTime()))
			end
		end

	end
end)

if Predict or Client then
	TGNS.HookNetworkMessage(NetworkMessageNames.WaveInProgress, function(message)
		waveInProgress = message.i
	end)
	TGNS.HookNetworkMessage(NetworkMessageNames.RecentlyWelded, function(message)
		recentlyWeldedTime[message.i] = message.t
	end)
end

if Server or Client then
	local Plugin = {}

	local TD = {}

	if Client then
	end

	if Server then
		Plugin.HasConfig = true
		Plugin.ConfigName = "td.json"
	end

	local function OnClientInitialise()
		function Plugin:Think(deltaTime)
			if recentlyWeldedTime[Client.GetLocalClientIndex()] then
			 	local recentlyWelded = wasRecentlyWelded(Client.GetLocalPlayer())
			 	if recentlyWelded ~= recentWeldEffectEnabled then
		 			Player.screenEffects.darkVision = Player.screenEffects.darkVision or Client.CreateScreenEffect("shaders/Blur.screenfx")
		 			Player.screenEffects.darkVision:SetActive(recentlyWelded)
			 		recentWeldEffectEnabled = recentlyWelded
			 	end
			end
		end
	end

	local function OnServerInitialise()
		Server.SetConfigSetting("force_even_teams_on_join", false)

		local WaveTextChannelId = 72
		local waveStartDelayInSeconds = 15
		local structures = {}
		local allWaveStructuresDeployed = {}
		local currentGameStartWhen = 0

		local function markPlayerAsRecentlyWelded(player)
			recentlyWeldedTime[player:GetClientIndex()] = Shared.GetTime()
			TGNS.DoFor(TGNS.GetPlayerList(), function(p)
				TGNS.SendNetworkMessageToPlayer(p, NetworkMessageNames.RecentlyWelded, {i=player:GetClientIndex(), t=Shared.GetTime()})
			end)
		end

		function Plugin:Think()
			-- if math.floor(Shared.GetTime()) % 5 == 0 then
			-- 	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			-- 		if Shared.GetTime() - (recentlyWeldedTime[p:GetClientIndex()] or 0) > recentWeldTimespanInSeconds then
			-- 			markPlayerAsRecentlyWelded(p)
			-- 		end
			-- 	end)
			-- end
		end

		local originalWelderPerformWeld = Welder.PerformWeld
		Welder.PerformWeld = function(welderSelf, player)
			local originalCheckMeleeCapsule = CheckMeleeCapsule
			CheckMeleeCapsule = function(weapon, player, damage, range, optionalCoords, traceRealAttack, scale, priorityFunc, filter, mask)
				local didHit, target, endPoint, direction, surface = originalCheckMeleeCapsule(weapon, player, damage, range, optionalCoords, traceRealAttack, scale, priorityFunc, filter, mask)
				if didHit and target and target.GetClientIndex then
					markPlayerAsRecentlyWelded(target)
				end
				return didHit, target, endPoint, direction, surface
			end
			originalWelderPerformWeld(welderSelf, player)
			CheckMeleeCapsule = originalCheckMeleeCapsule
		end

		local function limitationAdvisoryText(c, waveNumber)
			local result = ""
			if TGNS.ClientIsMarine(c) then
				result = string.format("\n\nYou %s during waves!%s", TGNS.IsClientCommander(c) and "can only drop ammo\nand catpacks" or "cannot move", waveNumber < 5 and "\nKill the moving structures!" or "")
			end
			return result
			
		end

		local function getWaveData(n)
			local waveInfo = Shine.Plugins.td.Config.Waves[n]
			if not TGNS.IsProduction() then
				-- waveInfo = "Test|Whip,0,1,5|1"
			end
			local waveData = TGNS.Split("|", waveInfo)
			local waveDamageModifier = waveData[3]
			local waveTitle = string.format("%s (Weapons Strength: %s%s)", waveData[1], math.floor(100 * waveDamageModifier), "%%")
			local structureInfos = TGNS.Select(TGNS.Split(";", waveData[2]), function(d)
				local structureData = TGNS.Split(",", d)
				return {type=structureData[1],delay=structureData[2],count=structureData[3],speed=structureData[4],damageModifier=waveDamageModifier}
			end)
			return {title=waveTitle, structures=structureInfos}
		end

		function TD.PrepareNextWave(chair, hive, waveNumber)
			waveInProgress = false
			-- local lastStructureKilledWaveNumber = waveNumber
			if #Shine.Plugins.td.Config.Waves >= waveNumber then
				local nextWaveData = getWaveData(waveNumber)

				local startDelayInSeconds = waveNumber - 1 % 5 == 0 and waveStartDelayInSeconds * 2 or waveStartDelayInSeconds
				TGNS.DoTimes(startDelayInSeconds, function(i)
					local secondsUntilWaveStart = startDelayInSeconds - i
					TGNS.ScheduleAction(startDelayInSeconds - secondsUntilWaveStart, function()
						-- if TGNS.IsGameInProgress() and chair and hive and (lastStructureKilledWaveNumber == waveNumber) then
						if TGNS.IsGameInProgress() and chair and hive then
							-- Shared.Message("secondsUntilWaveStart: " .. tostring(secondsUntilWaveStart))
							if secondsUntilWaveStart > 0 then
								TGNS.DoFor(TGNS.GetHumanClientList(), function(c)
									if secondsUntilWaveStart == startDelayInSeconds - 1 then
										TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(c), NetworkMessageNames.WaveInProgress, {i=waveInProgress})
									end
									local teamRgb = TGNS.GetTeamRgb(TGNS.GetClientTeamNumber(c))
									Shine.ScreenText.Add(WaveTextChannelId, {X = 0.5, Y = 0.6, Text = string.format("Next: Wave %s - %s%s", waveNumber, nextWaveData.title, TGNS.ClientIsMarine(c) and string.format("\nStarting %s\nPrepare and take positions.%s", secondsUntilWaveStart >= 3 and string.format("in %s seconds...", secondsUntilWaveStart + 1) or "now!", limitationAdvisoryText(c, waveNumber)) or ""), Duration = 600, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
								end)
							else
								TGNS.DoFor(TGNS.GetMarinePlayers(TGNS.GetPlayerList()), function(p)
									TGNS.AddPlayerResources(p, 10)
									local weapons = p:GetWeapons()
						    		TGNS.DoFor(weapons, function(w)
									    if w.GiveAmmo then
										    w:GiveAmmo(AmmoPack.kNumClips, true)
									    end
						    		end)
								end)
								TD.SendWave(chair, hive, waveNumber)
							end
						end
					end)
				end)
			else
				if chair and chair:GetIsAlive() then
					hive:Kill()
					TGNS.DestroyEntity(hive)
				end
			end
		end

		function TD.SendWave(chair, hive, waveNumber)
			-- Shared.Message("waveNumber: " ..tostring(waveNumber))
			local types = {}
			types.Whip = Whip.kMapName
			types.Shift = Shift.kMapName
			types.Crag = Crag.kMapName
			types.Drifter = Drifter.kMapName
			types.Shade = Shade.kMapName

			waveInProgress = true
			local waveData = getWaveData(waveNumber)

			TGNS.DoFor(TGNS.GetHumanClientList(), function(c)
				local teamRgb = TGNS.GetTeamRgb(TGNS.GetClientTeamNumber(c))
				Shine.ScreenText.Add(WaveTextChannelId, {X = 0.5, Y = 0.6, Text = string.format("Wave %s%s", string.format("%s - %s", waveNumber, waveData.title), limitationAdvisoryText(c, waveNumber)), Duration = 600, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
				TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(c), NetworkMessageNames.WaveInProgress, {i=waveInProgress})
			end)

			local waveCurrentGameStartWhen = currentGameStartWhen
			TGNS.DoFor(waveData.structures, function(s, i)
				-- Shared.Message(string.format("type: %s, delay: %s, count: %s, speed: %s", s.type, s.delay, s.count, s.speed))
				TGNS.ScheduleAction(s.delay, function()
					local theseStructuresAreIntendedForCurrentGame = waveCurrentGameStartWhen == currentGameStartWhen
					if theseStructuresAreIntendedForCurrentGame then
						TGNS.DoTimes(s.count, function()
							if TGNS.IsGameInProgress() and chair and hive then
								-- check to make sure current round is the round for which these structures were spawned
								local structure = CreateEntity(types[s.type], hive:GetOrigin(), kAlienTeamType)
								table.insert(structures, structure)

								-- local playingHumansCount = #TGNS.GetPlayingClients(TGNS.GetPlayerList())
								-- if playingHumansCount > 1 then
								-- 	structure.damageModifier = s.damageModifier
								-- end
								structure.damageModifier = s.damageModifier

								if structure.SetConstructionComplete then
									structure:SetConstructionComplete()
								end

								local modifier = s.speed
								local fireSpeedModifier = function(entity) return entity:GetIsOnFire() and .5 or 1 end

								local originalGetMaxSpeed = structure.GetMaxSpeed
								structure.GetMaxSpeed = function(structureSelf)
									local result = originalGetMaxSpeed(structureSelf)
									return result * modifier * fireSpeedModifier(structureSelf)
								end

								local originalDrifterkMoveSpeed = Drifter.kMoveSpeed
								local originalDrifterOnUpdate = Drifter.OnUpdate
								structure.kDrifterMoveSpeed = originalDrifterkMoveSpeed * modifier
								Drifter.OnUpdate = function(drifterSelf, deltaTime)
									Drifter.kMoveSpeed = drifterSelf.kDrifterMoveSpeed * fireSpeedModifier(drifterSelf)
									originalDrifterOnUpdate(drifterSelf, deltaTime)
									Drifter.kMoveSpeed = originalDrifterkMoveSpeed
								end

								if structure.SetMature then
									structure:SetMature()
								end
								structure:SetMaxHealth(structure:GetMaxHealth() * modifier)
								structure:SetMaxArmor(structure:GetMaxArmor() * modifier)
								local targetHealth = structure:GetMaxHealth()
								local targetArmor = structure:GetMaxArmor()
								if structure.matureMaxHealth then
									structure.matureMaxHealth = structure.matureMaxHealth * modifier
									structure.matureMaxArmor = structure.matureMaxArmor * modifier
									targetHealth = structure.matureMaxHealth
									targetArmor = structure.matureMaxArmor
								end
								structure:SetHealth(targetHealth)
								structure:SetArmor(targetArmor)

								structure:GiveOrder(kTechId.Move, chair:GetId(), chair:GetOrigin(), nil, true, true)

								local originalStructureOnKill = structure.OnKill
								structure.OnKill = function(structureSelf, attacker, doer, point, direction)
									originalStructureOnKill(structureSelf, attacker, doer, point, direction)
									-- TGNS.DestroyEntity(structureSelf)

									TGNS.RemoveAllMatching(structures, structure)
									if waveNumber and allWaveStructuresDeployed[waveNumber] and #structures == 0 then
										-- Shared.Message(string.format("------------------------------------------------------------------------------------------------------- allWaveStructuresDeployed[%s] == true", waveNumber))
										TD.PrepareNextWave(chair, hive, waveNumber + 1)
									end

									GetGamerules():GetTeam(kMarineTeamType):AddTeamResources(15)
									if attacker and attacker:isa("Marine") then
										TGNS.AddPlayerResources(attacker, 5)
										local weapons = attacker:GetWeapons()
							    		TGNS.DoFor(weapons, function(w)
										    if w.GiveAmmo then
											    w:GiveAmmo(AmmoPack.kNumClips, true)
										    end
							    		end)
									end
								end

								local originalStructureCompletedCurrentOrder = structure.CompletedCurrentOrder
								structure.CompletedCurrentOrder = function(structureSelf)
									originalStructureCompletedCurrentOrder(structureSelf)
									if chair then
										local lengthFromChair = (structureSelf:GetOrigin() - chair:GetOrigin()):GetLength()
										-- Shared.Message("lengthFromChair: " .. tostring(lengthFromChair))
										if lengthFromChair > 5 then
											TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c)
												Shine.ScreenText.Add(70, {X = 0.5, Y = 0.4, Text = "Blocked structures damage the chair and then die!", Duration = 6, R = 255, G = 0, B = 0, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, c)
											end)
										end
										chair:DeductHealth(chair:GetMaxHealth() * .05)
									end
									structure:Kill()
									-- TGNS.ScheduleAction(5, function()
									-- 	TGNS.DestroyEntity(structure)
									-- end)
								end
							end
						end)
						if i == #waveData.structures then
							-- Shared.Message(string.format("------------------------------------------------------------------------------------------------------- allWaveStructuresDeployed[%s] = true", waveNumber))
							allWaveStructuresDeployed[waveNumber] = true
						end
					end
				end)
			end)
		end

		TGNS.DisableUweGameReporting()

		local md = TGNSMessageDisplayer.Create("TD")

		function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
			local cancel = false
			if not (force or shineForce) then
				if newTeamNumber == kAlienTeamType then
					md:ToPlayerNotifyError(player, "TD is played on the Marine team.")
					cancel = true
				end
				if cancel then
					return false
				end
			end
		end

		function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
			local client = TGNS.GetClient(player)
			if TGNS.ClientIsMarine(client) then
				TGNS.ScheduleAction(0, function()
					if client and Shine:IsValidClient(client) and TGNS.ClientIsMarine(client) and not TGNS.IsGameInProgress() then
						TGNS.ForceGameStart()
					end
				end)
				gamerules:RespawnPlayer(player)
			end
		end

		function Plugin:EndGame(gamerules, winningTeam)
			Shine.ScreenText.End(WaveTextChannelId)
		end

		function Plugin:ClientConnect(client)
			TGNS.ScheduleAction(0, function()
				if not TGNS.IsProduction() then
					TGNS.SendToTeam(TGNS.GetPlayer(client), kMarineTeamType)
				end
				Shine.ScreenText.Add(82, {X = .5, Y = 0.95, Text = "\nTD BETA - TGNS FORUMS FOR CHANGELOG", Duration = 120, R = 255, G = 255, B = 255, Alignment = TGNS.ShineTextAlignmentCenter, Size = 1, FadeIn = 0, IgnoreFormat = true}, c)
			end)
		end

		lastNoAttackNoticeTimes = {}
		lastNoWeldNoticeTimes = {}
		function Plugin:TakeDamage( Ent, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
			if Ent and Ent:GetTeamNumber() == kAlienTeamType then
				if Ent:isa("Hive") or not Inflictor then
					Damage = 0
					ArmourUsed = 0
					HealthUsed = 0
					if Ent:isa("Hive") then
						local client = TGNS.GetClient(Attacker)
						if client and (lastNoAttackNoticeTimes[client] == nil or lastNoAttackNoticeTimes[client] < Shared.GetTime() - 1) and (Attacker:GetOrigin() - Ent:GetOrigin()):GetLength() < kHitEffectRelevancyDistance then
							local teamRgb = TGNS.GetTeamRgb(Attacker:GetTeamNumber())
							Shine.ScreenText.Add(70, {X = 0.5, Y = 0.4, Text = "You cannot damage the Hive. Attack the moving structures!", Duration = 6, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, client)
							lastNoAttackNoticeTimes[client] = Shared.GetTime()
						end
					end
				else
					if Ent.damageModifier then
						Damage = Damage * Ent.damageModifier
						ArmourUsed = ArmourUsed * Ent.damageModifier
						HealthUsed = HealthUsed * Ent.damageModifier
					end
				end
			end
			return Damage, ArmourUsed, HealthUsed
			-- return 0, 0, 0

		end


		TGNS.RegisterEventHook("GameStarted", function()
			currentGameStartWhen = Shared.GetTime()
			local chair = GetEntitiesForTeam( "CommandStation", kMarineTeamType )[1]
			local hive = GetEntitiesForTeam( "Hive", kAlienTeamType )[1]
			hive:SetMature()
			hive:SetHealth(hive:GetMatureMaxHealth())
			hive:SetArmor(hive:GetMatureMaxArmor())
			chair.GetCanBeWeldedOverride = function(chairSelf, doer)
				local client = TGNS.GetClient(doer)
				if client and (lastNoWeldNoticeTimes[client] == nil or Shared.GetTime() - lastNoWeldNoticeTimes[client] > 1) then
					local teamRgb = TGNS.GetTeamRgb(doer:GetTeamNumber())
					Shine.ScreenText.Add(71, {X = 0.5, Y = 0.4, Text = "You cannot weld the Chair. The game ends when the Chair dies. Attack the moving structures!", Duration = 6, R = teamRgb.R, G = teamRgb.G, B = teamRgb.B, Alignment = TGNS.ShineTextAlignmentCenter, Size = 3, FadeIn = 0, IgnoreFormat = true}, client)
					lastNoWeldNoticeTimes[client] = Shared.GetTime()
				end
				return false, false
			end
			TD.PrepareNextWave(chair, hive, 1)
		end)

		local originalNS2GamerulesCheckGameEnd = NS2Gamerules.CheckGameEnd
		NS2Gamerules.CheckGameEnd = function(gameRulesSelf)
			local chairDestroyed = gameRulesSelf:GetTeam(kTeam1Index):GetNumAliveCommandStructures() == 0
			local hiveDestroyed = gameRulesSelf:GetTeam(kTeam2Index):GetNumAliveCommandStructures() == 0
			if chairDestroyed or hiveDestroyed then
				TGNS.DoFor(structures, function(s) s:Kill() end)
				-- explode all the eggs
				local originalGameRulesSelfTeam1GetHasTeamLost = gameRulesSelf.team1.GetHasTeamLost
				local originalGameRulesSelfTeam2GetHasTeamLost = gameRulesSelf.team2.GetHasTeamLost
				gameRulesSelf.team1.GetHasTeamLost = function(team1Self) return chairDestroyed end
				gameRulesSelf.team2.GetHasTeamLost = function(team1Self) return hiveDestroyed end
				originalNS2GamerulesCheckGameEnd(gameRulesSelf)
				gameRulesSelf.team1.GetHasTeamLost = originalGameRulesSelfTeam1GetHasTeamLost
				gameRulesSelf.team2.GetHasTeamLost = originalGameRulesSelfTeam2GetHasTeamLost
			end
		end

		local originalNS2GamerulesGetCanSpawnImmediately = NS2Gamerules.GetCanSpawnImmediately
		NS2Gamerules.GetCanSpawnImmediately = function() return true end

		-- local parent, OldSpawnInfantryPortal = LocateUpValue( MarineTeam.SpawnInitialStructures, "SpawnInfantryPortal", { LocateRecurse = true } )
		-- function SpawnInfantryPortal( marineTeamSelf, techPoint )
		-- end
		-- ReplaceUpValue( parent, "SpawnInfantryPortal", SpawnInfantryPortal, { LocateRecurse = true } )

		local parent, OldCheckForNoIPs = LocateUpValue( MarineTeam.Update, "CheckForNoIPs", { LocateRecurse = true } )
		function CheckForNoIPs( marineTeamSelf, timePassed )
		end
		ReplaceUpValue( parent, "CheckForNoIPs", CheckForNoIPs, { LocateRecurse = true } )

	end

	function Plugin:Initialise()
		self.Enabled = true
		function init()
			if Shared.GetMapName() == "" then
				Shine.Timer.Simple(0, init)
			elseif Shared.GetMapName() == TdMapName then
				if Client then OnClientInitialise() end
				if Server then OnServerInitialise() end
			end
		end
		init()

		return true
	end

	function Plugin:Cleanup()
	    --Cleanup your extra stuff like timers, data etc.
	    self.BaseClass.Cleanup( self )
	end

	Shine:RegisterExtension("td", Plugin )
end