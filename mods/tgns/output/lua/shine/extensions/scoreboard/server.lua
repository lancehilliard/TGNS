local approvedClients = {}
local changers = {}
local clientsReadyForScoreboardData = {}

local function PlayerCanSeeAfkStatus(sourcePlayer, targetPlayer)
	local result = false
	if sourcePlayer ~= nil and targetPlayer ~= nil then
	end
		local sendToPlayerCanKickAfkPlayers = TGNS.ClientAction(targetPlayer, function(c)
				local playerIsAdmin = TGNS.IsClientAdmin(c)
				local playerIsGuardian = TGNS.IsClientGuardian(c)
				return playerIsAdmin or playerIsGuardian
			end
		)
		local sameTeams = TGNS.PlayersAreTeammates(sourcePlayer, targetPlayer)
		result = sameTeams or sendToPlayerCanKickAfkPlayers
	return result
end

local function GetPlayerPrefix(sourcePlayer, targetPlayer)
	local result = ""

	local client = TGNS.GetClient(sourcePlayer)
	if client then
		local groupIcons = Shine.Plugins.scoreboard.Config.GroupIcons
		table.sort(groupIcons, function(t1, t2) return t1.sort < t2.sort end)
		for _, groupicon in ipairs(groupIcons) do
			if TGNS.ClientIsInGroup(client, groupicon.group) then
				result = groupicon.icon
				break
			end
		end
		if result == nil then
			result = Shine.Plugins.scoreboard.Config.CatchAll
		end
		if TGNS.IsPlayerAFK(sourcePlayer) and PlayerCanSeeAfkStatus(sourcePlayer, targetPlayer) then
			result = Shine.Plugins.scoreboard.Config.AFK .. result
		end
		if Shine.Plugins.betterknownas and Shine.Plugins.betterknownas.Enabled and Shine.Plugins.betterknownas.IsPlayingWithoutBkaName and Shine.Plugins.betterknownas:IsPlayingWithoutBkaName(sourcePlayer) then
			result = result .. "*"
		end
	end
	return result
end

local function GetReadyPlayerList()
	local result = TGNS.GetPlayers(TGNS.Where(TGNS.GetClientList(), function(c) return TGNS.Has(clientsReadyForScoreboardData, c) end))
	return result
end

local function SendNetworkMessage(sourcePlayer, targetPlayer)
	TGNS.SendNetworkMessageToPlayer(targetPlayer, Shine.Plugins.scoreboard.SCOREBOARD_DATA, {i=sourcePlayer:GetClientIndex(), p=GetPlayerPrefix(sourcePlayer, targetPlayer), c=TGNS.ClientIsInGroup(TGNS.GetClient(sourcePlayer), "captains_group")})
end

function Plugin:AnnouncePlayerPrefix(player)
	TGNS.DoFor(GetReadyPlayerList(), function(p)
		SendNetworkMessage(player, p)
	end)
end

local function UpdatePlayerPrefixes(player)
	TGNS.DoFor(GetReadyPlayerList(), function(p)
		SendNetworkMessage(p, player)
	end)
end

function Plugin:ClientConfirmConnect(client)
	TGNS.ScheduleAction(1, function()
		if Shine:IsValidClient(client) then
			local sourcePlayer = TGNS.GetPlayer(client)
			local sourceSteamId = TGNS.GetClientSteamId(client)
			table.insert(clientsReadyForScoreboardData, client)
			if sourcePlayer then
				TGNS.SendNetworkMessageToPlayer(sourcePlayer, self.TOGGLE_OPTIONALS, {t=not TGNS.IsClientStranger(client)})
				UpdatePlayerPrefixes(sourcePlayer)
				self:AnnouncePlayerPrefix(sourcePlayer)
				local approvedSentTotal = 0
				local approvedReceivedTotal = 0
				TGNS.DoFor(TGNS.GetClientList(), function(c)
					if c then
						local targetSteamId = TGNS.GetClientSteamId(c)
						approvedClients[targetSteamId] = approvedClients[targetSteamId] or {}
						if approvedClients[targetSteamId][sourceSteamId] then
							TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(c), self.APPROVE_ALREADY_APPROVED, {c=sourcePlayer:GetClientIndex()})
							approvedReceivedTotal = approvedReceivedTotal + 1
						end
						approvedClients[sourceSteamId] = approvedClients[sourceSteamId] or {}
						if approvedClients[sourceSteamId][targetSteamId] then
							local targetPlayer = TGNS.GetPlayer(c)
							TGNS.SendNetworkMessageToPlayer(sourcePlayer, self.APPROVE_ALREADY_APPROVED, {c=targetPlayer:GetClientIndex()})
							approvedSentTotal = approvedSentTotal + 1
						end
					end
				end)
				TGNS.SendNetworkMessageToPlayer(sourcePlayer, self.APPROVE_RECEIVED_TOTAL, {t=approvedReceivedTotal})
				TGNS.SendNetworkMessageToPlayer(sourcePlayer, self.APPROVE_SENT_TOTAL, {t=approvedSentTotal})
			end
		end
	end)
