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
			result = result .. Shine.Plugins.scoreboard.Config.AFK
		end
		if Shine.Plugins.betterknownas and Shine.Plugins.betterknownas.Enabled and Shine.Plugins.betterknownas.IsPlayingWithoutBkaName and Shine.Plugins.betterknownas:IsPlayingWithoutBkaName(sourcePlayer) then
			result = "*" .. result
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
			table.insert(clientsReadyForScoreboardData, client)
			local player = TGNS.GetPlayer(client)
			UpdatePlayerPrefixes(player)
			self:AnnouncePlayerPrefix(player)
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
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end