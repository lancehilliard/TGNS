Script.Load("lua/TGNSCommon.lua")

local abandonedResources
local lastKnownGameplayTeamNumber

local function ResetAbandonedResources()
	abandonedResources = {
      [1] = {},
      [2] = {}
    }
	lastKnownGameplayTeamNumber = {}
end
ResetAbandonedResources()

local function AnnounceAbandonedResources(client, resources)
	local debugMessage = string.format("%s abandoned %s resources.", TGNS.GetClientName(client), math.floor(resources))
	if math.floor(resources) > 0 then
		TGNS.SendAdminConsoles(debugMessage, "TEAMRESDEBUG")
	end
end

local function AbandonResources(client)
	if TGNS.IsGameInProgress() then
		local player = TGNS.GetPlayer(client)
		local playerTeamNumber = TGNS.GetPlayerTeamNumber(player)
		if TGNS.IsGameplayTeam(playerTeamNumber) then
			if abandonedResources[playerTeamNumber][client] == nil then
				local resources = TGNS.GetPlayerTotalCost(player)
				abandonedResources[playerTeamNumber][client] = resources
				TGNS.SetPlayerResources(player, 0)
				AnnounceAbandonedResources(client, resources)
				if resources > 100 then
					abandonedResources[playerTeamNumber][TGNS.GetClientSteamId(client) .. Shared.GetTime()] = resources - 100
					abandonedResources[playerTeamNumber][client] = 100
				end
			end
		end
	end
end

local function OnGameEnd()
	ResetAbandonedResources()
end
TGNS.RegisterEventHook("OnGameEnd", OnGameEnd)

local function AnnounceReceivedResources(player, resources)
	local message = string.format("%s got %s resources from a departed teammate.", TGNS.GetPlayerName(player), math.floor(resources))
	if math.floor(resources) > 0 then
		TGNS.SendChatMessage(player, message, "TEAMRES")
		TGNS.SendAdminConsoles(message, "TEAMRESDEBUG")
	end
end

local function DistributeAbandonedResources(client, teamNumber)
	local player = TGNS.GetPlayer(client)
	local playerTeamNumber = TGNS.GetPlayerTeamNumber(player)
	if TGNS.IsGameplayTeam(playerTeamNumber) and playerTeamNumber == teamNumber then
		local resKey
		local giveableResources
		if lastKnownGameplayTeamNumber[client] == teamNumber then
			resKey = client
			giveableResources = abandonedResources[playerTeamNumber][client]
		else
			TGNS.DoForPairs(abandonedResources[playerTeamNumber], function(key, resources)
				if resources ~= nil and (giveableResources == nil or resources > giveableResources) then
					giveableResources = resources
					resKey = key
				end
			end)
		end
		if giveableResources ~= nil then
			local originalResources = TGNS.GetPlayerResources(player)
			if math.floor(giveableResources) > math.floor(originalResources) then
				TGNS.SetPlayerResources(player, giveableResources)
				abandonedResources[playerTeamNumber][resKey] = math.floor(originalResources) > 0 and originalResources or nil
				AnnounceAbandonedResources(client, originalResources)
				AnnounceReceivedResources(player, giveableResources)
			end
		end
		lastKnownGameplayTeamNumber[client] = teamNumber
	end
end

local function CommunitySlotsOnTeamJoin(self, player, newTeamNumber, force)
	local cancel = false
	local joiningClient = TGNS.GetClient(player)
	local playerIsDroppingToReadyRoom = TGNS.IsGameplayTeam(TGNS.GetPlayerTeamNumber(player)) and newTeamNumber == kTeamReadyRoom
	local playerIsJoiningTeam = TGNS.IsGameplayTeam(newTeamNumber)
	if playerIsDroppingToReadyRoom then
		AbandonResources(joiningClient)
	elseif playerIsJoiningTeam then
		TGNS.ScheduleAction(2, function() DistributeAbandonedResources(joiningClient, newTeamNumber) end)
	end
	return cancel
end
TGNS.RegisterEventHook("OnTeamJoin", CommunitySlotsOnTeamJoin, TGNS.LOWEST_EVENT_HANDLER_PRIORITY)

local function ShowPlayerCosts(client)
	TGNS.DoFor(TGNS.GetPlayerList(), function(p)
		local name = TGNS.GetPlayerName(p)
		local className = TGNS.GetPlayerClassName(p)
		local classPurchaseCost = TGNS.GetPlayerClassPurchaseCost(p)
		local weaponsCost = TGNS.GetMarineWeaponsTotalPurchaseCost(p)
		TGNS.ConsolePrint(client, string.format("%s: %s worth %s with weapons worth %s", name, className, classPurchaseCost, weaponsCost), "COSTS")
	end)
end
TGNS.RegisterCommandHook("Console_sv_showcosts", ShowPlayerCosts, "Print costs of all players.")