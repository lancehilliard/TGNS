local md = TGNSMessageDisplayer.Create()

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "printablenames.json"

function Plugin:JoinTeam(gamerules, player, newTeamNumber, force, shineForce)
	local _, nonPrintableCharactersCount = string.gsub(player:GetName(), "[^\32-\126]", "")
	if nonPrintableCharactersCount>0 and newTeamNumber ~= kTeamReadyRoom then
		local client = TGNS.GetClient(player)
		TGNSClientKicker.Kick(client, Shine.Plugins.printablenames.Config.KickMessage)
	end
end

function Plugin:PlayerNameChange(player, newName, oldName)
	local _, nonPrintableCharactersCount = string.gsub(newName, "[^\32-\126]", "")
	if nonPrintableCharactersCount>0 then
		local gamerules = GetGamerules()
		if gamerules then
			md:ToPlayerNotifyError(player, Shine.Plugins.printablenames.Config.WarnMessage)
			gamerules:JoinTeam(player, kTeamReadyRoom)
		end
	end
end

function Plugin:Initialise()
    self.Enabled = true
	TGNS.RegisterEventHook("OnSlotTaken", function(client)
		local player = TGNS.GetPlayer(client)
		local _, nonPrintableCharactersCount = string.gsub(player:GetName(), "[^\32-\126]", "")
		if nonPrintableCharactersCount>0 then
			md:ToPlayerNotifyError(player, Shine.Plugins.printablenames.Config.WarnMessage)
		end
	end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("printablenames", Plugin )