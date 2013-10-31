local originalGetCanPlayerHearPlayer
local md
local specmodes = {}
local modeDescriptions = {["0"] = "Chat Advisory ON; Voicecomm: All"
	, ["1"] = "Chat Advisory OFF; Voicecomm: Marines only"
	, ["2"] = "Chat Advisory OFF; Voicecomm: Aliens only"
	, ["3"] = "Chat Advisory OFF; Voicecomm: Marines and Aliens only"
	, ["4"] = "Chat Advisory OFF; Voicecomm: None"}

local function playerHasDefaultMode(player)
	local result = specmodes[player] == nil or specmodes[player] == 0
	return result
end

local function listenerSpectatorShouldHearSpeaker(listenerPlayer, speakerPlayer)
	local speakerPlayerTeamNumber = TGNS.GetPlayerTeamNumber(speakerPlayer)
	local result = playerHasDefaultMode(listenerPlayer) or (TGNS.PlayerIsOnPlayingTeam(speakerPlayer) and (specmodes[listenerPlayer] == 3 or specmodes[listenerPlayer] == speakerPlayerTeamNumber))
	return result
end

local function spectatorShouldSeeChatAdvisories(player)
	local result = playerHasDefaultMode(player)
	return result
end

local function showUsage(player)
	md:ToPlayerNotifyError(player, "Invalid mode. Press 'M > Info > sh_specmode' for usage.")
end

local Plugin = {}

function Plugin:CreateCommands()
    local modCommand = self:BindCommand( "sh_specmode", "specmode", function(client, modeCandidate)
    	local player = TGNS.GetPlayer(client)
    	local mode = tonumber(modeCandidate)
    	if mode == nil or mode < 0 or mode > 4 then
    		showUsage(player)
    	else
    		specmodes[player] = mode
    	end
    	local currentSpecMode = tostring(specmodes[player] or 0)
    	md:ToPlayerNotifyInfo(player, string.format("Current sh_specmode: %s (%s)", currentSpecMode, modeDescriptions[currentSpecMode]))
    end, true)
    modCommand:AddParam{ Type = "string", TakeRestofLine = true, Optional = true }
    modCommand:Help( "Toggle spectate modifications on/off." )
end

function Plugin:Initialise()
    self.Enabled = true
	originalGetCanPlayerHearPlayer = TGNS.ReplaceClassMethod("NS2Gamerules", "GetCanPlayerHearPlayer", function(self, listenerPlayer, speakerPlayer)
		local result
		if TGNS.IsPlayerSpectator(listenerPlayer) then
			result = listenerSpectatorShouldHearSpeaker(listenerPlayer, speakerPlayer)
		else
			result = originalGetCanPlayerHearPlayer(self, listenerPlayer, speakerPlayer)
		end
		return result
	end)
	TGNS.ScheduleActionInterval(90, function()
		local specPlayers = TGNS.Where(TGNS.GetPlayerList(), function(p) return TGNS.IsPlayerSpectator(p) and spectatorShouldSeeChatAdvisories(p) end)
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