end

function Plugin:PlayerNameChange(player, newName, oldName)
	self:AnnouncePlayerPrefix(player)
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("AfkChanged", function(player, playerIsAfk)
		self:AnnouncePlayerPrefix(player)
	end)
	TGNS.RegisterEventHook("ClientGroupsChanged", function(client)
		self:AnnouncePlayerPrefix(TGNS.GetPlayer(client))
	end)
	TGNS.RegisterEventHook("BkaChanged", function(client)
		self:AnnouncePlayerPrefix(TGNS.GetPlayer(client))
	end)
	local startTimeSeconds
	approvedClients = {}
	local approveReceivedTotal = {}
	local approveSentTotal = {}
	TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
		startTimeSeconds = secondsSinceEpoch
		approvedClients = {}
		approveSentTotal = {}
		approveReceivedTotal = {}
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			TGNS.SendNetworkMessageToPlayer(p, self.APPROVE_RESET, {})
			TGNS.SendNetworkMessageToPlayer(p, self.APPROVE_RECEIVED_TOTAL, {t=0})
			TGNS.SendNetworkMessageToPlayer(p, self.APPROVE_SENT_TOTAL, {t=0})
		end)
	end)
	TGNS.HookNetworkMessage(self.APPROVE_REQUESTED, function(client, message)
		local md = TGNSMessageDisplayer.Create("APPROVE")
		local player = TGNS.GetPlayer(client)
		local targetClientIndex = message.c
		if startTimeSeconds ~= nil then
			local targetClient = TGNS.GetClientById(targetClientIndex)
			if targetClient and Shine:IsValidClient(targetClient) then
				if client ~= targetClient then
					if not TGNS.GetIsClientVirtual(targetClient) then
						local sourceSteamId = TGNS.GetClientSteamId(client)
						local targetSteamId = TGNS.GetClientSteamId(targetClient)
						local targetClientName = TGNS.GetClientName(targetClient)
						approvedClients[sourceSteamId] = approvedClients[sourceSteamId] or {}
						if approvedClients[sourceSteamId][targetSteamId] == nil then
							local approveUrl = string.format("%s&i=%s&a=%s&s=%s&t=%s", TGNS.Config.ApproveEndpointBaseUrl, sourceSteamId, targetSteamId, TGNS.GetSimpleServerName(), startTimeSeconds)
							TGNS.GetHttpAsync(approveUrl, function(approveResponseJson)
								local approveResponse = json.decode(approveResponseJson) or {}
								if approveResponse.success then
									if Shine:IsValidClient(client) then
										approvedClients[sourceSteamId][targetSteamId] = true
										approveSentTotal[sourceSteamId] = TGNS.GetNumericValueOrZero(approveSentTotal[sourceSteamId])
										approveSentTotal[sourceSteamId] = approveSentTotal[sourceSteamId] + 1
										TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_SENT_TOTAL, {t=approveSentTotal[sourceSteamId]})
										if Shine:IsValidClient(targetClient) then
											if TGNS.IsClientStranger(targetClient) and Shine.Plugins.targetedcommands and Shine.Plugins.targetedcommands.Enabled and Shine.Plugins.targetedcommands.Affirm then
												Shine.Plugins.targetedcommands:Affirm(client, targetClient, md)
											end
											approveReceivedTotal[targetSteamId] = TGNS.GetNumericValueOrZero(approveReceivedTotal[targetSteamId])
											approveReceivedTotal[targetSteamId] = approveReceivedTotal[targetSteamId] + 1
											TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(targetClient), self.APPROVE_RECEIVED_TOTAL, {t=approveReceivedTotal[targetSteamId]})
										end
									end
								else
									if approveResponse.msg == "Too many recent approvals for this player." then
										md:ToPlayerNotifyError(player, string.format("You must Approve some other players before %s.", targetClientName))
										TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
									elseif approveResponse.msg == "Too many recent approvals." then
										md:ToPlayerNotifyError(player, "You have Approved too many players in the last 24 hours.")
										TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
									else
										TGNS.DebugPrint(string.format("scoreboard ERROR: Unable to approve NS2ID %s. msg: %s | response: %s | stacktrace: %s", targetSteamId, approveResponse.msg, approveResponseJson, approveResponse.stacktrace))
										if approvedClients[sourceSteamId][targetSteamId] == nil then
											md:ToPlayerNotifyError(player, string.format("There was a problem approving %s.", targetClientName))
											TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
										end
									end
								end
							end)
						else
							md:ToPlayerNotifyError(player, string.format("You may Approve %s only once per game.", targetClientName))
						end
					else
						md:ToPlayerNotifyError(player, "Don't encourage the bots.")
					end
				else
					md:ToPlayerNotifyError(player, "Your modesty knows no bounds.")
				end
			else
				md:ToPlayerNotifyError(player, "There was a problem approving.")
				TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
			end
		else
			md:ToPlayerNotifyError(player, "You may Approve only after a game has started.")
			TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
		end
	end)
	TGNS.HookNetworkMessage(self.QUERY_REQUESTED, function(client, message)
		local player = TGNS.GetPlayer(client)
		local targetClientIndex = message.c
		local targetClient = TGNS.GetClientById(targetClientIndex)
		local md = TGNSMessageDisplayer.Create("QUERY")
		if targetClient and Shine:IsValidClient(targetClient) then
			--if client ~= targetClient then
				--if not TGNS.GetIsClientVirtual(targetClient) then
					TGNS.ScheduleAction(5, function()
						if Shine:IsValidClient(client) then
							TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), self.QUERY_ALLOWED, {c=targetClientIndex})
						end
					end)
					local sourceSteamId = TGNS.GetClientSteamId(client)
					local targetSteamId = TGNS.GetClientSteamId(targetClient)
					local targetClientName = TGNS.GetClientName(targetClient)
					Shine.Plugins.betterknownas:ShowCurrentBka(client, targetSteamId, "BKA", "AKAs", "BKA")
					if Balance then
						local totalGamesCount = Balance.GetTotalGamesPlayedBySteamId(targetSteamId)
						if totalGamesCount > 0 and totalGamesCount < 50 then
							local targetPlayer = TGNS.GetPlayer(targetClient)
							md:ToPlayerNotifyInfo(player, string.format("%s has played %s games so far on TGNS.", targetClientName, totalGamesCount))
						end
					end
				--else
					--md:ToPlayerNotifyError(player, "The bots don't take kindly to being queried.")
				--end
			--else
			--	md:ToPlayerNotifyError(player, "You know all there is to know about yourself.")
			--end
		else
			md:ToPlayerNotifyError(player, "There was a problem querying.")
		end
	end)
	TGNS.HookNetworkMessage(self.BADGE_QUERY_REQUESTED, function(client, message)
		Shared.Message(tostring(targetClientIndex))
		local player = TGNS.GetPlayer(client)
		local targetClientIndex = message.c
		local targetClient = TGNS.GetClientById(targetClientIndex)
		local md = TGNSMessageDisplayer.Create("BADGES")
		if targetClient and Shine:IsValidClient(targetClient) then
			if not TGNS.GetIsClientVirtual(targetClient) then
				local sourceSteamId = TGNS.GetClientSteamId(client)
				local targetSteamId = TGNS.GetClientSteamId(targetClient)
				local targetClientName = TGNS.GetClientName(targetClient)
				local badgeInfo = Shine.Plugins.tgnsbadges:GetCurrentBadgeInfo(targetSteamId)
				if badgeInfo then
					md = TGNSMessageDisplayer.Create("BADGES")
					md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), string.format("%s: %s - %s", targetClientName, badgeInfo.DisplayName, badgeInfo.Description))
				end
				TGNS.ScheduleAction(5, function()
					if Shine:IsValidClient(client) then
						TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), self.BADGE_QUERY_ALLOWED, {c=targetClientIndex})
					end
				end)
			else
				md:ToPlayerNotifyError(player, "The bots don't take kindly to being queried.")
			end
		else
			md:ToPlayerNotifyError(player, "There was a problem querying.")
		end
	end)
	TGNS.RegisterEventHook("LookDownChanged", function(player, isLookingDown)
		local isLookingUp = not isLookingDown
		TGNS.SendNetworkMessageToPlayer(player, self.TOGGLE_CUSTOM_NUMBERS_COLUMN, {t=isLookingUp})
	end)
 	TGNS.RegisterEventHook("PlayerLocationChanged", function(player, locationName)
		TGNS.DoFor(TGNS.GetPlayerList(), function(p)
			local locationNameToSend = (TGNS.IsPlayerSpectator(p) or TGNS.PlayersAreTeammates(player, p)) and TGNS.Truncate(locationName, 4) or ""
			TGNS.SendNetworkMessageToPlayer(p, self.LOCATION_CHANGED, {c=player:GetClientIndex(), n=locationNameToSend})
		end)
 	end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end