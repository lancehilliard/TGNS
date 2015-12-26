local PLAYER_COUNT_THRESHOLD = 14
local BOT_COUNT_THRESHOLD = 25
local MINIMUM_MARINE_COUNT_FOR_TWO_ALIEN_HUMANS = 6
local originalEndRoundOnTeamUnbalanceSetting = 0.4
local originalForceEvenTeamsOnJoinSetting = true
local originalAutoTeamBalanceSetting = { enabled_after_seconds = 10, enabled_on_unbalance_amount = 2 }
local originalHatchCooldown = kHatchCooldown
local originalAlienSpawnTime = kAlienSpawnTime
local originalkEggGenerationRate = kEggGenerationRate
local originalkMarineRespawnTime = kMarineRespawnTime
local originalkMatureHiveHealth = kMatureHiveHealth
local originalkMatureHiveArmor = kMatureHiveArmor
local originalGetGestateTechId = Egg.GetGestateTechId
local originalOnosGetMaxSpeed = Onos.GetMaxSpeed
local originalOnosChargeSpeed = Onos.kChargeSpeed
local winOrLoseOccurredRecently
local md
local botAdvisory
local alltalk = false
local originalGetCanPlayerHearPlayer
local spawnReprieveAction = function() end
local surrenderBotsIfConditionsAreRight = function() end
local pushSentForThisMap = false
local freeCragEntity
local alienTeamResBonus = 0
local whenLastOnosSpeedAdvisory
local onosSpeedMultiplier = 1
local onosSpeedMultiplierCalculator = function() end
local startingBotsKarmaThrottleInMinutes = 10
local startingBotsKarmaLastGiven = {}
local botsEnabled = false

local Plugin = {}

