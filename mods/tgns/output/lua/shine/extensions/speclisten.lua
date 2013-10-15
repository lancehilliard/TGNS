local originalGetCanPlayerHearPlayer
local md
local specmods = {}

local function playerShouldSeeSpecMods(player)
	local result = specmods[player] == nil or specmods[player] == true
	return result
end

local Plugin = {}

function Plugin:CreateCommands()
    local modCommand = self:BindCommand( "sh_specmods", "specmods", function(client)
        local player = TGNS.GetPlayer(client)
        specmods[player] = not (specmods[player] == nil or specmods[player] == true)
        md:ToPlayerNotifyInfo(player, string.format("Spectate modifications are %s.", specmods[player] == true and "on" or "off"))
    end)
    modCommand:Help( "Toggle spectate modifications on/off." )
end

function Plugin:Initialise()
    self.Enabled = true
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		if TGNS.IsPlayerSpectator(listenerPlayer) and playerShouldSeeSpecMods(listenerPlayer) then
			result = true
		end
		return result
	end)
	TGNS.ScheduleActionInterval(5, function()
		local specPlayers = TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.IsPlayerSpectator(p) and playerShouldSeeSpecMods(p) end)
		TGNS.DoFor(specPlayers, function(p)
			md:ToPlayerNotifyInfo(p, "Limit of 8 per team. Join when you see an opening. Spectate while you wait.")
			md:ToPlayerNotifyInfo(p, "Enjoy the show for now. Spectating is a fun privilege! Don't abuse it!")
		end)
	end)
	md = TGNSMessageDisplayer.Create("SPECTATE")
	self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("speclisten", Plugin )