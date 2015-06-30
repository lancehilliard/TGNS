local md
local clientFriendlyFireWarnings = {}

local function TakeDamage( OldFunc, self, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
	local victim = self
	if Attacker and victim and Attacker:isa("Player") and victim ~= Attacker and Inflictor ~= nil and Inflictor:GetParent() == Attacker and victim:GetTeamNumber() == Attacker:GetTeamNumber() then
		local attackerClient = TGNS.GetClient(Attacker)
		if TGNS.IsClientStranger(attackerClient) then
			clientFriendlyFireWarnings[attackerClient] = clientFriendlyFireWarnings[attackerClient] or 0
			if clientFriendlyFireWarnings[attackerClient] < 2 then
				clientFriendlyFireWarnings[attackerClient] = clientFriendlyFireWarnings[attackerClient] + 1
				md:ToPlayerNotifyRed(Attacker, "Friendly fire ENABLED! Please check your fire.")
			end
		end
		PreventAlert = true
	end
	return OldFunc( victim, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
end

local Plugin = {}

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
    if TGNS.IsGameplayTeamNumber(newTeamNumber) and TGNS.IsClientStranger(TGNS.GetClient(client)) then
    	TGNS.ScheduleAction(6, function()
    		md:ToPlayerNotifyInfo(player, "Friendly Fire is ENABLED! Please be careful when attacking.")
    	end)
    end
end

function Plugin:Initialise()
    self.Enabled = true
	md = TGNSMessageDisplayer.Create("FF")
	-- Shine.Hook.SetupClassHook( "LiveMixin", "TakeDamage", "TakeDamage", TakeDamage )
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("friendlyfiretweaks", Plugin )