local function createFreeCragEntity()
	local hives = GetEntitiesForTeam( "Hive", kAlienTeamType )
	local hive = hives[ math.random(#hives) ]
	local pos = GetRandomBuildPosition( kTechId.Crag, hive:GetOrigin(), Crag.kHealRadius - 1 )
	freeCragEntity = CreateEntity("crag", pos, kAlienTeamType)
	freeCragEntity:SetConstructionComplete()
end

function Plugin:GetTotalNumberOfBots()
	local result = #TGNS.Where(TGNS.GetClientList(), TGNS.GetIsClientVirtual)
	return result
end

local function setBotConfig()
	botsEnabled = true
	if not originalEndRoundOnTeamUnbalanceSetting then
		originalEndRoundOnTeamUnbalanceSetting = Server.GetConfigSetting("end_round_on_team_unbalance")
	end
	Server.SetConfigSetting("end_round_on_team_unbalance", 0)
	if not originalForceEvenTeamsOnJoinSetting then
		originalForceEvenTeamsOnJoinSetting = Server.GetConfigSetting("force_even_teams_on_join")
	end
	Server.SetConfigSetting("force_even_teams_on_join", false)
	if not originalAutoTeamBalanceSetting then
		originalAutoTeamBalanceSetting = Server.GetConfigSetting("auto_team_balance")
	end
	Server.SetConfigSetting("auto_team_balance", nil)

	kHatchCooldown = 1
	kAlienSpawnTime = 0.5
	kEggGenerationRate = 0
	kMarineRespawnTime = kMarineRespawnTime / 2
	kMatureHiveHealth = LiveMixin.kMaxHealth
	kMatureHiveArmor = LiveMixin.kMaxArmor

	Egg.GetGestateTechId = function(eggGetGestateTechIdSelf)
		local result = originalGetGestateTechId(eggGetGestateTechIdSelf)
		if result == kTechId.Skulk then
			if math.random() < .005 then
				local random = math.random()
				if random < .25 then
					result = kTechId.Gorge
				elseif random < .5 then
					result = kTechId.Lerk
				elseif random < .75 then
					result = kTechId.Fade
				else
					result = kTechId.Onos
				end
			end
		end
		return result
	end

	Onos.GetMaxSpeed = function(onosGetMaxSpeedSelf, possible)
		local result = originalOnosGetMaxSpeed(onosGetMaxSpeedSelf, possible)
		if onosSpeedMultiplier < 1 then
			result = result * onosSpeedMultiplier
			Onos.kChargeSpeed = Onos.kMaxSpeed
		else
			Onos.kChargeSpeed = originalOnosChargeSpeed
		end
		return result
	end

	onosSpeedMultiplierCalculator = function()
		onosSpeedMultiplier = #TGNS.GetMarineClients(TGNS.GetPlayerList()) / MINIMUM_MARINE_COUNT_FOR_TWO_ALIEN_HUMANS
		if onosSpeedMultiplier < 1 then
			local tweakModifier = 0.9
			onosSpeedMultiplier = onosSpeedMultiplier * tweakModifier
		end
	end

	TGNS.ScheduleAction(2, function()
		alltalk = true
		-- md:ToAllNotifyInfo("All talk enabled during bots play.")
	end)

	spawnReprieveAction = function()
		TGNS.ScheduleAction(5, function()
			if kEggGenerationRate == 0 then
				kEggGenerationRate = originalkEggGenerationRate
				TGNS.ScheduleAction(20, function()
					if Shine.Plugins.bots:GetTotalNumberOfBots() > 0 then
						kEggGenerationRate = 0
					end
				end)
			end
		end)
	end

	surrenderBotsIfConditionsAreRight = function()
		local numberOfNonAfkHumans = #TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.GetIsClientVirtual(c) and not TGNS.IsPlayerAFK(TGNS.GetPlayer(c)) end)
		if Shine.Plugins.bots:GetTotalNumberOfBots() > 0 and numberOfNonAfkHumans >= PLAYER_COUNT_THRESHOLD and TGNS.IsGameInProgress() and not winOrLoseOccurredRecently then
			md:ToAllNotifyInfo(string.format("Server has seeded for NS (%s+ non-AFK players). Bots surrender! Killing bots does not lower the WinOrLose timer.", PLAYER_COUNT_THRESHOLD))
			Shine.Plugins.winorlose:CallWinOrLose(kAlienTeamType)
			winOrLoseOccurredRecently = true
			TGNS.ScheduleAction(65, function() winOrLoseOccurredRecently = false end)
			Shine.Plugins.mapvote.Config.AlwaysExtend = true
			Shine.Plugins.mapvote.Config.AllowExtend = true
			Shine.Plugins.mapvote.CanExtend = function(mapVoteSelf) return true end
			Shine.Plugins.mapvote.Config.ForcedMaps[TGNS.GetCurrentMapName()] = true
			Shine.Plugins.mapvote.ForcedMapCount = 1
		end
	end

end

local function setOriginalConfig()
	botsEnabled = false
	spawnReprieveAction = function() end
	surrenderBotsIfConditionsAreRight = function() end
	if originalEndRoundOnTeamUnbalanceSetting then
		Server.SetConfigSetting("end_round_on_team_unbalance", originalEndRoundOnTeamUnbalanceSetting)
	end
	if originalForceEvenTeamsOnJoinSetting then
		Server.SetConfigSetting("force_even_teams_on_join", originalForceEvenTeamsOnJoinSetting)
	end
	if originalAutoTeamBalanceSetting then
		Server.SetConfigSetting("auto_team_balance", originalAutoTeamBalanceSetting)
	end
	kHatchCooldown = originalHatchCooldown
	kAlienSpawnTime = originalAlienSpawnTime
	kEggGenerationRate = originalkEggGenerationRate
	kMarineRespawnTime = originalkMarineRespawnTime
	kMatureHiveHealth = originalkMatureHiveHealth
	kMatureHiveArmor = originalkMatureHiveArmor
	Egg.GetGestateTechId = originalGetGestateTechId
	Onos.GetMaxSpeed = originalOnosGetMaxSpeed
	Onos.kChargeSpeed = originalOnosChargeSpeed
	onosSpeedMultiplierCalculator = function() end
	onosSpeedMultiplier = 1

	if alltalk then
		alltalk = false
		TGNS.ScheduleAction(TGNS.ENDGAME_TIME_TO_READYROOM, function()
			md:ToAllNotifyInfo("All talk disabled.")
		end)
	end
end

local function removeBots(players, count)
	local botClients = TGNS.GetMatchingClients(players, TGNS.GetIsClientVirtual)
	TGNS.DoFor(botClients, function(c, index)
		if count == nil or index <= count then
			TGNSClientKicker.Kick(c, "Managed bot removal.", nil, nil, false)
		end
	end)
end

local function showBotAdvisory(client)
	if Shine:IsValidClient(client) and TGNS.IsProduction() then
		md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), botAdvisory)
		md:ToClientConsole(client, "------------")
		md:ToClientConsole(client, " TGNS BOTS")
		md:ToClientConsole(client, "------------")
		md:ToClientConsole(client, string.format("Bots are used on TGNS to seed the server to %s non-AFK human players.", PLAYER_COUNT_THRESHOLD))
		md:ToClientConsole(client, string.format("When the server reaches %s non-AFK human players, the aliens surrender and humans-only NS2 play begins.", PLAYER_COUNT_THRESHOLD))
		md:ToClientConsole(client, "During TGNS bots play: marines spawn more quickly than in normal NS2 play")
		md:ToClientConsole(client, "During TGNS bots play: marines receive personal resources more quickly than in normal NS2 play")
		md:ToClientConsole(client, "During TGNS bots play: marines receive catpacks when killing bots")
		md:ToClientConsole(client, "During TGNS bots play: marines receive a clip of ammo when killing bots")
		md:ToClientConsole(client, "During TGNS bots play: alien hives have more health")
		md:ToClientConsole(client, "During TGNS bots play: aliens get one free persistent crag")
		md:ToClientConsole(client, "During TGNS bots play: alltalk is enabled")
		md:ToClientConsole(client, "Many thanks to TAW|Leech for contributing to our skulk bot brain code!")
	end
