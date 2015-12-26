TGNSConnectedTimesTracker = {}

local DISCONNECTED_TIME_ALLOWED_IN_SECONDS = 300
local TRACKING_INTERVAL_IN_SECONDS = 30
local DATA_BACKEND_UPDATE_INTERVAL_IN_SECONDS = 60
local connectedTimes = {}
local played = {}
local lastUpdatedTimes = {}

local pdr = TGNSPlayerDataRepository.Create("connectedtimes", function(data)
	data.when = data.when ~= nil and data.when or nil
	data.lastSeen = data.lastSeen ~= nil and data.lastSeen or nil
	data.played = data.played ~= nil and data.played or nil
	return data
end)

function TGNSConnectedTimesTracker.AddToPlayTime(client, secondsToAddToPlayed)
	local steamId = TGNS.GetClientSteamId(client)
	played[steamId] = (played[steamId] or 0) + secondsToAddToPlayed
end

function TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	local result = connectedTimes[steamId] or 0
	return result
end

function TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(client)
	local steamId = TGNS.GetClientSteamId(client)
	local result = played[steamId] or 0
	return result
end

local function GetHumanClients()
	local result = TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.GetIsClientVirtual(c) end)
	return result
end

function TGNSConnectedTimesTracker.PrintConnectedDurations(client)
	local humanClients = GetHumanClients()
	TGNS.SortDescending(humanClients, TGNSConnectedTimesTracker.GetPlayedTimeInSeconds)
	local humanStrangers = TGNS.Where(humanClients, TGNS.IsClientStranger)
	local humanPrimerOnlys = TGNS.Where(humanClients, TGNS.IsPrimerOnlyClient)
	local humanSupportingMembers = TGNS.Where(humanClients, TGNS.IsClientSM)
	local md = TGNSMessageDisplayer.Create("CONNECTEDTIMES")
	local printConnectedTime = function(c)
		local connectedTimeInSeconds = TGNSConnectedTimesTracker.GetClientConnectedTimeInSeconds(c)
		local playedTimeInSeconds = TGNSConnectedTimesTracker.GetPlayedTimeInSeconds(c)
		local gamesCount = Balance and Balance.GetTotalGamesPlayed and Balance.GetTotalGamesPlayed(c) or "?"
		md:ToClientConsole(client, string.format("%s%s> %s: %s/%s %s", TGNS.IsPlayerAFK(TGNS.GetPlayer(c)) and "!" or "", TGNS.GetClientCommunityDesignationCharacter(c), TGNS.GetClientName(c), TGNS.SecondsToClock(Shared.GetSystemTime() - connectedTimeInSeconds), TGNS.SecondsToClock(playedTimeInSeconds), string.format("(games: %s%s)", gamesCount, TGNS.IsClientCommander(c) and "; Commander" or "")))
	end
	TGNS.DoFor(humanStrangers, printConnectedTime)
	TGNS.DoFor(humanPrimerOnlys, printConnectedTime)
	TGNS.DoFor(humanSupportingMembers, printConnectedTime)
end

TGNS.ScheduleActionInterval(TRACKING_INTERVAL_IN_SECONDS, function()
	local gameIsHumansOnly = Shine.Plugins.bots:GetTotalNumberOfBots() == 0
	TGNS.DoFor(GetHumanClients(), function(client)
		local steamId = TGNS.GetClientSteamId(client)
		local clientIsInGame = TGNS.IsGameInProgress() and TGNS.ClientIsOnPlayingTeam(client)
		local secondsToAddToPlayed = (clientIsInGame and gameIsHumansOnly) and TRACKING_INTERVAL_IN_SECONDS or 0
		connectedTimes[steamId] = connectedTimes[steamId] or Shared.GetSystemTime()
		played[steamId] = (played[steamId] or 0) + secondsToAddToPlayed
		if (Shared.GetTime() - (lastUpdatedTimes[steamId] or 0) > DATA_BACKEND_UPDATE_INTERVAL_IN_SECONDS) then
			pdr:Load(steamId, function(loadResponse)
				if loadResponse.success then
					local data = loadResponse.value
					local tooLongHasPassedSinceLastSeen = data.lastSeen == nil or (Shared.GetSystemTime() - data.lastSeen > DISCONNECTED_TIME_ALLOWED_IN_SECONDS)
					local noExistingConnectionTimeIsOnRecord = data.when == nil
					local tooLongOrNoExisting = tooLongHasPassedSinceLastSeen or noExistingConnectionTimeIsOnRecord
					if tooLongOrNoExisting then
						data.when = Shared.GetSystemTime()
						data.played = 0
					end
					data.played = data.played or 0
					played[steamId] = played[steamId] or 0
					data.played = data.played > played[steamId] and data.played or played[steamId]
					data.lastSeen = Shared.GetSystemTime()
					pdr:Save(data, function(saveResponse)
						if not saveResponse.success then
							Shared.Message("ConnectedTimesTracker ERROR: unable to save data")
						end
					end)
					connectedTimes[steamId] = data.when
					played[steamId] = data.played
				else
					Shared.Message("ConnectedTimesTracker ERROR: unable to access data")
				end
			end)
			lastUpdatedTimes[steamId] = Shared.GetTime()
		end
	end)
end)

-- TGNS.RegisterEventHook("OnClientDisconnect", function(client)
-- 	local steamId = TGNS.GetClientSteamId(client)
-- 	connectedTimes[steamId] = 0
-- 	played[steamId] = 0
-- end)