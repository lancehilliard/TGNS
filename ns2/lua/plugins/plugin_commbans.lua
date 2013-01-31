//NS2 Commander bans

local CommBans = { }
local CommBansFileName = "config://CommBans.json"

local function LoadCommanderBannedPlayers()

	Shared.Message("Loading " .. CommBansFileName)
	
	CommBans = { }
	
	// Load the ban settings from file if the file exists.
	local CommBansFile = io.open(CommBansFileName, "r")
	if CommBansFile then
		CommBans = json.decode(CommBansFile:read("*all")) or { }
		CommBansFile:close()
	end
	
end

LoadCommanderBannedPlayers()

local function SaveCommanderBannedPlayers()

	local CommBansFile = io.open(CommBansFileName, "w+")
	if CommBansFile then
		CommBansFile:write(json.encode(CommBans))
		CommBansFile:close()
	end
	
end

local function GetPlayerList()

	local playerList = EntityListToTable(Shared.GetEntitiesWithClassname("Player"))
	table.sort(playerList, function(p1, p2) return p1:GetName() < p2:GetName() end)
	return playerList
	
end

local function AllPlayers(doThis)

	return function(client)
	
		local playerList = GetPlayerList()
		for p = 1, #playerList do
		
			local player = playerList[p]
			doThis(player, client, p)
			
		end
		
	end
	
end

local function GetPlayerMatchingSteamId(steamId)

	assert(type(steamId) == "number")
	
	local match = nil
	
	local function Matches(player)
	
		local playerClient = Server.GetOwner(player)
		if playerClient and playerClient:GetUserId() == steamId then
			match = player
		end
		
	end
	AllPlayers(Matches)()
	
	return match
	
end

local function GetPlayerMatchingName(name)

	assert(type(name) == "string")
	
	local match = nil
	
	local function Matches(player)
	
		if player:GetName() == name then
			match = player
		end
		
	end
	AllPlayers(Matches)()
	
	return match
	
end

local function GetPlayerMatching(id)

	local idNum = tonumber(id)
	if idNum then
		return GetPlayerMatchingGameId(idNum) or GetPlayerMatchingSteamId(idNum)
	elseif type(id) == "string" then
		return GetPlayerMatchingName(id)
	end
		
end

if kDAKConfig and kDAKConfig.DAKLoader and kDAKConfig.DAKLoader.GamerulesExtensions then

	local originalNS2GRGetPlayerBannedFromCommand
	
	originalNS2GRGetPlayerBannedFromCommand = Class_ReplaceMethod(kDAKConfig.DAKLoader.GamerulesClassName, "GetPlayerBannedFromCommand", 
		function(self, playerId)

			local banned = false //Innocent until proven guilty
			banned = originalNS2GRGetPlayerBannedFromCommand( self, playerId )
			
			for b = #CommBans, 1, -1 do
				local cban = CommBans[b]
				if cban.id == playerId then
					// Check if enough time has passed on a temporary comm ban.
					local now = Shared.GetSystemTime()
					if cban.time == 0 or now < cban.time then
						banned = true
					else
						// No longer banned.
						LoadCommanderBannedPlayers()
						table.remove(CommBans, b)
						SaveCommanderBannedPlayers()
					end
				end
			end
			return banned
		end
	)
	
end

local function DelayedVoteManagerOverride()	
	if VoteManager ~= nil then
		//UpdateVoteManagerFields
		VoteManager.kMinVotesNeeded = kDAKConfig.CommBans.kMinVotesNeeded
		VoteManager.kTeamVotePercentage = kDAKConfig.CommBans.kTeamVotePercentage
	end
	DAKDeregisterEventHook("kDAKOnServerUpdate", DelayedVoteManagerOverride)
end

DAKRegisterEventHook("kDAKOnServerUpdate", DelayedVoteManagerOverride, 5)

function CommBansCastVoteByPlayer(self, voteTechId, player)
	local commanders = GetEntitiesForTeam("Commander", player:GetTeamNumber())
	if table.count(commanders) >= 1 then
		local targetCommander = commanders[1]
		if targetCommander ~= nil then
			local client = Server.GetOwner(targetCommander)
			if client ~= nil then
				if not DAKGetLevelSufficient(client, playerId) and DAKGetClientCanRunCommand(client, "sv_ejectionprotection") then
					return true
				end
			end
		end
	end
end

DAKRegisterEventHook("kDAKOnCastVoteByPlayer", CommBansCastVoteByPlayer, 5)

local function OnCommandCommBan(client, playerId, duration, ...)

	local player = GetPlayerMatching(playerId)
	local bannedUntilTime = Shared.GetSystemTime()
	duration = tonumber(duration)
	if duration == nil or duration <= 0 then
		bannedUntilTime = 0
	else
		bannedUntilTime = bannedUntilTime + (duration * 60)
	end
	if not DAKGetLevelSufficient(client, playerId) then
		return
	end
	if player then
	
		LoadCommanderBannedPlayers()
		table.insert(CommBans, { name = player:GetName(), id = Server.GetOwner(player):GetUserId(), reason = StringConcatArgs(...), time = bannedUntilTime })
		SaveCommanderBannedPlayers()
		ServerAdminPrint(client, player:GetName() .. " has been banned from the command chair")
		
	elseif tonumber(playerId) > 0 then
	
		LoadCommanderBannedPlayers()
		table.insert(CommBans, { name = "Unknown", id = tonumber(playerId), reason = StringConcatArgs(...), time = bannedUntilTime })
		SaveCommanderBannedPlayers()
		ServerAdminPrint(client, "Player with SteamId " .. playerId .. " has been banned from the command chair")
		
	else
		ServerAdminPrint(client, "No matching player")
	end
	
end

DAKCreateServerAdminCommand("Console_sv_commban", OnCommandCommBan, "<player id> <duration in minutes> <reason text>, Bans the player from commanding, pass in 0 for duration to ban forever")

local function OnCommandUnCommBan(client, steamId)

	local found = false
	LoadCommanderBannedPlayers()
	for p = #CommBans, 1, -1 do
	
		if CommBans[p].id == steamId then
		
			table.remove(CommBans, p)
			ServerAdminPrint(client, "Removed " .. steamId .. " from the commander ban list")
			found = true
			
		end
		
	end
	
	if found then
		SaveCommanderBannedPlayers()
	else
		ServerAdminPrint(client, "No matching Steam Id in commander ban list")
	end
	
end

DAKCreateServerAdminCommand("Console_sv_uncommban", OnCommandUnCommBan, "<steam id>, Removes the player matching the passed in Steam Id from the commander ban list")

function GetCommBannedPlayersList()

	local returnList = { }
	
	for p = 1, #CommBans do
	
		local cban = CommBans[p]
		table.insert(returnList, { name = cban.name, id = cban.id, reason = cban.reason, time = cban.time })
		
	end
	
	return returnList
	
end

local function ListCommanderBans(client)

	if #CommBans == 0 then
		ServerAdminPrint(client, "No players are currently commander banned")
	end
	
	for p = 1, #CommBans do
	
		local cban = CommBans[p]
		local timeLeft = cban.time == 0 and "Forever" or (((cban.time - Shared.GetSystemTime()) / 60) .. " minutes")
		ServerAdminPrint(client, "Name: " .. cban.name .. " Id: " .. cban.id .. " Time Remaining: " .. timeLeft .. " Reason: " .. (cban.reason or "Not provided"))
		
	end
	
end

DAKCreateServerAdminCommand("Console_sv_listcommbans", ListCommanderBans, "Lists the commander banned players")