Plugin.HasConfig = false
-- Plugin.ConfigName = "infestedhelper.json"

local md = TGNSMessageDisplayer.Create()
local deadMd = TGNSMessageDisplayer.Create("DEAD")
local infestedMd = TGNSMessageDisplayer.Create("INFESTED")
local INFESTED_CHAT_CHARACTERS = "inf "
local initialInfestedSteamIds
local PLAYER_COUNT_THRESHOLD = 12
local GAME_COUNT_THRESHOLD = 4
--local INFESTATION_INFESTED_BENEFIT_PERCENTAGE = 33
local gameCount = 0
local infectedCounts = {}
local cystKills

function Plugin:ClientConfirmConnect(client)
end

local function clientIsInfected(client)
	local player = TGNS.GetPlayer(client)
	return player.GetIsInfected and player:GetIsInfected()
end

local function clientIsMarine(client)
	return TGNS.ClientIsMarine(client) and TGNS.IsClientAlive(client) and not clientIsInfected(client)
end

local function clientIsDead(client)
	return TGNS.ClientIsMarine(client) and not TGNS.IsClientAlive(client)
end

local function clientIsInfested(client)
	return TGNS.ClientIsMarine(client) and TGNS.IsClientAlive(client) and clientIsInfected(client)
end

function Plugin:OnEntityKilled(gamerules, victim, attacker, inflictor, point, dir)
	if cystKills then
		if attacker and victim then
			local attackerClient = TGNS.GetClient(attacker)
			if attackerClient and victim:isa("Cyst") then
				cystKills[attackerClient] = (cystKills[attackerClient] or 0) + 1
			end
		end
	end
end