end

function Plugin:ClientConfirmConnect(client)
	if self:GetTotalNumberOfBots() > 0 and not TGNS.GetIsClientVirtual(client) then
		showBotAdvisory(client)
		TGNS.ScheduleAction(5, function() showBotAdvisory(client) end)
		TGNS.ScheduleAction(12, function() showBotAdvisory(client) end)
		TGNS.ScheduleAction(20, function() showBotAdvisory(client) end)
		TGNS.ScheduleAction(40, function() showBotAdvisory(client) end)
	end
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
	if not (force or shineForce) then
		if self:GetTotalNumberOfBots() > 0 and TGNS.IsGameplayTeamNumber(newTeamNumber) and not TGNS.GetIsClientVirtual(client) then
			local alienHumanClients = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return TGNS.GetPlayerTeamNumber(p) == kAlienTeamType and not TGNS.GetIsClientVirtual(c) end)
			local marineHumanClients = TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return TGNS.GetPlayerTeamNumber(p) == kMarineTeamType and not TGNS.GetIsClientVirtual(c) end)
			local numberOfAllowedAlienPlayers = 1
			local errorMessage = string.format("Marines must have %s human players before the bot Aliens may have a second human player.", MINIMUM_MARINE_COUNT_FOR_TWO_ALIEN_HUMANS)
			if #marineHumanClients >= MINIMUM_MARINE_COUNT_FOR_TWO_ALIEN_HUMANS then
				numberOfAllowedAlienPlayers = 2
				errorMessage = "A maximum of two human players are allowed on the bot team."
			end
			if #alienHumanClients >= numberOfAllowedAlienPlayers and newTeamNumber ~= kMarineTeamType then
			--if newTeamNumber ~= kMarineTeamType then
				md:ToPlayerNotifyError(player, errorMessage)
				return false
			end
		end
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.ScheduleAction(2, function()
		removeBots(TGNS.GetPlayerList())
	end)
	setOriginalConfig()
end

