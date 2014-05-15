local kWinOrLoseVoteArray = { }
local kWinOrLoseTeamCount = 2
local kTimeAtWhichWinOrLoseVoteSucceeded = 0
local kTeamWhichWillWinIfWinLoseCountdownExpires = nil
local kCountdownTimeRemaining = 0
local ENTITY_CLASSNAMES_TO_DESTROY_ON_LOSING_TEAM = { "Sentry", "Mine", "Armory", "Whip", "Clog", "Hydra", "Crag", "ARC" }
local VOTE_HOWTO_TEXT = "Press 'M > Surrender' to vote."
local md
local lastVoteStartTimes = {}
local numberOfSecondsToDeductFromCountdownTimeRemaining
local mayVoteAt = 0
local lastNoAttackNoticeTimes = {}
local lastBannerDisplayCountdownRemaining

local originalGetCanAttack

local function removeBanners()
	Shine:RemoveText(nil, { ID = 70 } )
	Shine:RemoveText(nil, { ID = 71 } )
	Shine:RemoveText(nil, { ID = 72 } )
	Shine:RemoveText(nil, { ID = 73 } )
	Shine:RemoveText(nil, { ID = 74 } )
end

local function SetupWinOrLoseVars()
	for i = 1, kWinOrLoseTeamCount do
		local WinOrLoseVoteTeamArray = {WinOrLoseRunning = 0, WinOrLoseVotes = { }, WinOrLoseVotesAlertTime = 0}
		table.insert(kWinOrLoseVoteArray, WinOrLoseVoteTeamArray)
	end
end

local function GetCommandStructureToKeep(commandStructures)
	local builtAndAliveCommandStructures = TGNS.Where(commandStructures, TGNS.CommandStructureIsBuiltAndAlive)
	TGNS.SortDescending(builtAndAliveCommandStructures, TGNS.GetNumberOfWorkingInfantryPortals)
	local commandStructuresWithCommanders = TGNS.Where(builtAndAliveCommandStructures, TGNS.CommandStructureHasCommander)
	local builtAndAliveCommandStationsWithWorkingInfantryPortal = TGNS.Where(builtAndAliveCommandStructures, function(s) return TGNS.GetNumberOfWorkingInfantryPortals(s) > 0 end)
	local firstCommandStructureWithCommander = #commandStructuresWithCommanders > 0 and TGNS.GetFirst(commandStructuresWithCommanders) or nil
	local firstCommandStationWithWorkingInfantryPortal = #builtAndAliveCommandStationsWithWorkingInfantryPortal > 0 and TGNS.GetFirst(builtAndAliveCommandStationsWithWorkingInfantryPortal) or nil
	local firstBuiltAndAliveCommandStructure = #builtAndAliveCommandStructures > 0 and TGNS.GetFirst(builtAndAliveCommandStructures) or nil
	local result = firstCommandStructureWithCommander or firstCommandStationWithWorkingInfantryPortal or firstBuiltAndAliveCommandStructure or TGNS.GetFirst(commandStructures)
	return result
end

local function getNumberOfRequiredVotes(votersCount)
	local result = math.floor((votersCount * (Shine.Plugins.winorlose.Config.MinimumPercentage / 100)))
	return result
end

-- local function stopTeamPlayersFromAttacking(teamNumber)
-- 	TGNS.DoFor(TGNS.GetPlayers(TGNS.GetTeamClients(teamNumber)), function(p)
-- 		pcall(function()
-- 			p:SelectNextWeapon()
-- 			p:SelectPrevWeapon()
-- 		end)
-- 	end)
-- end

