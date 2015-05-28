local md
local recentLocations = {}
local MAXIMUM_ALLOWED_LOCATION_DURATION = 20
local tracks = {}
local trackStartTimes = {}
local LOWEST_CHANNEL_ID = 71
local highestChannelId
local enabled = {}
local startingRoomNames = {}
local nextLocationNames = {}

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "lapstracker.json"

local function debug(message)
	if not TGNS.IsProduction() then
		md:ToAdminNotifyInfo(message)
	end
end

local function getTrackDuration(client, trackId)
	local result = Shared.GetTime() - trackStartTimes[client][trackId]
	return result
end

local function getTrackDurationDisplay(trackDuration)
	local result = TGNS.GetStopWatchTime(trackDuration)
	return result
end

local function clearTexts(client, lowestChannelId)
	lowestChannelId = lowestChannelId or LOWEST_CHANNEL_ID
	for i=lowestChannelId, highestChannelId or lowestChannelId do Shine.ScreenText.End(i, client) end
end

local function disableLaps(client, reason, endTexts)
	enabled[client] = false
	recentLocations[client] = {}
	trackStartTimes[client] = {}
	nextLocationNames[client] = {}
	md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), string.format("Laps disabled due to %s. %s", reason, (TGNS.ClientIsOnPlayingTeam(client) and not (TGNS.IsGameInProgress() or TGNS.IsGameInCountdown())) and "Type sh_laps in your client console to re-enable." or ""))
	if endTexts then
		clearTexts(client)
		Shine.ScreenText.End(98, client)
		Shine.ScreenText.End(99, client)
		Shine.ScreenText.End(100, client)
	end
end


