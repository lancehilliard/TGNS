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

local originalGetCanAttack

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

local function onVoteSuccessful(teamNumber, players)
	local teamName = TGNS.GetTeamName(teamNumber)
	local chatMessage = string.sub(string.format("WinOrLose! %s can't attack! End it in %s secs, or THEY WIN!", teamName, Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds), 1, kMaxChatLength)
	md:ToAllNotifyInfo(chatMessage)
	kTimeAtWhichWinOrLoseVoteSucceeded = TGNS.GetSecondsSinceMapLoaded()
	kTeamWhichWillWinIfWinLoseCountdownExpires = TGNS.GetTeamFromTeamNumber(teamNumber)
	numberOfSecondsToDeductFromCountdownTimeRemaining = 2
	kCountdownTimeRemaining = Shine.Plugins.winorlose.Config.NoAttackDurationInSeconds
	TGNS.DoFor(players, function(p)
		pcall(function()
			p:SelectNextWeapon()
			p:SelectPrevWeapon()
		end)
	end)
	kWinOrLoseVoteArray[teamNumber].WinOrLoseVotesAlertTime = 0
	kWinOrLoseVoteArray[teamNumber].WinOrLoseRunning = 0
	kWinOrLoseVoteArray[teamNumber].WinOrLoseVotes = { }
end

local function UpdateWinOrLoseVotes()
	if kTimeAtWhichWinOrLoseVoteSucceeded > 0 then
		local teamNumberWhichWillWinIfWinLoseCountdownExpires = kTeamWhichWillWinIfWinLoseCountdownExpires:GetTeamNumber()
		if kCountdownTimeRemaining > 0 then
			if (math.fmod(kCountdownTimeRemaining, Shine.Plugins.winorlose.Config.WarningIntervalInSeconds) == 0 or kCountdownTimeRemaining <= 5) then
				local commandStructures = TGNS.GetEntitiesForTeam("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires)
				local commandStructureToKeep = GetCommandStructureToKeep(commandStructures)
				if teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType then
					commandStructureToKeep.GetCanBeNanoShieldedOverride = function(self, resultTable)
	    				resultTable.shieldedAllowed = false
	    				local commanderClient = TGNS.GetFirst(TGNS.Where(TGNS.GetTeamClients(teamNumberWhichWillWinIfWinLoseCountdownExpires), TGNS.IsClientCommander))
	    				local commanderPlayer = TGNS.GetPlayer(commanderClient)
	    				md:ToPlayerNotifyError(commanderPlayer, "Command chairs may not be nanoshielded during WinOrLose.")
	    			end
				end
				TGNS.DestroyEntitiesExcept(commandStructures, commandStructureToKeep)
				local teamName = TGNS.GetTeamName(teamNumberWhichWillWinIfWinLoseCountdownExpires)
				local locationNameOfCommandStructureToKeep = commandStructureToKeep:GetLocationName()
				local chatMessage = string.format("%s can't attack. Game ends in %s secs. Hurry to %s!", teamName, kCountdownTimeRemaining, locationNameOfCommandStructureToKeep)
				md:ToAllNotifyInfo(chatMessage)
				TGNS.DoFor(ENTITY_CLASSNAMES_TO_DESTROY_ON_LOSING_TEAM, function(className)
					TGNS.DestroyAllEntities(className, teamNumberWhichWillWinIfWinLoseCountdownExpires)
				end)
			end
			kCountdownTimeRemaining = kCountdownTimeRemaining - 1
		else
			md:ToAllNotifyInfo("WinOrLose! On to the next game!")
			TGNS.DestroyAllEntities("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType and kAlienTeamType or kMarineTeamType)
			kTimeAtWhichWinOrLoseVoteSucceeded = 0
		end
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
					onVoteSuccessful(i, playerRecords)
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
	onVoteSuccessful(teamNumber, TGNS.GetPlayers(TGNS.GetTeamClients(teamNumber)))
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("WINORLOSE")
	originalGetCanAttack = TGNS.ReplaceClassMethod("Player", "GetCanAttack", function(self)
		local winOrLoseChallengeIsInProgressByMyTeam = kTimeAtWhichWinOrLoseVoteSucceeded > 0 and self:GetTeam() == kTeamWhichWillWinIfWinLoseCountdownExpires
		local canAttack = originalGetCanAttack(self) and not winOrLoseChallengeIsInProgressByMyTeam
		return canAttack
	end)
	TGNS.RegisterEventHook("GameStarted", function()
		mayVoteAt = TGNS.GetSecondsSinceMapLoaded() + 5
	end)
	SetupWinOrLoseVars()
	TGNS.RegisterEventHook("OnEverySecond", UpdateWinOrLoseVotes)
	self:CreateCommands()
    return true
end

function Plugin:EndGame(gamerules, winningTeam)
	ClearWinOrLoseVotes()
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
			if kCountdownTimeRemaining < 57 then
				if victimEntity:isa("Player") and attackerEntity:isa("Player") and inflictorEntity:GetParent() == attackerEntity then
					local commandStructureDescription = teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType and "CHAIR" or "HIVE"
					if kCountdownTimeRemaining > 23 then
						if TGNS.GetPlayerTeamNumber(attackerEntity) ~= teamNumberWhichWillWinIfWinLoseCountdownExpires and TGNS.GetPlayerTeamNumber(victimEntity) == teamNumberWhichWillWinIfWinLoseCountdownExpires then
							numberOfSecondsToDeductFromCountdownTimeRemaining = numberOfSecondsToDeductFromCountdownTimeRemaining + 1
							numberOfSecondsToDeductFromCountdownTimeRemaining = numberOfSecondsToDeductFromCountdownTimeRemaining > 8 and 8 or numberOfSecondsToDeductFromCountdownTimeRemaining
							kCountdownTimeRemaining = kCountdownTimeRemaining - numberOfSecondsToDeductFromCountdownTimeRemaining
							--local secondsDescription = numberOfSecondsToDeductFromCountdownTimeRemaining > 1 and "more seconds" or "second"
							md:ToTeamNotifyInfo(TGNS.GetPlayerTeamNumber(attackerEntity), string.format("%s killed a player. Timer reduced to %s! Kill the %s!", TGNS.GetPlayerName(attackerEntity), kCountdownTimeRemaining, commandStructureDescription))
							md:ToTeamNotifyInfo(TGNS.GetPlayerTeamNumber(victimEntity), string.format("%s did not die in vain! Timer reduced!", TGNS.GetPlayerName(victimEntity)))
						end
					else
						md:ToTeamNotifyInfo(TGNS.GetPlayerTeamNumber(victimEntity), string.format("%s has fallen, yet the %s still stands!", TGNS.GetPlayerName(victimEntity), TGNS.ToLower(commandStructureDescription)))
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