function Plugin:CreateCommands()
	local botsCommand = self:BindCommand( "sh_bots", "bots", function(client, countModifier)
		local steamId = TGNS.GetClientSteamId(client)
		countModifier = tonumber(countModifier)
		local errorMessage
		local players = TGNS.GetPlayerList()
		if countModifier then
			if self:GetTotalNumberOfBots() == 0 then
				local atLeastOnePlayerIsOnGameplayTeam = #TGNS.GetAlienClients(players) + #TGNS.GetMarineClients(players) > 0
				if #players >= PLAYER_COUNT_THRESHOLD then
					errorMessage = string.format("Bots are used only for seeding the server to %s players.", PLAYER_COUNT_THRESHOLD)
				elseif atLeastOnePlayerIsOnGameplayTeam then
					errorMessage = "All players must be in the ReadyRoom before adding initial bots."
				elseif Shine.Plugins.mapvote:VoteStarted() then
					errorMessage = "Bots cannot be managed during a map vote."
				elseif Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled() then
					errorMessage = "Bots cannot be managed during a Captains Game."
				end
			end
		else
			errorMessage = "Specify a positive or negative bot count modifier."
		end
		if TGNS.HasNonEmptyValue(errorMessage) then
			md:ToPlayerNotifyError(TGNS.GetPlayer(client), errorMessage)
		else
			local proposedTotalCount = self:GetTotalNumberOfBots() + countModifier
			countModifier = proposedTotalCount <= BOT_COUNT_THRESHOLD and countModifier or (countModifier - (proposedTotalCount - BOT_COUNT_THRESHOLD))
			if countModifier > 0 then
				setBotConfig()
				if not TGNS.IsGameInProgress() then
					local humanNonSpectatorsNotInSidebar = TGNS.Where(players, function(p)
						local client = TGNS.GetClient(p)
						return not TGNS.GetIsClientVirtual(client) and not TGNS.IsPlayerSpectator(p) and not (Shine.Plugins.sidebar and Shine.Plugins.sidebar.PlayerIsInSidebar and Shine.Plugins.sidebar:PlayerIsInSidebar(p))
					end)
					TGNS.DoFor(humanNonSpectatorsNotInSidebar, function(p)
						local c = TGNS.GetClient(p)
						TGNS.SendToTeam(p, kMarineTeamType, true)
						TGNS.ScheduleAction(2, function() showBotAdvisory(c) end)
						TGNS.ScheduleAction(8, function() showBotAdvisory(c) end)
						TGNS.ScheduleAction(16, function() showBotAdvisory(c) end)
					end)
					Shine.Plugins.forceroundstart:ForceRoundStart()
					if not pushSentForThisMap and TGNS.IsProduction() then
						Shine.Plugins.push:Push("tgns-bots", "TGNS bots round started!", string.format("%s on %s\\n\\nServer Info: http://rr.tacticalgamer.com/ServerInfo", TGNS.GetCurrentMapName(), TGNS.GetSimpleServerName()))
						pushSentForThisMap = true

						if startingBotsKarmaLastGiven[steamId] == nil or (Shared.GetTime() - startingBotsKarmaLastGiven[steamId] >= TGNS.ConvertMinutesToSeconds(startingBotsKarmaThrottleInMinutes)) then
							TGNS.Karma(steamId, "StartingBots")
							startingBotsKarmaLastGiven[steamId] = Shared.GetTime()
						end
					end
				end
				local command = string.format("addbot %s %s", countModifier, kAlienTeamType)
				TGNS.ScheduleAction(TGNS.IsGameInProgress() and 0 or 2, function()
					TGNS.ExecuteServerCommand(command)
				end)
			else
				local numberOfBotsToRemove = math.abs(countModifier)
				numberOfBotsToRemove = numberOfBotsToRemove < self:GetTotalNumberOfBots() and numberOfBotsToRemove or self:GetTotalNumberOfBots() - 1
				removeBots(players, numberOfBotsToRemove)
			end
		end
	end)
	botsCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	botsCommand:Help( "<countModifier> +/- the count of alien bots." )

	local botsMaxCommand = self:BindCommand( "sh_botsmax", "botsmax", function(client, maxCandidate)
		local player = TGNS.GetPlayer(client)
		local max = tonumber(maxCandidate)
		if max <= 0 then
			md:ToPlayerNotifyError(player, "Bots maximum must be a positive number.")
		else
			BOT_COUNT_THRESHOLD = max
			local excessBotCount = self:GetTotalNumberOfBots() - BOT_COUNT_THRESHOLD
			if excessBotCount > 0 then
				removeBots(TGNS.GetPlayerList(), excessBotCount)
			end
			md:ToPlayerNotifyInfo(player, string.format("Maximum possible bots set to %s.", max))
		end
	end)
	botsMaxCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	botsMaxCommand:Help( "<max> Set the maximum possible count of bots." )

	local humansMaxCommand = self:BindCommand( "sh_botsplayerthreshold", nil, function(client, maxCandidate)
		local player = TGNS.GetPlayer(client)
		local max = tonumber(maxCandidate)
		if max <= 0 then
			md:ToPlayerNotifyError(player, "Bots player threshold must be a positive number.")
		else
			PLAYER_COUNT_THRESHOLD = max
			md:ToPlayerNotifyInfo(player, string.format("Bots player threshold set to %s.", max))
			botAdvisory = string.format("Alltalk enabled during bots. Server switches to NS upon %s non-AFK players. Console for details.", PLAYER_COUNT_THRESHOLD)
		end
	end)
	humansMaxCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	humansMaxCommand:Help( "<threshold> Set the player threshold count for bots." )
