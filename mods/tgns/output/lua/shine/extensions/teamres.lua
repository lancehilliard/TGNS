local abandonedResources
local lastKnownGameplayTeamNumber
local md = TGNSMessageDisplayer.Create("TEAMRES")

local function debugLog(message)
	-- if TGNS.IsGameInProgress() then
	-- 	md:ToAdminConsole(message)
	-- end
end

local function ResetAbandonedResources()
	abandonedResources = {
      [1] = {},
      [2] = {}
    }
	lastKnownGameplayTeamNumber = {}
end
ResetAbandonedResources()

local function AnnounceAbandonedResources(client, resources)
	//local debugMessage = string.format("%s abandoned %s resources.", TGNS.GetClientName(client), math.floor(resources))
	//if math.floor(resources) > 0 then
	//	md:ToAdminConsole(debugMessage)
	//end
end

local function AbandonResources(client)
	if TGNS.IsGameInProgress() then
		local player = TGNS.GetPlayer(client)
		local playerTeamNumber = TGNS.GetPlayerTeamNumber(player)
		debugLog(string.format("AbandonResources: player team number: %s", playerTeamNumber))
		if TGNS.IsGameplayTeamNumber(playerTeamNumber) then
			debugLog(string.format("AbandonResources: player team number is gameplay team number..."))
			if abandonedResources[playerTeamNumber][client] == nil then
				debugLog(string.format("AbandonResources: no abandoned resources yet from this client..."))
				local resources = TGNS.GetPlayerTotalCost(player)
				debugLog(string.format("AbandonResources: player total cost: %s. Retaining resources...", resources))
				abandonedResources[playerTeamNumber][client] = resources
				debugLog(string.format("AbandonResources: setting player resources to 0..."))
				TGNS.SetPlayerResources(player, 0)
				debugLog(string.format("AbandonResources: announcing abandoned resources..."))
				AnnounceAbandonedResources(client, resources)
				if resources > 100 then
					local extraResources = resources - 100
					debugLog(string.format("AbandonResources: Resources are > 100. Retaining %s extra resources...", extraResources))
					abandonedResources[playerTeamNumber][TGNS.GetClientSteamId(client) .. Shared.GetTime()] = extraResources
					debugLog(string.format("AbandonResources: Retaining 100 resources..."))
					abandonedResources[playerTeamNumber][client] = 100
				end
			else
				debugLog(string.format("AbandonResources: abandoned resources already retained for client..."))
			end
		end
	end
end

local function AnnounceReceivedResources(player, resources)
	local message = string.format("%s got %s resources from a departed teammate.", TGNS.GetPlayerName(player), math.floor(resources))
	if math.floor(resources) > 0 then
		md:ToPlayerNotifyInfo(player, message)
		md:ToAdminConsole(message)
	end
end

-- debugLog(string.format("DistributeResources: "))

local function DistributeAbandonedResources(client, teamNumber)
	local player = TGNS.GetPlayer(client)
	local playerTeamNumber = TGNS.GetPlayerTeamNumber(player)
	debugLog(string.format("DistributeResources: player team number: %s", playerTeamNumber))
	if TGNS.IsGameplayTeamNumber(playerTeamNumber) and playerTeamNumber == teamNumber then
		debugLog(string.format("DistributeResources: player is on gameplay team and playerTeamNumber == teamNumber..."))
		local resKey
		local giveableResources
		if lastKnownGameplayTeamNumber[client] == teamNumber then
			debugLog(string.format("DistributeResources: teamNumber is client's last known gameplay team number..."))
			resKey = client
			giveableResources = abandonedResources[playerTeamNumber][client]
			debugLog(string.format("DistributeResources: giveableResources: %s...", giveableResources))
		else
			TGNS.DoForPairs(abandonedResources[playerTeamNumber], function(key, resources)
				if resources ~= nil and (giveableResources == nil or resources > giveableResources) then
					giveableResources = resources
					resKey = key
					debugLog(string.format("DistributeResources: giveableResources: %s...", giveableResources))
				end
			end)
		end
		if giveableResources ~= nil then
			debugLog(string.format("DistributeResources: giveable resources found..."))
			local originalResources = TGNS.GetPlayerResources(player)
			debugLog(string.format("DistributeResources: player original resources: %s...", originalResources))
			if math.floor(giveableResources) > math.floor(originalResources) then
				debugLog(string.format("DistributeResources: player has fewer resources than are giveable. Setting player resources to %s.", giveableResources))
				TGNS.SetPlayerResources(player, giveableResources)
				local resourcesToRetain = math.floor(originalResources) > 0 and originalResources or nil
				debugLog(string.format("DistributeResources: setting abandoned resources for %s to %s...", Shine:IsValidClient(resKey) and TGNS.GetClientName(resKey) or resKey, resourcesToRetain))
				abandonedResources[playerTeamNumber][resKey] = resourcesToRetain
				debugLog(string.format("DistributeResources: announcing abandoned resources..."))
				AnnounceAbandonedResources(client, originalResources)
				debugLog(string.format("DistributeResources: announcing received resources..."))
				AnnounceReceivedResources(player, giveableResources)
			end
		end
		lastKnownGameplayTeamNumber[client] = teamNumber
	end