local function OnLocationChanged(player, locationName)
	local client = TGNS.GetClient(player)
	if enabled[client] and not TGNS.IsGameInProgress() and not TGNS.IsGameInCountdown() then
		--debug(string.format("locationName: %s", locationName))
		recentLocations[client] = recentLocations[client] or {}
		trackStartTimes[client] = trackStartTimes[client] or {}
		nextLocationNames[client] = nextLocationNames[client] or {}
		if TGNS.ClientIsOnPlayingTeam(client) and TGNS.HasNonEmptyValue(locationName) and not (#recentLocations[client] > 0 and recentLocations[client][#recentLocations[client]].locationName == locationName) then
			local now = Shared.GetTime()
			table.insert(recentLocations[client], {locationName=locationName,time=now})
			if #recentLocations[client] > 20 then
				table.remove(recentLocations[client], 1)
			end
			--debug(TGNS.Join(TGNS.Select(recentLocations[client], function(l) return l.locationName end), ", "))
			if #recentLocations[client] > 1 then
				TGNS.ScheduleAction(MAXIMUM_ALLOWED_LOCATION_DURATION, function()
					if enabled[client] and #recentLocations[client] > 1 and Shine:IsValidClient(client) and TGNS.GetLast(recentLocations[client]).time == now then
						disableLaps(client, "inactivity")
					end
				end)
			end
			local advisories = {}
			TGNS.DoForPairs(tracks, function(trackId, trackData)
				local trackName = trackData.name
				local trackLocationNames = trackData.locationNames
				if locationName == TGNS.GetFirst(trackLocationNames) and not trackStartTimes[client][trackId] and #recentLocations[client] > 1 and recentLocations[client][#recentLocations[client]-1].locationName == trackLocationNames[#trackLocationNames-1] then
					trackStartTimes[client][trackId] = TGNS.GetLast(recentLocations[client]).time
				end
			end)

			TGNS.DoForPairs(tracks, function(trackId, trackData)
				local trackName = trackData.name
				local trackLocationNames = trackData.locationNames
				local completedTrack
				nextLocationNames[client][trackId] = nextLocationNames[client][trackId] or {}
				if ((nextLocationNames[client][trackId].first == locationName) or (trackLocationNames[1] == locationName)) and trackStartTimes[client][trackId] then
					local relevantRecentLocations = TGNS.Where(recentLocations[client], function(l) return l.time >= trackStartTimes[client][trackId] end)
					local matchingLocations = {}
					TGNS.DoFor(relevantRecentLocations, function(relevantRecentLocation, index)
						if relevantRecentLocation.locationName == trackLocationNames[index] then
							table.insert(matchingLocations, relevantRecentLocation)
						end
					end)
					if #matchingLocations == #trackLocationNames then
						completedTrack = true
					end
					TGNS.DoFor(trackLocationNames, function(trackLocationName, mainIndex)
						if mainIndex > 1 and trackLocationNames[mainIndex-1] == locationName then
							local relevantRecentLocationsIncludeAllTrackLocationsSoFar = true
							for subIndex = mainIndex-1, 1, -1 do
								relevantRecentLocationsIncludeAllTrackLocationsSoFar = relevantRecentLocationsIncludeAllTrackLocationsSoFar and #relevantRecentLocations >= subIndex and relevantRecentLocations[subIndex].locationName == trackLocationNames[subIndex]
								if not relevantRecentLocationsIncludeAllTrackLocationsSoFar then
									break
								end
							end
							if relevantRecentLocationsIncludeAllTrackLocationsSoFar then
								nextLocationNames[client][trackId] = {first=trackLocationName,second=mainIndex < #trackLocationNames and trackLocationNames[mainIndex+1] or nil}
							end
						end
					end)
					local trackDuration = getTrackDuration(client, trackId)
					if nextLocationNames[client][trackId].first then
						local trackDescriptor = string.format("(%sTime: %s) %s", completedTrack and "Final " or "", getTrackDurationDisplay(trackDuration), trackName)
						local routeDescriptor = string.format("Go to %s", string.format("%s%s", nextLocationNames[client][trackId].first, nextLocationNames[client][trackId].second and string.format(", then %s", nextLocationNames[client][trackId].second) or "!"))
						table.insert(advisories, {i=trackId,n=trackName,l=trackDescriptor,r=routeDescriptor})
					end
					if completedTrack then
						local message = string.format("%s finished %s in %s. Learn more: http://rr.tacticalgamer.com/Laps", TGNS.GetClientName(client), trackName, getTrackDurationDisplay(trackDuration))
						if math.random() < 0.05 then
							md:ToAllNotifyInfo(message)
						else
							md:ToPlayerNotifyInfo(player, message)
						end
						local url = string.format("%s&i=%s&t=%s&b=%s&s=%s", TGNS.Config.LapsEndpointBaseUrl, TGNS.GetClientSteamId(client), TGNS.UrlEncode(trackId), TGNS.UrlEncode(Shared.GetBuildNumber()), TGNS.UrlEncode(trackDuration))
						TGNS.GetHttpAsync(url, function(lapsResponseJson)
							local lapsResponse = json.decode(lapsResponseJson) or {}
							if not lapsResponse.success then
								TGNS.DebugPrint(string.format("laps ERROR: Unable to save laps data for playerid %s. msg: %s | response: %s | stacktrace: %s", TGNS.GetClientSteamId(client), lapsResponse.msg, lapsResponseJson, lapsResponse.stacktrace))
							end
						end)
						trackStartTimes[client][trackId] = TGNS.GetLast(recentLocations[client]).time
					end
				else
					if trackStartTimes[client][trackId] then
						table.insert(advisories, {i=trackId,n=trackName,l=string.format("%s HALTED", trackName),r=string.format("Wrong Room (Needed: %s, not %s)", nextLocationNames[client][trackId].first, locationName), isBad=true})
					end
					local trackDescriptor = string.format("To Start %s", trackName)
					local routeDescriptor = string.format("Go to %s, then %s", trackData.locationNames[#trackData.locationNames-1], TGNS.GetFirst(trackData.locationNames))
					table.insert(advisories, {i=trackId,n=trackName,l=trackDescriptor,r=routeDescriptor})
					trackStartTimes[client][trackId] = false
				end
			end)
			if #advisories > 0 then
				table.sort(advisories, function(a1, a2)
					local a1s = trackStartTimes[client][a1.i] or 10000
					local a2s = trackStartTimes[client][a2.i] or 10000
					if a1.isBad	then
						a1s = a1s + 100000
					end
					if a2.isBad	then
						a2s = a2s + 100000
					end
					if a1s ~= a2s then
						return a1s < a2s
					else
						return a1.n < a2.n
					end
				end)
				local channelId = LOWEST_CHANNEL_ID
				local y = 0.6
				TGNS.DoFor(advisories, function(a)
					local r = a.isBad and 255 or 0
					local g = a.isBad and 0 or 255
					local b = ((not trackStartTimes[client][a.i]) and (not a.isBad)) and 255 or 0
					local size = trackStartTimes[client][a.i] and 3 or 1
					local duration = #recentLocations[client] > 1 and MAXIMUM_ALLOWED_LOCATION_DURATION or 100000
					Shine.ScreenText.Add(channelId, {X = 0.5, Y = y, Text = string.format("%s:", a.l), Duration = duration, R = r, G = g, B = b, Alignment = TGNS.ShineTextAlignmentMax, Size = size, FadeIn = 0, IgnoreFormat = true}, client)
					channelId = channelId + 1
					Shine.ScreenText.Add(channelId, {X = 0.5, Y = y, Text = string.format(" %s", a.r), Duration = duration, R = r, G = g, B = b, Alignment = TGNS.ShineTextAlignmentMin, Size = size, FadeIn = 0, IgnoreFormat = true}, client)
					channelId = channelId + 1
					y = y + 0.05
				end)
				clearTexts(client, channelId)
				highestChannelId = channelId
			end
			Shine.ScreenText.Add(98, {X = 0.5, Y = 0.95, Text = "Hide these messages: sh_laps in console", Duration = MAXIMUM_ALLOWED_LOCATION_DURATION, R = 255, G = 255, B = 255, Alignment = TGNS.ShineTextAlignmentCenter, Size = 1, FadeIn = 0, IgnoreFormat = true}, client)
			Shine.ScreenText.Add(99, {X = 0.5, Y = 0.05, Text = "http://rr.tacticalgamer.com/Laps", Duration = MAXIMUM_ALLOWED_LOCATION_DURATION, R = 255, G = 255, B = 255, Alignment = TGNS.ShineTextAlignmentCenter, Size = 1, FadeIn = 0, IgnoreFormat = true}, client)
		end
	end
end

function Plugin:CreateCommands()
    local lapsCommand = self:BindCommand( "sh_laps", nil, function(client)
        md:ToClientConsole(client, "")
        md:ToClientConsole(client, "== LAPS ==")
    	if TGNS.ClientIsAlien(client) then
    		if not TGNS.IsGameInProgress() then
	    		if #startingRoomNames > 0 then
			    	enabled[client] = not enabled[client] == true
			        if enabled[client] then
			        	local player = TGNS.GetPlayer(client)
				        md:ToClientConsole(client, string.format("You have %s Laps. Execute sh_laps again to %s it.", enabled[client] and "enabled" or "disabled", enabled[client] and "disable" or "enable"))
				        md:ToClientConsole(client, "")
				        md:ToClientConsole(client, "Laps is competitive time trials through stock NS2 maps. Following pre-defined room routes, you")
				        md:ToClientConsole(client, "race against your own past times and those of other players. Each map has multiple tracks, each")
				        md:ToClientConsole(client, "defined as a list of sequential room names. Try to move through each track as fast as possible!")
				        md:ToClientConsole(client, "")
				        md:ToClientConsole(client, "If you haven't yet seen http://rr.tacticalgamer.com/Laps, you might read the Help there before continuing.")
				        md:ToClientConsole(client, "")
				        md:ToClientConsole(client, "Otherwise, you're ready to race! Starting rooms are displayed on screen!")
				        md:ToClientConsole(client, "")
				        OnLocationChanged(player, player:GetLocationName())
				    else
						disableLaps(client, "console command", true)
			        end
	    		else
	    			md:ToClientConsole(client, "ERROR: No tracks are defined for this map.")
	    		end
    		else
    			md:ToClientConsole(client, "ERROR: You may not enable Laps during gameplay.")
    		end
    	else
    		md:ToClientConsole(client, "ERROR: You must be a Skulk to enable Laps. Other classes might be supported in the future.")
    	end
        md:ToClientConsole(client, "")
    end, true)
    lapsCommand:Help("Toggle the Laps tracker. Learn more: http://rr.tacticalgamer.com/Laps")
end

function Plugin:PostJoinTeam(gamerules, player, oldTeamNumber, newTeamNumber, force, shineForce)
	local client = TGNS.GetClient(player)
	if enabled[client] and not TGNS.IsGameplayTeamNumber(newTeamNumber) then
		disableLaps(client, "leaving team", true)
	end
end

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create("LAPS")
    self:CreateCommands()
	TGNS.RegisterEventHook("PlayerLocationChanged", OnLocationChanged)

	TGNS.RegisterEventHook("GameStarted", function(secondsSinceEpoch)
		TGNS.DoFor(TGNS.GetClientList(), function(c)
			if enabled[c] then
				disableLaps(c, "game start", true)
			end
		end)
	end)
	
	TGNS.ScheduleAction(0, function()
		TGNS.DoForPairs(Shine.Plugins.lapstracker.Config.Tracks, function(trackId, trackData)
			if trackData.mapName == TGNS.GetCurrentMapName() then
				tracks[trackId] = trackData
				table.insertunique(startingRoomNames, TGNS.GetFirst(trackData.locationNames))
			end
		end)
	end)

    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("lapstracker", Plugin )
