local Plugin = {}

Plugin.Version = "1.0"
Plugin.HasConfig = true

Plugin.Conflicts = {
	DisableThem = "afkkick"
}


Plugin.DefaultConfig = {
        MinPlayers = 10,
		IgnoreAllSpectators = false,
		IgnorePrimerSpectators = false,
		IgnoreSMSpectators = false,
		ConsiderAFKTime = 60, -- Time when AfkChanged is executed
		KickTime = 180, -- Time in seconds
		WarnTimes = {
			90,	45,	20,	10, 5, 4, 3, 2,	1
		}
}

Plugin.CheckConfig = true

local md
--- Last time of action, last known direction,
-- and whether this player has been warned. Each
-- index is a client containing a list, which will
-- contain, at most:
-- IsAFK 	 - If AfkChanged was called on this client
-- LastMove  - From a call to TGNS.GetSecondsSinceServerProcessStarted()
-- LastWarn  - A time, in seconds, that the player was last warned at 
--			  (e.g 45 would be 45 seconds of not moving) (nil if (s)he hasn't been warned since (s)he last moved)
-- LastPitch - Last pitch we've seen from this player
-- LastYaw   - Last yaw 
local LastActionTimes = {} 
local PlayerAFK = {} -- this name is too general to put on the global namespace

--- Resets the afk timer on the specified client, also making sure
-- that it is inited
-- @param Client a client
-- @return false if the client's afk timer was not set, true otherwise
function PlayerAFK:ResetAFKTimer( Client )
	if not Client then return false end
	if not Client.GetIsVirtual then 
		print("Called with something that isn't a client:")
		require 'pl.pretty'.dump(Client) 
	end
	if Client:GetIsVirtual() then return false end
	LastActionTimes[Client] = LastActionTimes[Client] or {}
	LastActionTimes[Client].LastMove = TGNS.GetSecondsSinceServerProcessStarted()
	LastActionTimes[Client].LastWarn = nil
	if LastActionTimes[Client].IsAfk then
		TGNS.ExecuteEventHooks("AfkChanged", Player, false)
	end
	LastActionTimes[Client].IsAfk = false
	return true
end

function PlayerAFK:TimeAFK( Client )
	if not LastActionTimes[Client] then 
		PlayerAFK:ResetAFKTimer( Client )
		return 0
	end	
	return TGNS.GetSecondsSinceServerProcessStarted() - LastActionTimes[Client].LastMove
end

function PlayerAFK:IsAFKFor( Client, TimeSeconds )
	if not LastActionTimes[Client] then return false end
	return self:TimeAFK() >= TimeSeconds
end

function PlayerAFK:HasBeenWarned( Client )
	if not LastActionTimes[Client] then return false end
	return LastActionTimes[Client].LastWarn ~= nil
end

--- Decides if a client is immune to AFK-Kick actions.
-- @param Player the player that controls the client
-- @param Client the client to check
function PlayerAFK:IsImmune( Player, Client )
	if Client:GetIsVirtual() then return true end
	
	if not Player then return true end
	
	local TeamNum = TGNS.GetPlayerTeamNumber( Player )
	if TeamNum == kSpectatorIndex and (
			self.Config.IgnoreAllSpecators or
			(self.Config.IgnorePrimerSpectators and TGNS.IsPrimerOnlyClient( Client )) or
			(self.Config.IgnoreSMSpectators and TGNS.IsClientSM( Client ))
		) then return true end
	
	return false
end

--- Takes the necessary action against the Client if necessary
-- @param Client the client to perform an action against
-- @return if any action was taken
function PlayerAFK:PerformActionAgainst( Client )
	-- First decide if any action needs to be taken against anyone
	local Players = Shared.GetEntitiesWithClassname( "Player" )
	if #Players < self.Config.MinPlayers then return false end
	
	local Player = TGNS.GetPlayer( Client ) 
	-- Next check for various immunities
	if PlayerAFK:IsImmune( Player, Client ) then return false end
	
	local TimeAfk = PlayerAFK:TimeAFK( Player, Client )
	if not LastActionTimes[Client].IsAFK and TimeAfk >= self.Config.ConsiderAFKTime then
		LastActionTimes[Client].IsAFK = true
		TGNS.ExecuteEventHooks("AfkChanged", Player, true)
	end
	
	local WarnTimeIndex = 1
	if LastActionTimes[Client].LastWarn then
		WarnTimeIndex = LastActionTimes[Client] + 1
	end
	
	local WarnTimeSeconds = self.Config.WarnTimes[WarnTimeIndex]
	if WarnTimeSeconds then
		if TimeAfk < WarnTimeSeconds then 
			return false
		else
			md:ToPlayerNotifyInfo( "You have been afk for " .. TimeAfk .. " seconds, and will be kicked in " .. (self.Config.KickTime - TimeAfk) .. " seconds" )
		end
	elseif self.Config.KickTime - TimeAfk <= 0.01 then -- No warnings left
		TGNSClientKicker.Kick( Client, "You were kicked for being afk for " .. TimeAfk .. " seconds", function () end, function() end, false )
	end
end

--- If, somehow, some players weren't removed from
-- the list, this will fix that
function PlayerAFK:CleanupMemory( )
	for k, v in pairs(LastActionTimes) do
		v.IsPlayerConnected = false
	end
	
	-- This ought to have a helper method
	local Players = Shared.GetEntitiesWithClassname( "Player" )
	
	for i = 1, #Players do
		local Ply = Players[i]
		
		if Ply then
			local Cli = GetOwner( Ply )
			if Cli then
				LastActionTimes[Cli].IsPlayerConnected = true
			end
		end
	end
	
	for k, v in pairs(LastActionTimes) do
		if not v.IsPlayerConnected then
			LastActionTimes[k] = nil
		else
			LastActionTimes[k].IsPlayerConnected = nil
		end
	end
end

function Plugin:GetPlayerAFK()
	return PlayerAFK
end

function Plugin:Initialise()
	self.Enabled = true
	md = TGNSMessageDisplayer.Create("AFK-Kick+")
	
	
	TGNS.ScheduleActionInterval(1, function() 
		local Clients = TGNS.GetClients(TGNS.GetPlayerList())
		for c in Clients do
			PlayerAFK:PerformActionAgainst( c )
		end
	end)
	return true
end

-- 
-- These functions merely detect movement/actions that reset afk timers in roguhly
-- the order they would happen in (for convienent scanning)
--
function Plugin:ClientConnect( Client )
	PlayerAFK:ResetAFKTimer( Client )
end

function Plugin:ClientConfirmConnect( Client )
	PlayerAFK:ResetAFKTimer( Client )
end

function Plugin:OnProcessMove( Player, Input )
	local Gamerules = GetGamerules()
	local Started = Gamerules and Gamerules:GetGameStarted()
	
	local Client = GetOwner( Player )
	
	local ClientActionTimes = LastActionTimes[Client]
	if not ClientActionTimes then 
		if not ResetAFKTimer( Client ) then return end
		ClientActionTimes = LastActionTimes[Client]
	end
	
	local Pitch, Yaw = Input.pitch, Input.yaw
	local LastPitch, LastYaw = ClientActionTimes.LastPitch, ClientActionTimes.LastYaw
	ClientActionTimes.LastPitch, ClientActionTimes.LastYaw = Pitch, Yaw
	
	if LastPitch and LastPitch ~= Pitch then
		PlayerAFK:ResetAFKTimer( Client )
		return
	end
	if LastYaw and LastYaw ~= Yaw then
		PlayerAFK:ResetAFKTimer( Client )
		return
	end
	if Input.move.x ~= 0 or Input.move.y ~= 0 or Input.move.z ~= 0 then
		PlayerAFK:ResetAFKTimer( Client ) 
	end
end

function Plugin:PlayerNameChange( Player, ... )
	local Client = GetOwner( Player ) 
	PlayerAFK:ResetAFKTimer( Client ) 
end

function Plugin:PlayerSay( Client, ... )
	PlayerAFK:ResetAFKTimer( Client )
end

-- Commander Functions
local function GetBuildingOwnerClient( Building )
	local Team = Building:GetTeam()

	-- Check for spectate / modded team
	if not Team or not Team.GetCommander then return end

	-- Get the owner of the building, which is whoever placed it (this might
	-- not be the commander)
	local Owner = Building:GetOwner()
	
	-- If the owner doesn't exist, fallback to the commander. The Owner will exist
	-- in sentries that are placed by the commander, but it isn't guarranteed to work
	-- for, say, armories
	Owner = Owner or Team:GetCommander()

	-- If there is no owner still, then do nothing
	if not Owner then return end
	
	return GetOwner( Owner )
end

function Plugin:CommLoginPlayer( Building, Player )
	PlayerAFK:ResetAFKTimer( GetOwner( Player ) )
end

function Plugin:OnConstructInit( Building )
	PlayerAFK:ResetAFKTimer( GetBuildingOwnerClient( Building ) )
end

function Plugin:OnCommanderTechTreeAction( Commander, ... )
        local Client = GetOwner( Commander )
        if not Client then return end
        
        PlayerAFK:ResetAFKTimer( Client )
end

function Plugin:OnRecycle( Building, ResearchID )
	PlayerAFK:ResetAFKTimer( GetBuildingOwnerClient( Building ) )
end

function Plugin:OnCommanderNotify( Commander, ... )
        PlayerAFK:ResetAFKTimer( GetOwner( Commander ) )
end

function Plugin:CommLogout( Player )
	PlayerAFK:ResetAFKTimer( GetOwner( Player ) )
end

-- End Commander Functions

function Plugin:ClientDisconnect( Client )
	LastActionTimes[Client] = nil
end
--
-- End action detecting functions
--

function Plugin:Cleanup()
	AfkTimes = {}
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension( "improvedafk", Plugin )