function Plugin:Initialise()
    self.Enabled = true

	TGNS.DoWithConfig(function()

	    if Shine.GetGamemode() == "Infested" then

	    	if self:IsSaturdayNightFever() then
	    		Shine.Plugins.mapvote.Config.RoundLimit = 5
	    	end
	    	IMGameMaster.kAirQualityChangePerSecondMax = IMGameMaster.kAirQualityChangePerSecondMax * 0.8
	    	kWelderPowerRepairRate = kWelderPowerRepairRate * 2

	    	if not TGNS.IsProduction() then
	    		TGNS.ScheduleAction(5, function()
		    		IMGameMaster.kTimeBeforeInfectedChosen = 1
	    		end)
	    	end

			Shine.Hook.Add("PlayerSay", "InfestedPlayerSay", function(client, networkMessage)
				-- local teamOnly = networkMessage.teamOnly
				if TGNS.StartsWith(TGNS.ToLower(networkMessage.message), TGNS.ToLower(INFESTED_CHAT_CHARACTERS)) or StringTrim(TGNS.ToLower(networkMessage.message)) == StringTrim(TGNS.ToLower(INFESTED_CHAT_CHARACTERS)) then
					if clientIsInfested(client) then
						if TGNS.ToLower(networkMessage.message) ~= TGNS.ToLower(INFESTED_CHAT_CHARACTERS) then
							networkMessage.message = TGNS.Substring(networkMessage.message, string.len(INFESTED_CHAT_CHARACTERS) + 1)
							TGNS.DoFor(TGNS.GetPlayers(TGNS.Where(TGNS.GetClientList(), function(c) return clientIsInfested(c) or TGNS.IsClientSpectator(c) or TGNS.IsClientReadyRoom(c) end)), function(p)
								local player = TGNS.GetPlayer(client)
								local playerLocationName = TGNS.GetPlayerLocationName(player)
								infestedMd:ToPlayerNotifyColors(p, string.format("%s%s: %s", TGNS.GetClientName(client), TGNS.HasNonEmptyValue(playerLocationName) and string.format(" (%s)", playerLocationName) or "", StringTrim(networkMessage.message)), 229.755, 158.865, 54.825, 255, 255, 255)
							end)
						end
						return ""
					else
						md:ToPlayerNotifyError(TGNS.GetPlayer(client), "Only infested may chat privately using 'inf '.")
						return ""
					end
				else
					if clientIsDead(client) and TGNS.IsGameInProgress() then
						TGNS.DoFor(TGNS.GetPlayers(TGNS.Where(TGNS.GetClientList(), function(c) return clientIsDead(c) or TGNS.IsClientSpectator(c) or TGNS.IsClientReadyRoom(c) end)), function(p)
							deadMd:ToPlayerNotifyColors(p, string.format("%s: %s", TGNS.GetClientName(client), StringTrim(networkMessage.message)), 255, 0, 0, 255, 255, 255)
						end)
						return ""
					end
				end
			end, TGNS.LOWEST_EVENT_HANDLER_PRIORITY)


			TGNS.ScheduleActionInterval(45, function()
				TGNS.DoFor(TGNS.Where(TGNS.GetClientList(), clientIsInfested), function(c)
					md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), "Start any chat with 'inf ' (with a space) to privately chat with other infested (ex: 'inf let's go!').")
				end)
			end)

			TGNS.ScheduleActionInterval(600, function()
				TGNS.DoFor(TGNS.Where(TGNS.GetClientList(), clientIsInfested), function(c)
					md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), "M > Notifications > Infested -- get notified when Infested is being played on the server!")
				end)
			end)

			Script.Load("lua/tgns/Elixer_Utility.lua")
			Elixer.UseVersion(TGNSElixerVersion) 

			local clientsWhoWouldLikeToBeInfested = {}

			TGNS.ScheduleAction(1, function()
				local parent, OldPickInfected = LocateUpValue( IMGameMaster.OnUpdate, "PickInfected", { LocateRecurse = true } )
				local function PickInfected( infestedSelf )
					local originalGetGamerules = GetGamerules
					local randomNumbers = {}
					TGNS.DoFor(TGNS.GetClientList(), function(c)
						randomNumbers[c] = math.random()
					end)
					local originalMathRandom = math.random
					local originalGetPlayers
					local shouldInfluenceRandomPlayerSelection = math.random() >= 0.50
					if shouldInfluenceRandomPlayerSelection then
						GetGamerules = function()
							local gamerulesResult = originalGetGamerules()
							if originalGetPlayers == nil then
								originalGetPlayers = gamerulesResult.team1.GetPlayers
							end
							if gamerulesResult and gamerulesResult.team1 then
								gamerulesResult.team1.GetPlayers = function(teamSelf)
									local playersResult = originalGetPlayers(teamSelf)

									TGNS.SortAscending(playersResult, function(p)
										local c = TGNS.GetClient(p)
										local playerWantsToBeInfested = TGNS.Has(clientsWhoWouldLikeToBeInfested, c)
										return playerWantsToBeInfested and (randomNumbers[c] or 0) or 10+(randomNumbers[c] or 0)
									end)
									return playersResult
								end
							end
							return gamerulesResult
						end
						local randomResult = 0
						local getRandomResult = function(max)
							randomResult = randomResult + 1
							return randomResult <= max and randomResult or max
						end
						math.random = function(lower, upper)
							local mathRandomResult = lower ~= nil and (upper ~= nil and originalMathRandom(lower, upper) or getRandomResult(lower)) or originalMathRandom()
							return mathRandomResult
						end
					end
					OldPickInfected(infestedSelf)
					GetGamerules = originalGetGamerules
					math.random = originalMathRandom
					clientsWhoWouldLikeToBeInfested = {}
					initialInfestedSteamIds = {}
					TGNS.DoForPairs(infestedSelf.initialInfected, function(steamId, isInitialInfested)
						table.insert(initialInfestedSteamIds, steamId)
					end)
				end
				ReplaceUpValue( parent, "PickInfected", PickInfected, { LocateRecurse = true } )

				local oldAttemptInfectionParent, originalAttemptInfection = LocateUpValue( Marine.SecondaryAttack, "AttemptInfection", { LocateRecurse = true } )
				local function AttemptInfection(marineSelf)
					local crosshairTargetForInfection
					local originalGetCrosshairTargetForInfection = marineSelf.GetCrosshairTargetForInfection
					marineSelf.GetCrosshairTargetForInfection = function(crosshairMarineSelf)
						crosshairTargetForInfection = originalGetCrosshairTargetForInfection(crosshairMarineSelf)
						if crosshairTargetForInfection then
							local originalInfect = crosshairTargetForInfection.Infect
							crosshairTargetForInfection.Infect = function(targetSelf)
								local marineClient = TGNS.GetClient(marineSelf)
								infectedCounts[marineClient] = (infectedCounts[marineClient] or 0) + 1
								Shared.Message("infectedCounts[marineClient]: " .. tostring(infectedCounts[marineClient]))
								originalInfect(targetSelf)
							end
						end
						return crosshairTargetForInfection
					end
					originalAttemptInfection(marineSelf)
					marineSelf.GetCrosshairTargetForInfection = originalGetCrosshairTargetForInfection
				end
				ReplaceUpValue(oldAttemptInfectionParent, "AttemptInfection", AttemptInfection, { LocateRecurse = true } )

				-- local originalMarineDeductInfestedEnergy = Marine.DeductInfestedEnergy
				-- Marine.DeductInfestedEnergy = function(marineSelf, amount)
				-- 	local modifier = GetIsPointOnInfestation(marineSelf:GetOrigin()) and (1-(INFESTATION_INFESTED_BENEFIT_PERCENTAGE/100)) or 1
				-- 	amount = amount * modifier
				-- 	originalMarineDeductInfestedEnergy(marineSelf, amount)
				-- end

				local originalNs2GamerulesGetPregameLength = NS2Gamerules.GetPregameLength
				NS2Gamerules.GetPregameLength = function(gamerulesSelf)
					local result = originalNs2GamerulesGetPregameLength(gamerulesSelf)
					if result < 2 then
						result = 2 -- give TRH time to finish recordings
					end
					return result
				end

				Event.Hook("Console_kill", function(client)
					if clientIsMarine(client) and #TGNS.Where(TGNS.GetClientList(), clientIsMarine) == 1 and #TGNS.Where(TGNS.GetClientList(), clientIsInfested) > 0 and TGNS.IsGameInProgress() and not TGNS.IsClientAFK(client) then
						md:ToAllNotifyInfo(string.format("%s tried to solve it...", TGNS.GetClientName(client)))
					else
						OnCommandKill(client)
					end
				end)

			end)

			Shine.Hook.Add("JoinTeam", "InfestJoinTeam", function(pluginSelf, player, newTeamNumber, force, shineForce)
				local client = TGNS.GetClient(player)
				if TGNS.ClientIsMarine(client) and clientIsMarine(client) and #TGNS.Where(TGNS.GetClientList(), clientIsMarine) == 1 and #TGNS.Where(TGNS.GetClientList(), clientIsInfested) > 0 and TGNS.IsGameInProgress() and not TGNS.IsClientAFK(client) then
					md:ToAllNotifyInfo(string.format("%s tried to run...", TGNS.GetClientName(client)))
					return false
				end
			end)

			Shine.Hook.Add("EndGame", "InfestEndGame", function(pluginSelf, gamerules, winningTeam)
				TGNS.ScheduleAction(1.5, function()
					local message = ""
					local initialInfestedClients = TGNS.Where(TGNS.Select(initialInfestedSteamIds, TGNS.GetClientByNs2Id), function(c) return c ~= nil end)
					if #initialInfestedClients > 0 then
						local initialInfestedClientNames = TGNS.Select(initialInfestedClients, TGNS.GetClientName)
						TGNS.SortAscending(initialInfestedClientNames)
						message = string.format("%sInitial Infested Last Round%s: %s", #initialInfestedClientNames > 1 and string.format("%s ", #initialInfestedClientNames) or "", #initialInfestedClientNames > 1 and "" or "", TGNS.Join(initialInfestedClientNames, ", "))
					end
					local mostInfectedPlayerName
					local mostInfectedCount = 0
					TGNS.DoForPairs(infectedCounts, function(client, infectedCount)
						if Shine:IsValidClient(client) and infectedCount > mostInfectedCount then
							mostInfectedPlayerName = TGNS.GetClientName(client)
							mostInfectedCount = infectedCount
						end
					end)
					infectedCounts = {}
					if mostInfectedCount > 0 then
						message = string.format("%s. Most infections last round: %s (%s)", message, mostInfectedPlayerName, mostInfectedCount)
					end

					local mostCystsKilledPlayerName
					local mostCystsKilledCount = 0
					TGNS.DoForPairs(cystKills, function(client, cystKillCount)
						if Shine:IsValidClient(client) and cystKillCount > mostCystsKilledCount then
							mostCystsKilledPlayerName = TGNS.GetClientName(client)
							mostCystsKilledCount = cystKillCount
						end
					end)
					if mostCystsKilledCount > 0 then
						message = string.format("%s. Most cysts killed last round: %s (%s)", message, mostCystsKilledPlayerName, mostCystsKilledCount)
					end

					if TGNS.HasNonEmptyValue(message) then
						md:ToAllNotifyInfo(message)
					end

					-- local survivingClients = TGNS.Where(TGNS.GetMarineClients(TGNS.GetPlayerList()), TGNS.IsClientAlive)
					-- TGNS.SortDescending(survivingClients, function(c) return TGNS.GetPlayerScore(TGNS.GetPlayer(c)) end)
					-- local survivingMarineClients = TGNS.Where(survivingClients, clientIsMarine)
					-- local survivingInfestedClients = TGNS.Where(survivingClients, clientIsInfested)
					-- local survivingWinnerClientNames = TGNS.Select(#survivingMarineClients > 0 and survivingMarineClients or survivingInfestedClients, TGNS.GetClientName)
					-- md:ToAllNotifyInfo(string.format("%s%s: %s", #survivingWinnerClientNames > 1 and Pluralize(#survivingWinnerClientNames, "Survivor") or "Lone Survivor", #survivingWinnerClientNames > 1 and "" or "", TGNS.Join(survivingWinnerClientNames, ", ")))
				end)
			end)

			TGNS.DoFor({"sh_infestme", "sh_infectme"}, function(c)
				local command = self:BindCommand(c, nil, function(client)
					local player = TGNS.GetPlayer(client)
					if TGNS.IsClientSM(client) then
						if clientIsDead(client) or not TGNS.IsGameInProgress() then
							TGNS.InsertDistinctly(clientsWhoWouldLikeToBeInfested, client)
							md:ToPlayerNotifyInfo(player, "Preference privately noted for next round only. No guarantees.")
						else
							md:ToPlayerNotifyError(player, "You must be dead to use this command during gameplay.")
						end
					else
						md:ToPlayerNotifyError(player, "Only Supporting Members may use this command.")
					end
				end, true)
				command:Help( "Tell the server you prefer be Infested. No guarantees." )
			end)
			TGNS.ScheduleActionInterval(180, function()
				TGNS.DoFor(TGNS.Where(TGNS.GetClientList(), clientIsDead), function(c)
					md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), "SMs: sh_infestme (in console) while dead to REQUEST to start Infested next round. No guarantees.")
				end)
			end)
			-- TGNS.ScheduleActionInterval(60, function()
			-- 	md:ToAllNotifyInfo(string.format("Standing on infestation slows hunger %s%%. Discuss this mod in our TGNS forums.", INFESTATION_INFESTED_BENEFIT_PERCENTAGE))
			-- end)

			TGNS.RegisterEventHook("GameStarted", function()
				cystKills = {}
				TGNS.ScheduleAction(5, function()
					gameCount = gameCount + 1
					if gameCount >= GAME_COUNT_THRESHOLD and not self:IsSaturdayNightFever() then
						local numberOfNonAfkHumans = #TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.GetIsClientVirtual(c) and not TGNS.IsPlayerAFK(TGNS.GetPlayer(c)) end)
						if numberOfNonAfkHumans >= PLAYER_COUNT_THRESHOLD then
							md:ToAllNotifyInfo(string.format("Server has seeded for NS (%s+ non-AFK players w/ %s+ rounds of Infested played).", PLAYER_COUNT_THRESHOLD, GAME_COUNT_THRESHOLD))
							Shine.Plugins.mapvote:StartVote(true)
							TGNS.ForcePlayersToReadyRoom(TGNS.GetMarinePlayers(TGNS.GetPlayerList()))
						end
					end
				end)
			end)

	    end

	end)


    -- self:CreateCommands()
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end