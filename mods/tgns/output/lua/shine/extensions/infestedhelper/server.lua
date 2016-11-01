Plugin.HasConfig = false
-- Plugin.ConfigName = "infestedhelper.json"

local md = TGNSMessageDisplayer.Create()
local deadMd = TGNSMessageDisplayer.Create("DEAD")
local infestedMd = TGNSMessageDisplayer.Create("INFESTED")
local INFESTED_CHAT_CHARACTERS = "inf "
local initialInfestedSteamIds

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

function Plugin:Initialise()
    self.Enabled = true

    if Shine.GetGamemode() == "Infested" then

    	-- if not TGNS.IsProduction() then
    	-- 	TGNS.ScheduleAction(5, function()
	    -- 		IMGameMaster.kTimeBeforeInfectedChosen = 1
    	-- 	end)
    	-- end

		Shine.Hook.Add("PlayerSay", "InfestedPlayerSay", function(client, networkMessage)
			-- local teamOnly = networkMessage.teamOnly
			if TGNS.StartsWith(networkMessage.message, INFESTED_CHAT_CHARACTERS) or StringTrim(networkMessage.message) == StringTrim(INFESTED_CHAT_CHARACTERS) then
				if clientIsInfested(client) then
					if networkMessage.message ~= INFESTED_CHAT_CHARACTERS then
						networkMessage.message = TGNS.Substring(networkMessage.message, string.len(INFESTED_CHAT_CHARACTERS) + 1)
						TGNS.DoFor(TGNS.GetPlayers(TGNS.Where(TGNS.GetClientList(), function(c) return clientIsInfested(c) or TGNS.IsClientSpectator(c) or TGNS.IsClientReadyRoom(c) end)), function(p)
							infestedMd:ToPlayerNotifyColors(p, string.format("%s: %s", TGNS.GetClientName(client), StringTrim(networkMessage.message)), 229.755, 158.865, 54.825, 255, 255, 255)
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
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(c), "Start any chat with 'inf ' to privately chat with other infested (ex: 'inf let's go!').")
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
					math.random = function(lower, upper)
						local mathRandomResult = lower ~= nil and (upper ~= nil and originalMathRandom(lower, upper) or 1) or originalMathRandom()
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
		end)

		Shine.Hook.Add("EndGame", "InfestEndGame", function(pluginSelf, gamerules, winningTeam)
			TGNS.ScheduleAction(1.5, function()
				local initialInfestedClients = TGNS.Where(TGNS.Select(initialInfestedSteamIds, TGNS.GetClientByNs2Id), function(c) return c ~= nil end)
				if #initialInfestedClients > 0 then
					local initialInfestedClientNames = TGNS.Select(initialInfestedClients, TGNS.GetClientName)
					TGNS.SortAscending(initialInfestedClientNames)
					md:ToAllNotifyInfo(string.format("%s Initial Infested Last Round%s: %s", #initialInfestedClientNames, #initialInfestedClientNames > 1 and "" or "", TGNS.Join(initialInfestedClientNames, ", ")))
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
					if clientIsDead(client) then
						TGNS.InsertDistinctly(clientsWhoWouldLikeToBeInfested, client)
						md:ToPlayerNotifyInfo(player, "Preference privately noted for next round only. No guarantees.")
					else
						md:ToPlayerNotifyError(player, "You must be dead to use this command.")
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

    end

    -- self:CreateCommands()
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end