local function onVoteSuccessful(teamNumber)
	local teamName = TGNS.GetTeamName(teamNumber)
	local chatMessage = string.sub(string.format("WinOrLose! %s can't attack! End it in %s secs, or THEY WIN!", teamName, Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds), 1, kMaxChatLength)
	md:ToAllNotifyInfo(chatMessage)

	kTimeAtWhichWinOrLoseVoteSucceeded = TGNS.GetSecondsSinceMapLoaded()
	kTeamWhichWillWinIfWinLoseCountdownExpires = TGNS.GetTeamFromTeamNumber(teamNumber)
	numberOfSecondsToDeductFromCountdownTimeRemaining = 4
	kCountdownTimeRemaining = Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds

	--stopTeamPlayersFromAttacking(teamNumberWhichWillWinIfWinLoseCountdownExpires)

	kWinOrLoseVoteArray[teamNumber].WinOrLoseVotesAlertTime = 0
	kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning = 0
	kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes = { }
	TGNS.ExecuteEventHooks("WinOrLoseCalled", teamNumber)
	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
		TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.SHOW_TEAM_MESSAGES, {s=false})
	end)
end

local function UpdateWinOrLoseVotes()
	if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
		local teamNumberWhichWillWinIfWinLoseCountdownExpires = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber()
		if kCountdownTimeRemaining > 0 then
			if ((lastBannerDisplayCountdownRemaining == nil or lastBannerDisplayCountdownRemaining >= kCountdownTimeRemaining + Shine.Plugins.winorlose.Config.WarningIntervalInSeconds) or kCountdownTimeRemaining <= 5) then
				local commandStructures = TGNS.GetEntitiesForTeam("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires)
				TGNS.DoFor(commandStructures, function(s)
					s.GetCanBeHealedOverride = function(self) return false, false end
					s.GetCanBeWeldedOverride = function(self, doer) return false, false end
				end)
				local teamName = TGNS.GetTeamName(teamNumberWhichWillWinIfWinLoseCountdownExpires)
				local chatMessage = string.format("%s can't attack. Game ends in %s seconds.", teamName, kCountdownTimeRemaining)
				local commandStructureToKeep = GetCommandStructureToKeep(commandStructures)
				local bannerLocationName = ""
				if commandStructureToKeep ~= nil then
					if teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType then
						commandStructureToKeep.GetCanBeNanoShieldedOverride = function(self, resultTable)
		    				resultTable.shieldedAllowed = false
		    				local commanderClient = TGNS.GetFirst(TGNS.Where(TGNS.GetTeamClients(teamNumberWhichWillWinIfWinLoseCountdownExpires), TGNS.IsClientCommander))
		    				local commanderPlayer = TGNS.GetPlayer(commanderClient)
		    				md:ToPlayerNotifyError(commanderPlayer, "Command chairs may not be nanoshielded during WinOrLose.")
		    			end
					end
					local locationNameOfCommandStructureToKeep = commandStructureToKeep:GetLocationName()
					TGNS.DestroyEntitiesExcept(commandStructures, commandStructureToKeep)
					bannerLocationName = string.format(" in %s", locationNameOfCommandStructureToKeep)
				end

				local teamNameWhichMustWinOrLose = TGNS.GetTeamName(TGNS.GetOtherPlayingTeamNumber(teamNumberWhichWillWinIfWinLoseCountdownExpires))
				TGNS.DoFor(TGNS.GetPlayingClients(TGNS.GetPlayerList()), function(c)
					local teamNumber = TGNS.PlayerAction(c, TGNS.GetPlayerTeamNumber)
					local playerIsMarine = teamNumber == kMarineTeamType
					local b = playerIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
					local r = playerIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
					local g = playerIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
					local winningTeamText = string.format("WinOrLose! Kill the %s%s!", TGNS.GetTeamCommandStructureCommonName(teamNumberWhichWillWinIfWinLoseCountdownExpires), bannerLocationName)
					local losingTeamText = string.format("Your team has surrendered. %s must WinOrLose!", teamNameWhichMustWinOrLose)
					local bannerText = teamNumber == teamNumberWhichWillWinIfWinLoseCountdownExpires and losingTeamText or winningTeamText
					Shine:SendText(c, Shine.BuildScreenMessage(71, 0.5, 0.2, bannerText, Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, r, g, b, 1, 3, 0 ) )
					Shine:SendText(c, Shine.BuildScreenMessage(72, 0.5, 0.24, chatMessage, Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, r, g, b, 1, 1, 0 ) )
				end)
				local spectatorsText = string.format("WinOrLose! %s have %s seconds to kill the %s%s!", teamNameWhichMustWinOrLose, kCountdownTimeRemaining, TGNS.GetTeamCommandStructureCommonName(teamNumberWhichWillWinIfWinLoseCountdownExpires), bannerLocationName)
				TGNS.DoFor(TGNS.GetSpectatorClients(TGNS.GetPlayerList()), function(c)
					Shine:SendText(c, Shine.BuildScreenMessage(74, 0.5, 0.85, spectatorsText, Shine.Plugins.winorlose.Config.WarningIntervalInSeconds + 1, 255, 255, 255, 1, 1, 0))
				end)
				TGNS.DoFor(ENTITY_CLASSNAMES_TO_DESTROY_ON_LOSING_TEAM, function(className)
					TGNS.DestroyAllEntities(className, teamNumberWhichWillWinIfWinLoseCountdownExpires)
				end)
				lastBannerDisplayCountdownRemaining = kCountdownTimeRemaining
			end
			kCountdownTimeRemaining = kCountdownTimeRemaining - 1
		else
			removeBanners()
			Shine:SendText(nil, Shine.BuildScreenMessage(75, 0.5, 0.2, "WinOrLose, on to the next game!", 7, 255, 255, 255, 1, 3, 0 ) )
			-- Shine:SendText(nil, Shine.BuildScreenMessage(72, 0.5, 0.24, "", 1, 255, 255, 255, 1, 1, 0))
			-- Shine:SendText(nil, Shine.BuildScreenMessage(74, 0.5, 0.85, "", 1, 255, 255, 255, 1, 1, 0))
			TGNS.DestroyAllEntities("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType and kAlienTeamType or kMarineTeamType)
			kTimeAtWhichWinOrLoseVoteSucceeded = 0
		end
		TGNS.ExecuteEventHooks("WinOrLoseCountdownChanged", kCountdownTimeRemaining)
	else
		for i = 1, kWinOrLoseTeamCount do
			if kWinOrLoseVoteArray[i].WinOrLoseRunning ~= 0 and TGNS.IsGameInProgress() and kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime + Shine.Plugins.winorlose.Config.AlertDelayInSeconds < TGNS.GetSecondsSinceMapLoaded() then
				local playerRecords = TGNS.GetPlayers(TGNS.GetMatchingClients(TGNS.GetPlayerList(), function(c,p) return p:GetTeamNumber() == i end))
				local totalvotes = 0
				for j = #kWinOrLoseVoteArray[i].WinOrLoseVotes, 1, -1 do
					local clientid = kWinOrLoseVoteArray[i].WinOrLoseVotes[j]
					local stillplaying = false

					for k = 1, #playerRecords do
						local player = playerRecords[k]
						if player ~= nil then
							local client = Server.GetOwner(player)
							if client ~= nil then
								if clientid == client:GetUserId() then
									stillplaying = true
									totalvotes = totalvotes + 1
									break
								end
							end
						end
					end

					if not stillplaying then
						table.remove(kWinOrLoseVoteArray[i].WinOrLoseVotes, j)
					end
				end
				if totalvotes >= getNumberOfRequiredVotes(#playerRecords) then
					onVoteSuccessful(i)
				else
					local chatMessage
					if kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime == 0 then
						chatMessage = string.sub(string.format("Concede vote started. %s votes are needed. %s", getNumberOfRequiredVotes(#playerRecords), VOTE_HOWTO_TEXT), 1, kMaxChatLength)
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = TGNS.GetSecondsSinceMapLoaded()
					elseif kWinOrLoseVoteArray[i].WinOrLoseRunning + Shine.Plugins.winorlose.Config.VotingTimeInSeconds < TGNS.GetSecondsSinceMapLoaded() then
						--local abstainedNames = {}
						--TGNS.DoFor(playerRecords, function(p)
						--	local playerSteamId = TGNS.ClientAction(p, TGNS.GetClientSteamId)
						--	if not TGNS.Has(kWinOrLoseVoteArray[i].WinOrLoseVotes, playerSteamId) then
						--		table.insert(abstainedNames, TGNS.GetPlayerName(p))
						--	end
						--end)
						--chatMessage = string.sub(string.format("Concede vote expired. Abstained: %s", TGNS.Join(abstainedNames, ", ")), 1, kMaxChatLength)
						chatMessage = "Concede vote expired."
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
						kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
						kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
					else
						chatMessage = string.sub(string.format("%s/%s votes to concede; %s secs left. %s", totalvotes,
						 getNumberOfRequiredVotes(#playerRecords),
						 math.ceil((kWinOrLoseVoteArray[i].WinOrLoseRunning + Shine.Plugins.winorlose.Config.VotingTimeInSeconds) - TGNS.GetSecondsSinceMapLoaded()), VOTE_HOWTO_TEXT), 1, kMaxChatLength)
						kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = TGNS.GetSecondsSinceMapLoaded()
					end
					md:ToTeamNotifyInfo(i, chatMessage)
					-- TGNS.DoFor(playerRecords, function(p)
					-- 	md:ToPlayerNotifyInfo(p, chatMessage)
					-- end)
				end
			end
		end
	end
end

local function ClearWinOrLoseVotes()
	for i = 1, kWinOrLoseTeamCount do
		kWinOrLoseVoteArray[i].WinOrLoseVotesAlertTime = 0
		kWinOrLoseVoteArray[i].WinOrLoseRunning = 0
		kWinOrLoseVoteArray[i].WinOrLoseVotes = { }
	end
	kTimeAtWhichWinOrLoseVoteSucceeded = 0
	lastVoteStartTimes = {}
	lastBannerDisplayCountdownRemaining = nil
end

local function OnCommandWinOrLose(client)
	local player = TGNS.GetPlayer(client)
	if TGNS.IsGameInProgress() then
		if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
			md:ToPlayerNotifyError(player, "WinOrLose in progress.")
		elseif TGNS.GetSecondsSinceMapLoaded() < mayVoteAt then
			md:ToPlayerNotifyError(player, "You may not yet WinOrLose.")
		else
			--if player:GetTeam():GetNumAliveCommandStructures() <= 2 then
				local clientID = client:GetUserId()
				local teamNumber = TGNS.GetPlayerTeamNumber(player)
				if TGNS.IsGameplayTeamNumber(teamNumber) then
					if kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning ~= 0 then
						local alreadyvoted = false
						for i = #kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes, 1, -1 do
							if kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes[i] == clientID then
								alreadyvoted = true
								break
							end
						end
						if alreadyvoted then
							chatMessage = string.sub(string.format("You already voted to concede."), 1, kMaxChatLength)
							md:ToPlayerNotifyError(player, chatMessage)
						else
							md:ToTeamNotifyInfo(teamNumber, string.format("%s voted to concede. %s", TGNS.GetPlayerName(player), VOTE_HOWTO_TEXT))
							table.insert(kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes, clientID)
						end
					else
						if lastVoteStartTimes[client] == nil or lastVoteStartTimes[client] + 180 <= TGNS.GetSecondsSinceMapLoaded() then
							md:ToTeamNotifyInfo(teamNumber, string.format("%s started a concede vote. %s", TGNS.GetPlayerName(player), VOTE_HOWTO_TEXT))
							kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning = TGNS.GetSecondsSinceMapLoaded()
							table.insert(kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes, clientID)
							lastVoteStartTimes[client] = TGNS.GetSecondsSinceMapLoaded()
						else
							md:ToPlayerNotifyError(player, "You started a vote too recently. When another")
							md:ToPlayerNotifyError(player, "teammate starts a vote, you may participate.")
						end
					end
				else
					md:ToPlayerNotifyError(player, "You must be on a team.")
				end
			--else
			--	chatMessage = string.sub(string.format("You may concede only when you have one or two command structures."), 1, kMaxChatLength)
			--	Server.SendNetworkMessage(player, "Chat", BuildChatMessage(false, "PM - " .. DAK.config.language.MessageSender, -1, kTeamReadyRoom, kNeutralTeamType, chatMessage), true)
			--end
		end
	else
		md:ToPlayerNotifyError(player, "Game is not in progress.")
	end
end

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "winorlose.json"

function Plugin:CreateCommands()
	local command = self:BindCommand("sh_winorlose", nil, OnCommandWinOrLose, true)
	command:Help("Cast a WinOrLose vote.")
end

function Plugin:CallWinOrLose(teamNumber)
	onVoteSuccessful(teamNumber)
end

function Plugin:TakeDamage( Ent, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
	if kTimeAtWhichWinOrLoseVoteSucceeded > 0 and kCountdownTimeRemaining > 0 and Attacker and Attacker:isa("Player") and Attacker:GetTeamNumber() == kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber() and Ent and Ent:GetTeamNumber() ~= Attacker:GetTeamNumber() then
		--Shared.Message("YES WINORLOSE")
		Damage = 0
		HealthUsed = 0
		ArmourUsed = 0
		local client = TGNS.GetClient(Attacker)
		if client and (lastNoAttackNoticeTimes[client] == nil or lastNoAttackNoticeTimes[client] < Shared.GetTime() - 1) then
			local playerIsMarine = Attacker:GetTeamNumber() == kMarineTeamType
			local r = playerIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
			local g = playerIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
			local b = playerIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
			Shine:SendText(client, Shine.BuildScreenMessage(70, 0.5, 0.4, "You cannot do damage.", 6, r, g, b, 1, 3, 0 ) )
			lastNoAttackNoticeTimes[client] = Shared.GetTime()
		end
	else
		--Shared.Message("NO WINORLOSE")
	end
	return Damage, ArmourUsed, HealthUsed
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("WINORLOSE")
	-- originalGetCanAttack = TGNS.ReplaceClassMethod("Player", "GetCanAttack", function(self)
	-- 	local winOrLoseChallengeIsInProgressByMyTeam = kTimeAtWhichWinOrLoseVoteSucceeded > 0 and self:GetTeam() == kTeamWhichWillWinIfWinLoseCountdownExpires
	-- 	local canAttack = originalGetCanAttack(self) and not winOrLoseChallengeIsInProgressByMyTeam
	-- 	return canAttack
	-- end)
	TGNS.RegisterEventHook("GameStarted", function()
		mayVoteAt = TGNS.GetSecondsSinceMapLoaded() + 5
	end)
	SetupWinOrLoseVars()
	TGNS.RegisterEventHook("OnEverySecond", function()
		if TGNS.IsGameInProgress() then
			UpdateWinOrLoseVotes()
		end
	end)
	self:CreateCommands()
    return true
end

function Plugin:EndGame(gamerules, winningTeam)
	ClearWinOrLoseVotes()
	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
		TGNS.SendNetworkMessageToPlayer(p, Shine.Plugins.scoreboard.SHOW_TEAM_MESSAGES, {s=true})
	end)
	removeBanners()
end

function Plugin:CastVoteByPlayer(gamerules, voteTechId, player)
	local cancel = false
	if voteTechId == kTechId.VoteConcedeRound then
		TGNS.ClientAction(player, OnCommandWinOrLose)
		cancel = true
	end
	if cancel then
		return true
	end
end

function Plugin:OnEntityKilled(gamerules, victimEntity, attackerEntity, inflictorEntity, point, direction)
	if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
		local teamNumberWhichWillWinIfWinLoseCountdownExpires = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber()
		if TGNS.EntityIsCommandStructure(victimEntity) and victimEntity:GetTeamNumber() == teamNumberWhichWillWinIfWinLoseCountdownExpires then
			TGNS.DestroyAllEntities("CommandStructure", victimEntity:GetTeamNumber())
		else
			if kCountdownTimeRemaining > 0 and victimEntity and victimEntity:isa("Player") and victimEntity:GetTeamNumber() == teamNumberWhichWillWinIfWinLoseCountdownExpires then
				Shine:SendText(victimEntity, Shine.BuildScreenMessage(70, 0.5, 0.4, "", 6, 255, 255, 255, 1, 3, 0 ) )
			end
			if kCountdownTimeRemaining < Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds - 2 then
				if victimEntity and attackerEntity and victimEntity:isa("Player") and attackerEntity:isa("Player") and inflictorEntity:GetParent() == attackerEntity and not TGNS.GetIsClientVirtual(TGNS.GetClient(victimEntity)) and not TGNS.IsPlayerHallucination(victimEntity) then
					local commandStructureDescription = TGNS.GetTeamCommandStructureCommonName(teamNumberWhichWillWinIfWinLoseCountdownExpires)
					local attackerTeamNumber = TGNS.GetPlayerTeamNumber(attackerEntity)
					local attackerIsMarine = attackerTeamNumber == kMarineTeamType
					local attackerRed = attackerIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
					local attackerGreen = attackerIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
					local attackerBlue = attackerIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
					local victimTeamNumber = TGNS.GetPlayerTeamNumber(victimEntity)
					local victimIsMarine = victimTeamNumber == kMarineTeamType
					local victimRed = victimIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
					local victimGreen = victimIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
					local victimBlue = victimIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
					if kCountdownTimeRemaining > 22 then
						if attackerTeamNumber ~= teamNumberWhichWillWinIfWinLoseCountdownExpires and victimTeamNumber == teamNumberWhichWillWinIfWinLoseCountdownExpires then
							numberOfSecondsToDeductFromCountdownTimeRemaining = numberOfSecondsToDeductFromCountdownTimeRemaining + 1
							numberOfSecondsToDeductFromCountdownTimeRemaining = numberOfSecondsToDeductFromCountdownTimeRemaining > 8 and 8 or numberOfSecondsToDeductFromCountdownTimeRemaining
							kCountdownTimeRemaining = kCountdownTimeRemaining - numberOfSecondsToDeductFromCountdownTimeRemaining
							local attackerTeamNumber = TGNS.GetPlayerTeamNumber(attackerEntity)
							local attackerIsMarine = attackerTeamNumber == kMarineTeamType
							local attackerRed = attackerIsMarine and TGNS.MARINE_COLOR_R or TGNS.ALIEN_COLOR_R
							local attackerGreen = attackerIsMarine and TGNS.MARINE_COLOR_G or TGNS.ALIEN_COLOR_G
							local attackerBlue = attackerIsMarine and TGNS.MARINE_COLOR_B or TGNS.ALIEN_COLOR_B
							TGNS.DoFor(TGNS.GetTeamClients(attackerTeamNumber, TGNS.GetPlayerList()), function(c)
								Shine:SendText(c, Shine.BuildScreenMessage(73, 0.5, 0.4, string.format("%s killed a player. Timer reduced to %s!", TGNS.GetPlayerName(attackerEntity), kCountdownTimeRemaining), 3, attackerRed, attackerGreen, attackerBlue, 1, 2, 0 ) )
							end)
							TGNS.DoFor(TGNS.GetTeamClients(victimTeamNumber, TGNS.GetPlayerList()), function(c)
								Shine:SendText(c, Shine.BuildScreenMessage(73, 0.5, 0.7, string.format("%s did not die in vain! Timer reduced!", TGNS.GetPlayerName(victimEntity)), 6, victimRed, victimGreen, victimBlue, 1, 3, 0 ) )
							end)
						end
					else
						TGNS.DoFor(TGNS.GetTeamClients(victimTeamNumber, TGNS.GetPlayerList()), function(c)
							Shine:SendText(c, Shine.BuildScreenMessage(73, 0.5, 0.7, string.format("%s has fallen, yet the %s still stands!", TGNS.GetPlayerName(victimEntity), TGNS.ToLower(commandStructureDescription)), 6, victimRed, victimGreen, victimBlue, 1, 3, 0 ) )
						end)
					end
				end
			end
		end
	end
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup(self)
end

Shine:RegisterExtension("winorlose", Plugin)