end

//local function ShowPlayerCosts(client)
//	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
//		local name = TGNS.GetPlayerName(p)
//		local className = TGNS.GetPlayerClassName(p)
//		local classPurchaseCost = TGNS.GetPlayerClassPurchaseCost(p)
//		local weaponsCost = TGNS.GetMarineWeaponsTotalPurchaseCost(p)
//		TGNS.ConsolePrint(client, string.format("%s: %s worth %s with weapons worth %s", name, className, classPurchaseCost, weaponsCost), "COSTS")
//	end)
//end
//TGNS.RegisterCommandHook("Console_sv_showcosts", ShowPlayerCosts, "Print costs of all players.")

local Plugin = {}

function Plugin:EndGame()
	ResetAbandonedResources()
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	debugLog(string.format("ADMINDEBUG JoinTeam: %s changing teams... getting current team number...", TGNS.GetPlayerName(player)))
	local playerTeamNumber = TGNS.GetPlayerTeamNumber(player)
	debugLog(string.format("ADMINDEBUG JoinTeam: %s changing teams from %s to %s...", TGNS.GetPlayerName(player), TGNS.GetPlayerTeamNumber(player), TGNS.GetTeamName(newTeamNumber)))
	local joiningClient = TGNS.GetClient(player)
	debugLog(string.format("ADMINDEBUG JoinTeam: joiningClient object is %s...", joiningClient and "not nil" or "nil"))
	local playerIsDroppingToReadyRoom = TGNS.IsGameplayTeamNumber(playerTeamNumber) and newTeamNumber == kTeamReadyRoom
	debugLog(string.format("ADMINDEBUG JoinTeam: Player %s dropping to Ready Room...", playerIsDroppingToReadyRoom and "is" or "is not"))
	local playerIsJoiningTeam = TGNS.IsGameplayTeamNumber(newTeamNumber)
	debugLog(string.format("ADMINDEBUG JoinTeam: Player %s joining a playing team...", playerIsJoiningTeam and "is" or "is not"))
	if playerIsDroppingToReadyRoom then
		debugLog(string.format("ADMINDEBUG JoinTeam: Abandoning resources..."))
		AbandonResources(joiningClient)
	elseif playerIsJoiningTeam then
		debugLog(string.format("ADMINDEBUG JoinTeam: Scheduling res distribution..."))
		TGNS.ScheduleAction(2, function()
			if Shine:IsValidClient(joiningClient) then
				debugLog(string.format("ADMINDEBUG JoinTeam: joiningClient is valid Shine client. Distributing abandoned resources..."))
				DistributeAbandonedResources(joiningClient, newTeamNumber)
			else
				debugLog(string.format("ADMINDEBUG JoinTeam: joiningClient is not valid Shine client..."))
			end
		end)
	end
end

function Plugin:CreateCommands()
	local debugCommand = self:BindCommand("sh_teamres", nil, function(client)
		local printAction = function(key, resources) debugLog(string.format("%s: %s", Shine:IsValidClient(key) and TGNS.GetClientName(key) or key, resources)) end
		TGNS.DoForPairs(abandonedResources[1], printAction)
		TGNS.DoForPairs(abandonedResources[2], printAction)
	end)
	debugCommand:Help("Show retained resources for both teams.")
end

function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("teamres", Plugin )