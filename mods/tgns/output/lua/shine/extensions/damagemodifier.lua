local Plugin = {}
-- Plugin.HasConfig = true
-- Plugin.ConfigName = "damagemodifier.json"

function Plugin:TakeDamage( Ent, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
	local winOrLoseModification = Shine.Plugins.winorlose and Shine.Plugins.winorlose.GetDamageModification and Shine.Plugins.winorlose:GetDamageModification( Ent, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
	if winOrLoseModification then
		Damage = winOrLoseModification.Damage
		HealthUsed = winOrLoseModification.HealthUsed
		ArmourUsed = winOrLoseModification.ArmourUsed
		winOrLoseModification.NotifyAction()
	else
		local lapsModification = Shine.Plugins.lapstracker and Shine.Plugins.lapstracker.GetDamageModification and Shine.Plugins.lapstracker:GetDamageModification( Ent, Damage, Attacker, Inflictor, Point, Direction, ArmourUsed, HealthUsed, DamageType, PreventAlert )
		if lapsModification then
		Damage = lapsModification.Damage
		HealthUsed = lapsModification.HealthUsed
		ArmourUsed = lapsModification.ArmourUsed
		lapsModification.NotifyAction()
		end
	end
	return Damage, ArmourUsed, HealthUsed
end

function Plugin:Initialise()
    self.Enabled = true
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("damagemodifier", Plugin )