end

function Plugin:OnEntityKilled(gamerules, victimEntity, attackerEntity, inflictorEntity, point, direction)
	if victimEntity and victimEntity:isa("Player") and TGNS.GetIsClientVirtual(TGNS.GetClient(victimEntity)) and attackerEntity and attackerEntity:isa("Player") then
		local humanPlayersWithFewerThan100Resources = TGNS.Where(TGNS.GetPlayers(TGNS.GetPlayingClients(TGNS.GetPlayerList())), function(p) return TGNS.GetPlayerResources(p) < 100 and not TGNS.ClientAction(p, TGNS.GetIsClientVirtual) end)
		TGNS.DoFor(humanPlayersWithFewerThan100Resources, function(p)
			TGNS.AddPlayerResources(p, 2 / #humanPlayersWithFewerThan100Resources)
		end)
		alienTeamResBonus = alienTeamResBonus + 0.25
		if alienTeamResBonus >= 1 then
			GetGamerules():GetTeam(kAlienTeamType):AddTeamResources(1)
			alienTeamResBonus = alienTeamResBonus - 1
		end
		if inflictorEntity:GetParent() == attackerEntity or (inflictorEntity.GetClassName and inflictorEntity:GetClassName() == "Grenade") then
			if attackerEntity.ApplyCatPack then
				StartSoundEffectAtOrigin(CatPack.kPickupSound, attackerEntity:GetOrigin())
	    		attackerEntity:ApplyCatPack()
			end

    		local weapons = attackerEntity:GetWeapons()
    		TGNS.DoFor(weapons, function(w)
			    if w.GiveAmmo then
				    w:GiveAmmo(1)
			    end
    		end)
	    end
	end
	if freeCragEntity ~= nil and victimEntity == freeCragEntity then
		createFreeCragEntity()
	end
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("BOTS")
	TGNS.ScheduleAction(10, setOriginalConfig)
	self:CreateCommands()
	botAdvisory = string.format("Alltalk enabled during bots. Server switches to NS upon %s non-AFK players. Console for details.", PLAYER_COUNT_THRESHOLD)

	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		if alltalk and not (Shine.Plugins.sidebar and Shine.Plugins.sidebar.IsEitherPlayerInSidebar and Shine.Plugins.sidebar:IsEitherPlayerInSidebar(listenerPlayer, speakerPlayer)) then
			result = true
		end
		return result
	end)

	TGNS.ScheduleActionInterval(120, function() 
		if botsEnabled then
			spawnReprieveAction()
		end
	end)
	TGNS.ScheduleActionInterval(10, function() 
		if botsEnabled then
			surrenderBotsIfConditionsAreRight()
		end
	end)
	TGNS.ScheduleActionInterval(3, function()
		if botsEnabled then
			onosSpeedMultiplierCalculator()
			if onosSpeedMultiplier < 1 and (whenLastOnosSpeedAdvisory == nil or (Shared.GetTime() - whenLastOnosSpeedAdvisory) > 2) then
				local message = string.format("Onos movement speed is\nreduced in bot games having\nfewer than %s Marines.\n\nModifier: %s", MINIMUM_MARINE_COUNT_FOR_TWO_ALIEN_HUMANS, TGNS.RoundPositiveNumberDown(onosSpeedMultiplier, 2))
				local onosPlayers = TGNS.Where(TGNS.GetPlayerList(), function(p) return p:isa("Onos") end)
				TGNS.DoFor(onosPlayers, function(p)
					Shine.ScreenText.Add(36, {X = 0.75, Y = 0.65, Text = message, Duration = 5, R = 0, G = 255, B = 0, Alignment = TGNS.ShineTextAlignmentMin, Size = 2, FadeIn = 0, IgnoreFormat = true}, TGNS.GetClient(p))
				end)				
				whenLastOnosSpeedAdvisory = Shared.GetTime()
			end
		end
	end)

	TGNS.RegisterEventHook("GameStarted", function()
		if self:GetTotalNumberOfBots() > 0 then
			if TGNS.GetCurrentMapName() ~= "ns2_tgns_arclight" then
				createFreeCragEntity()
			end
			GetGamerules():GetTeam(kAlienTeamType):AddTeamResources(100)
			alienTeamResBonus = 0
		end
		if TGNS.GetCurrentMapName() == "dev_test" then
			TGNS.ScheduleAction(60, function()
				local hives = GetEntitiesForTeam( "Hive", kAlienTeamType )
				local hive = hives[ math.random(#hives) ]
				local chairs = GetEntitiesForTeam( "CommandStation", kMarineTeamType )
				local chair = chairs[ math.random(#chairs) ]
				local pos = GetRandomBuildPosition( kTechId.Crag, hive:GetOrigin(), Crag.kHealRadius - 1 )

				local numberOfStructures = 25
				TGNS.DoTimes(numberOfStructures, function(i)
					local structureNames = { Crag.kMapName, Shift.kMapName, Drifter.kMapName, Whip.kMapName, Shade.kMapName }
					local structureName = TGNS.GetFirst(TGNS.GetRandomizedElements(structureNames))
					local testEntity = CreateEntity(structureName, pos, kAlienTeamType)

					if testEntity.SetConstructionComplete then
						testEntity:SetConstructionComplete()
					end

					local modifier = 3 * (i/numberOfStructures)

					local originalGetMaxSpeed = testEntity.GetMaxSpeed
					testEntity.GetMaxSpeed = function(testEntitySelf)
						local result = originalGetMaxSpeed(testEntitySelf)
						return result * modifier
					end

					local originalDrifterkMoveSpeed = Drifter.kMoveSpeed
					local originalDrifterOnUpdate = Drifter.OnUpdate
					testEntity.kDrifterMoveSpeed = originalDrifterkMoveSpeed * modifier
					Drifter.OnUpdate = function(drifterSelf, deltaTime)
						Drifter.kMoveSpeed = drifterSelf.kDrifterMoveSpeed
						originalDrifterOnUpdate(drifterSelf, deltaTime)
						Drifter.kMoveSpeed = originalDrifterkMoveSpeed
					end

					if testEntity.matureMaxHealth then
						testEntity:SetMaxHealth(testEntity:GetMaxHealth() * modifier)
						testEntity.matureMaxHealth = testEntity.matureMaxHealth * modifier
						testEntity:SetHealth(testEntity:GetMatureMaxHealth())
						testEntity:SetMaxArmor(testEntity:GetMaxArmor() * modifier)
						testEntity.matureMaxArmor = testEntity.matureMaxArmor * modifier
						testEntity:SetMature()
						testEntity:SetArmor(testEntity:GetMatureMaxArmor())
					end

					if testEntity.SetOnFire and math.random() < .5 then
						testEntity:SetOnFire(nil, nil)
					end

					testEntity:GiveOrder(kTechId.Move, nil, chair:GetOrigin(), nil, true, true)
					TGNS.ScheduleAction(45, function()
						testEntity:GiveOrder(kTechId.Move, nil, chair:GetOrigin(), nil, true, true)
					end)
					TGNS.ScheduleAction(90, function()
						testEntity:GiveOrder(kTechId.Move, nil, chair:GetOrigin(), nil, true, true)
					end)
				end)
			end)
		end
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("bots", Plugin )

					-- if p:GetTeamNumber() == kTeam2Index then
					-- 	p.client.variantData.gorgeVariant = kGorgeVariant.shadow
					-- 	p.client.variantData.lerkVariant = kLerkVariant.shadow
					-- 	p:Replace("fade", p:GetTeamNumber())
					-- end
