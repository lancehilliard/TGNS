local ENTITY_CLASSNAMES_TO_DESTROY_ON_LOSING_TEAM = { "Sentry", "Mine", "Armory", "Whip", "Clog", "Hydra", "Crag" }
local timeInSecondsAtWhichVoteSucceeded = 0
local teamWhichWillWinIfCountdownExpires = nil
local secondsRemainingInCountdown = 0
local md = TGNSMessageDisplayer.Create("WINORLOSE")

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

local function OnEntityKilled(self, targetEntity, attacker, doer, point, direction)
	if timeInSecondsAtWhichVoteSucceeded > 0 then
		if TGNS.EntityIsCommandStructure(targetEntity) then
			TGNS.DestroyAllEntities("CommandStructure", targetEntity:GetTeamNumber())
		end
	end
end
TGNS.RegisterEventHook("OnEntityKilled", OnEntityKilled)

local originalGetCanAttack
originalGetCanAttack = TGNS.ReplaceClassMethod("Player", "GetCanAttack",
	function(self)
		local winOrLoseChallengeIsInProgressByMyTeam = timeInSecondsAtWhichVoteSucceeded > 0 and self:GetTeam() == teamWhichWillWinIfCountdownExpires
		local canAttack = originalGetCanAttack(self) and not winOrLoseChallengeIsInProgressByMyTeam
		return canAttack
	end
)

TGNS.RegisterEventHook("OnEverySecond", function(deltatime)
	if TGNS.IsGameInProgress() then
		if timeInSecondsAtWhichVoteSucceeded > 0 then
			local teamNumberWhichWillWinIfWinLoseCountdownExpires = teamWhichWillWinIfCountdownExpires:GetTeamNumber()
			local countdownFinished = Shared.GetTime() - timeInSecondsAtWhichVoteSucceeded > Shine.Plugins.winorlose.Config.NoAttackDuration
			if countdownFinished then
				md:ToAllNotifyInfo("WinOrLose! On to the next game!")
				TGNS.DestroyAllEntities("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType and kAlienTeamType or kMarineTeamType)
				timeInSecondsAtWhichVoteSucceeded = 0
			else
				if (math.fmod(secondsRemainingInCountdown, Shine.Plugins.winorlose.Config.WarningInterval) == 0 or secondsRemainingInCountdown <= 5) then
					local commandStructures = TGNS.GetEntitiesForTeam("CommandStructure", teamNumberWhichWillWinIfWinLoseCountdownExpires)
					local commandStructureToKeep = GetCommandStructureToKeep(commandStructures)
					TGNS.DestroyEntitiesExcept(commandStructures, commandStructureToKeep)
					local teamDescription = teamNumberWhichWillWinIfWinLoseCountdownExpires == kMarineTeamType and "Marines" or "Aliens"
					local locationNameOfCommandStructureToKeep = commandStructureToKeep:GetLocationName()
					local chatMessage = string.format("%s can't attack. Game ends in %s secs. Hurry to %s!", teamDescription, secondsRemainingInCountdown, locationNameOfCommandStructureToKeep)
					md:ToAllNotifyInfo(chatMessage)
					TGNS.DoFor(ENTITY_CLASSNAMES_TO_DESTROY_ON_LOSING_TEAM, function(className)
						TGNS.DestroyAllEntities(className, teamNumberWhichWillWinIfWinLoseCountdownExpires)
					end)
				end
				secondsRemainingInCountdown = secondsRemainingInCountdown - 1
			end
		end
	end
end)

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "winorlose.json"

function Plugin:EndGame(gamerules, winningTeam)
	timeInSecondsAtWhichVoteSucceeded = 0
end


function Plugin:Initialise()
    self.Enabled = true
    TGNS.ScheduleAction(10, function()
		Shine.Plugins.votesurrender.Surrender = function(x, team)
			local teamDescription = team == kMarineTeamType and "Marines" or "Aliens"
			local chatMessage = string.sub(string.format("WinOrLose! %s can't attack! End it in %s secs, or THEY WIN!", teamDescription, Shine.Plugins.winorlose.Config.NoAttackDuration), 1, kMaxChatLength)
			md:ToAllNotifyInfo(chatMessage)
			timeInSecondsAtWhichVoteSucceeded = Shared.GetTime()
			teamWhichWillWinIfCountdownExpires = GetGamerules():GetTeam(team)
			secondsRemainingInCountdown = Shine.Plugins.winorlose.Config.NoAttackDuration
			local teamPlayers = TGNS.GetPlayers(TGNS.GetTeamClients(team, TGNS.GetPlayerList()))
			TGNS.DoFor(teamPlayers, function(p)
				p:SelectNextWeapon()
				p:SelectPrevWeapon()
			end)
		end
    end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("winorlose", Plugin )