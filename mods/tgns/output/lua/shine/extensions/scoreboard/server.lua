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
			local sourceSteamId = TGNS.GetClientSteamId(client)
			table.insert(clientsReadyForScoreboardData, client)
			local sourcePlayer = TGNS.GetPlayer(client)
			if sourcePlayer then
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
	local md = TGNSMessageDisplayer.Create("AFFIRM")
	TGNS.HookNetworkMessage(self.APPROVE_REQUESTED, function(client, message)
		local player = TGNS.GetPlayer(client)
		local targetClientIndex = message.c
		if startTimeSeconds ~= nil then
			local targetClient = Shine.GetClientByID(targetClientIndex)
			if targetClient then
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
											approveReceivedTotal[targetClient] = TGNS.GetNumericValueOrZero(approveReceivedTotal[targetClient])
											approveReceivedTotal[targetClient] = approveReceivedTotal[targetClient] + 1
											TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(targetClient), self.APPROVE_RECEIVED_TOTAL, {t=approveReceivedTotal[targetClient]})
										end
									end
								else
									if approveResponse.msg == "Too many recent approvals for this player." then
										md:ToPlayerNotifyError(player, string.format("You must affirm some other players before %s.", targetClientName))
										TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
									elseif approveResponse.msg == "Too many recent approvals." then
										md:ToPlayerNotifyError(player, "You have affirmed too many players in the last 24 hours.")
										TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
									else
										TGNS.DebugPrint(string.format("scoreboard ERROR: Unable to affirm NS2ID %s. msg: %s | response: %s | stacktrace: %s", targetSteamId, approveResponse.msg, approveResponseJson, approveResponse.stacktrace))
										if approvedClients[sourceSteamId][targetSteamId] == nil then
											md:ToPlayerNotifyError(player, string.format("There was a problem affirming %s.", targetClientName))
											TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
										end
									end
								end
							end)
						else
							md:ToPlayerNotifyError(player, string.format("You may affirm %s only once per game.", targetClientName))
						end
					else
						md:ToPlayerNotifyError(player, "Don't encourage the bots.")
					end
				else
					md:ToPlayerNotifyError(player, "Your modesty knows no bounds.")
				end
			else
				md:ToPlayerNotifyError(player, "There was a problem affirming.")
				TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
			end
		else
			md:ToPlayerNotifyError(player, "You may affirm only after a game has started.")
			TGNS.SendNetworkMessageToPlayer(player, self.APPROVE_MAY_TRY_AGAIN, {c=targetClientIndex})
		end
	end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end