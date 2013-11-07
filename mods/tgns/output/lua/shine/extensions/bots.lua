local PLAYER_COUNT_THRESHOLD = 10
local BOT_COUNT_THRESHOLD = 25
local originalEndRoundOnTeamUnbalanceSetting = 0.4
local originalForceEvenTeamsOnJoinSetting = true
local originalAutoTeamBalanceSetting = { enabled_after_seconds = 10, enabled_on_unbalance_amount = 2 }
local winOrLoseOccurredRecently
local md

local Plugin = {}

local function getTotalNumberOfBots()
	local result = #TGNS.Where(TGNS.GetClientList(), TGNS.GetIsClientVirtual)
	return result
end

local function getTotalNumberOfHumans()
	local result = #TGNS.Where(TGNS.GetClientList(), function(c) return not TGNS.GetIsClientVirtual(c) end)
	return result
end

local function setBotConfig()
	if not originalEndRoundOnTeamUnbalanceSetting then
		originalEndRoundOnTeamUnbalanceSetting = Server.GetConfigSetting("end_round_on_team_unbalance")
	end
	Server.SetConfigSetting("end_round_on_team_unbalance", 0)
	if not originalForceEvenTeamsOnJoinSetting then
		originalForceEvenTeamsOnJoinSetting = Server.GetConfigSetting("force_even_teams_on_join")
	end
	Server.SetConfigSetting("force_even_teams_on_join", false)
	if not originalAutoTeamBalanceSetting then
		originalAutoTeamBalanceSetting = Server.GetConfigSetting("auto_team_balance")
	end
	Server.SetConfigSetting("auto_team_balance", {enabled_after_seconds=0, enabled_on_unbalance_amount=0})
end

local function setOriginalConfig()
	if originalEndRoundOnTeamUnbalanceSetting then
		Server.SetConfigSetting("end_round_on_team_unbalance", originalEndRoundOnTeamUnbalanceSetting)
	end
	if originalForceEvenTeamsOnJoinSetting then
		Server.SetConfigSetting("force_even_teams_on_join", originalForceEvenTeamsOnJoinSetting)
	end
	if originalAutoTeamBalanceSetting then
		Server.SetConfigSetting("auto_team_balance", originalAutoTeamBalanceSetting)
	end
end

local function removeBots(players, count)
	local botClients = TGNS.GetMatchingClients(players, TGNS.GetIsClientVirtual)
	TGNS.DoFor(botClients, function(c, index)
		if count == nil or index <= count then
			TGNSClientKicker.Kick(c, "Managed bot removal.", nil, nil, false)
		end
	end)
end

function Plugin:ClientConnect(client)
	if getTotalNumberOfBots() > 0 and not TGNS.GetIsClientVirtual(client) and getTotalNumberOfHumans() >= PLAYER_COUNT_THRESHOLD and TGNS.IsGameInProgress() and not winOrLoseOccurredRecently then
		md:ToAllNotifyInfo(string.format("Server has seeded to %s players. Bots surrender!", PLAYER_COUNT_THRESHOLD))
		Shine.Plugins.winorlose:CallWinOrLose(kAlienTeamType)
		winOrLoseOccurredRecently = true
		TGNS.ScheduleAction(65, function() winOrLoseOccurredRecently = false end)
	end
end

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
	if not (force or shineForce) then
		if getTotalNumberOfBots() > 0 and TGNS.IsGameplayTeamNumber(newTeamNumber) and not TGNS.GetIsClientVirtual(client) and not force then
			md:ToPlayerNotifyInfo(player, string.format("Everyone plays Marines against bots until the server seeds to %s players.", PLAYER_COUNT_THRESHOLD))
			if newTeamNumber ~= kMarineTeamType then
				return false
			end
		end
	end
end

function Plugin:EndGame(gamerules, winningTeam)
	TGNS.ScheduleAction(2, function()
		removeBots(TGNS.GetPlayerList())
	end)
	setOriginalConfig()
end

function Plugin:CreateCommands()
	local botsCommand = self:BindCommand( "sh_bots", "bots", function(client, countModifier)
		countModifier = tonumber(countModifier)
		local errorMessage
		local players = TGNS.GetPlayerList()
		if countModifier then
			if getTotalNumberOfBots() == 0 then
				local atLeastOnePlayerIsOnGameplayTeam = #TGNS.GetAlienClients(players) + #TGNS.GetMarineClients(players) > 0
				if #players >= PLAYER_COUNT_THRESHOLD then
					errorMessage = string.format("Bots are used only for seeding the server to %s players.", PLAYER_COUNT_THRESHOLD)
				elseif atLeastOnePlayerIsOnGameplayTeam then
					errorMessage = "All players must be in the ReadyRoom before adding initial bots."
				elseif Shine.Plugins.mapvote:VoteStarted() then
					errorMessage = "Bots cannot be managed during a map vote."
				elseif Shine.Plugins.captains and Shine.Plugins.captains:IsCaptainsModeEnabled() then
					errorMessage = "Bots cannot be managed during a Captains Game."
				end
			end
		else
			errorMessage = "Specify a positive or negative bot count modifier."
		end
		if TGNS.HasNonEmptyValue(errorMessage) then
			md:ToPlayerNotifyError(TGNS.GetPlayer(client), errorMessage)
		else
			local proposedTotalCount = getTotalNumberOfBots() + countModifier
			countModifier = proposedTotalCount <= BOT_COUNT_THRESHOLD and countModifier or (countModifier - (proposedTotalCount - BOT_COUNT_THRESHOLD))
			if countModifier > 0 then
				setBotConfig()
				local command = string.format("addbot %s %s", countModifier, kAlienTeamType)
				TGNS.ExecuteServerCommand(command)
				if not TGNS.IsGameInProgress() then
					local humanPlayers = TGNS.Where(players, function(p)
						local client = TGNS.GetClient(p)
						return not TGNS.GetIsClientVirtual(client)
					end)
					TGNS.DoFor(humanPlayers, function(p)
						TGNS.SendToTeam(p, kMarineTeamType, true)
					end)
					Shine.Plugins.forceroundstart:ForceRoundStart()
				end
			else
				removeBots(players, math.abs(countModifier))
			end
		end
	end)
	botsCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	botsCommand:Help( "<countModifier> +/- the count of alien bots." )

	local botsMaxCommand = self:BindCommand( "sh_botsmax", "botsmax", function(client, maxCandidate)
		local player = TGNS.GetPlayer(client)
		local max = tonumber(maxCandidate)
		if max <= 0 then
			md:ToPlayerNotifyError(player, "Bots maximum must be a positive number.")
		else
			BOT_COUNT_THRESHOLD = max
			local excessBotCount = getTotalNumberOfBots() - BOT_COUNT_THRESHOLD
			if excessBotCount > 0 then
				removeBots(TGNS.GetPlayerList(), excessBotCount)
			end
			md:ToPlayerNotifyInfo(player, string.format("Maximum possible bots set to %s.", max))
		end
	end)
	botsMaxCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	botsMaxCommand:Help( "<max> Set the maximum possible count of bots." )
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("BOTS")
	TGNS.ScheduleAction(10, setOriginalConfig)
	self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("bots", Plugin )