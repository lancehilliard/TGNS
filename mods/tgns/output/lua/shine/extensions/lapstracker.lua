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
local trackLowestTimes = {}
local lastKnownLocationNames = {}
local onLocationChangedEnabled

local Plugin = {}
Plugin.HasConfig = true
Plugin.ConfigName = "lapstracker.json"

local function giveWaypoint(player, locationName)
	-- disabled for now, as: 1) you're arguably moving too fast to use waypoints 2) they often show the slowest path (if ever another attempt: use origin that's above ground, not beneath it)
	-- local locationEntity = TGNS.GetFirst(GetLocationEntitiesNamed(locationName))
	-- player:GiveOrder(kTechId.Move, locationEntity:GetId(), locationEntity:GetOrigin())
	-- GetGroundAt(self, location, PhysicsMask.AIMovement)
end

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
	onLocationChangedEnabled = TGNS.Any(TGNS.GetClientList(), function(c) return enabled[c] == true end)
	recentLocations[client] = {}
	trackStartTimes[client] = {}
	nextLocationNames[client] = {}
	local player = TGNS.GetPlayer(client)
	md:ToPlayerNotifyInfo(player, string.format("Laps disabled due to %s. %s", reason, (TGNS.ClientIsOnPlayingTeam(client) and not (TGNS.IsGameInProgress() or TGNS.IsGameInCountdown())) and "Type sh_laps in your client console to re-enable." or ""))
	TGNS.RemoveMarinePlayerJetpack(player)
	if endTexts then
		clearTexts(client)
		Shine.ScreenText.End(97, client)
		Shine.ScreenText.End(98, client)
		Shine.ScreenText.End(99, client)
		Shine.ScreenText.End(100, client)
	end
end

local function showLowestTime(client, trackId)
	local player = TGNS.GetPlayer(client)
	trackLowestTimes[client] = trackLowestTimes[client] or {}
	trackLowestTimes[client][trackId] = trackLowestTimes[client][trackId] or {}
	trackStartTimes[client] = trackStartTimes[client] or {}
	local className = TGNS.GetPlayerClassName(player)
	if trackLowestTimes[client][trackId][className] ~= nil and trackLowestTimes[client][trackId][className] > 0 and trackStartTimes[client][trackId] then
		local trackData = tracks[trackId]
		local mapDescriptor = string.format("%s (%s)", trackData.name, Shared.GetBuildNumber())
		local message = string.format("%s\nYour Best Time (%s):\n%s", mapDescriptor, className, getTrackDurationDisplay(trackLowestTimes[client][trackId][className]))
		Shine.ScreenText.Add(97, {X = 0.8, Y = 0.3, Text = message, Duration = MAXIMUM_ALLOWED_LOCATION_DURATION, R = 255, G = 255, B = 255, Alignment = TGNS.ShineTextAlignmentMin, Size = 3, FadeIn = 0, IgnoreFormat = true}, client)
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
					TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.scoreboard.LAPS_START, {})
					trackLowestTimes[client] = trackLowestTimes[client] or {}
					local className = TGNS.GetPlayerClassName(player)
					trackLowestTimes[client][trackId] = trackLowestTimes[client][trackId] or {}
					if trackLowestTimes[client][trackId][className] == nil then
						local url = string.format("%s&i=%s&t=%s&b=%s&c=%s", TGNS.Config.LapsEndpointBaseUrl, TGNS.GetClientSteamId(client), TGNS.UrlEncode(trackId), TGNS.UrlEncode(Shared.GetBuildNumber()), TGNS.UrlEncode(className))
						TGNS.GetHttpAsync(url, function(lapsResponseJson)
							local lapsResponse = json.decode(lapsResponseJson) or {}
							if lapsResponse.success then
								if lapsResponse.seconds > 0 then
									trackLowestTimes[client][trackId][className] = lapsResponse.seconds
									showLowestTime(client, trackId)
								end
							else
								TGNS.DebugPrint(string.format("laps ERROR: Unable to access laps data for playerid %s. msg: %s | response: %s | stacktrace: %s", TGNS.GetClientSteamId(client), lapsResponse.msg, lapsResponseJson, lapsResponse.stacktrace))
							end
						end)					
					end
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
					if TGNS.ClientIsMarine(client) then
						player:SetFuel(1)
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
						if trackStartTimes[client][trackId] then
							giveWaypoint(player, nextLocationNames[client][trackId].first)
						end
					end
					if completedTrack then
						local showCompletedMessageToAll = math.random() < 0.05
						local message = string.format("%s finished %s in %s. %s", showCompletedMessageToAll and TGNS.GetClientName(client) or "You", trackName, getTrackDurationDisplay(trackDuration), showCompletedMessageToAll and "Learn more: http://rr.tacticalgamer.com/Laps" or "")
						if showCompletedMessageToAll then
							md:ToAllNotifyInfo(message)
						else
							md:ToPlayerNotifyInfo(player, message)
						end
						trackLowestTimes[client] = trackLowestTimes[client] or {}
						trackLowestTimes[client][trackId] = trackLowestTimes[client][trackId] or {}
						local className = TGNS.GetPlayerClassName(player)
						local lowestPreviousTime = trackLowestTimes[client][trackId][className]
						local url = string.format("%s&i=%s&t=%s&b=%s&s=%s&c=%s", TGNS.Config.LapsEndpointBaseUrl, TGNS.GetClientSteamId(client), TGNS.UrlEncode(trackId), TGNS.UrlEncode(Shared.GetBuildNumber()), TGNS.UrlEncode(trackDuration), TGNS.UrlEncode(className))
						TGNS.GetHttpAsync(url, function(lapsResponseJson)
							local lapsResponse = json.decode(lapsResponseJson) or {}
							if not lapsResponse.success then
								TGNS.DebugPrint(string.format("laps ERROR: Unable to save laps data for playerid %s. msg: %s | response: %s | stacktrace: %s", TGNS.GetClientSteamId(client), lapsResponse.msg, lapsResponseJson, lapsResponse.stacktrace))
								md:ToClientConsole(client, "")
								md:ToPlayerNotifyError(player, string.format("System error! %s time not recorded! :(  Console for assistance.", getTrackDurationDisplay(trackDuration)))
								md:ToClientConsole(client, "Feel free to ask Wyzcrak to manually record this time *if* it represents your personal track record.")
								md:ToClientConsole(client, "When he verifies this notification in the server log, he'll add the time manually for you.")
								md:ToClientConsole(client, "")
								trackLowestTimes[client][trackId][className] = lowestPreviousTime
							end
						end)
						trackLowestTimes[client][trackId][className] = trackDuration <= (trackLowestTimes[client][trackId][className] or trackDuration) and trackDuration or trackLowestTimes[client][trackId][className]
						if trackLowestTimes[client][trackId][className] < (lowestPreviousTime or 0) then
							TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.scoreboard.LAPS_BEST, {})
						else
							TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.scoreboard.LAPS_START, {})
						end
						trackStartTimes[client][trackId] = TGNS.GetLast(recentLocations[client]).time
					elseif trackLocationNames[1] ~= locationName then
							TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.scoreboard.LAPS_LEG, {})
					end
					showLowestTime(client, trackId)
				else
					if trackStartTimes[client][trackId] then
						table.insert(advisories, {i=trackId,n=trackName,l=string.format("%s HALTED", trackName),r=string.format("Wrong Room (Needed: %s, not %s)", nextLocationNames[client][trackId].first, locationName), isBad=true})
						TGNS.SendNetworkMessageToPlayer(player, Shine.Plugins.scoreboard.LAPS_BAD, {})
						Shine.ScreenText.End(97, client)
					end
					local trackDescriptor = string.format("To Start %s", trackName)
					local isLaunchRoom = trackData.locationNames[#trackData.locationNames-1] == locationName
					local routeDescriptor
					if isLaunchRoom then
						routeDescriptor = string.format("Go to %s", TGNS.GetFirst(trackData.locationNames))
					else
						routeDescriptor = string.format("Go to %s, then %s", trackData.locationNames[#trackData.locationNames-1], TGNS.GetFirst(trackData.locationNames))
					end
					table.insert(advisories, {i=trackId,n=trackName,l=trackDescriptor,r=routeDescriptor,isLaunchRoom=isLaunchRoom})
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
					local left_r
					local left_g
					local left_b
					local right_r
					local right_g
					local right_b
					if a.isBad then
						left_r = 255
						left_g = 0
						left_b = 0
						right_r = left_r
						right_g = left_g
						right_b = left_b
					else
						if trackStartTimes[client][a.i] then
							left_r = 255
							left_g = 255
							left_b = 255
							right_r = 0
							right_g = 255
							right_b = 0
						else
							left_r = 0
							left_g = 255
							left_b = 255
							if a.isLaunchRoom then
								right_r = 0
								right_g = 255
								right_b = 0
							else
								right_r = left_r
								right_g = left_g
								right_b = left_b
							end
						end
					end
					local size = trackStartTimes[client][a.i] and 3 or 1
					local duration = #recentLocations[client] > 1 and MAXIMUM_ALLOWED_LOCATION_DURATION or 100000
					Shine.ScreenText.Add(channelId, {X = 0.5, Y = y, Text = string.format("%s:", a.l), Duration = duration, R = left_r, G = left_g, B = left_b, Alignment = TGNS.ShineTextAlignmentMax, Size = size, FadeIn = 0, IgnoreFormat = true}, client)
					channelId = channelId + 1
					Shine.ScreenText.Add(channelId, {X = 0.5, Y = y, Text = string.format(" %s", a.r), Duration = duration, R = right_r, G = right_g, B = right_b, Alignment = TGNS.ShineTextAlignmentMin, Size = size, FadeIn = 0, IgnoreFormat = true}, client)
					channelId = channelId + 1
					y = y + 0.05
				end)
				clearTexts(client, channelId)
				highestChannelId = channelId
			end
			local r = 168
			local g = 168
			local b = 168
			Shine.ScreenText.Add(98, {X = 0.5, Y = 0.95, Text = "Hide these messages: sh_laps in console", Duration = MAXIMUM_ALLOWED_LOCATION_DURATION, R = r, G = g, B = b, Alignment = TGNS.ShineTextAlignmentCenter, Size = 1, FadeIn = 0, IgnoreFormat = true}, client)
			Shine.ScreenText.Add(99, {X = 0.5, Y = 0.05, Text = "http://rr.tacticalgamer.com/Laps", Duration = MAXIMUM_ALLOWED_LOCATION_DURATION, R = r, G = g, B = b, Alignment = TGNS.ShineTextAlignmentCenter, Size = 1, FadeIn = 0, IgnoreFormat = true}, client)
		end
	end
end

function Plugin:CreateCommands()
    local lapsCommand = self:BindCommand( "sh_laps", nil, function(client)
       	local player = TGNS.GetPlayer(client)
        md:ToClientConsole(client, "")
        md:ToClientConsole(client, "== LAPS ==")

		if TGNS.ClientIsOnPlayingTeam(client) then
			if not TGNS.IsClientCommander(client) then
	    		if not TGNS.IsGameInProgress() then    		if #startingRoomNames > 0 then
				    	enabled[client] = not enabled[client] == true
				        if enabled[client] then
				        	onLocationChangedEnabled = true
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
					        TGNS.GiveMarinePlayerJetpack(player)
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
				md:ToClientConsole(client, string.format("Exit the %s before executing sh_laps.", TGNS.GetTeamCommandStructureCommonName(TGNS.GetPlayerTeamNumber(player))))
			end
		else
			md:ToClientConsole(client, "ERROR: You must be on the Marine or Alien team to use this command.")
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

function Plugin:OnProcessMove(player, input)
	if onLocationChangedEnabled then
		local locationName = player:GetLocationName()
		if locationName ~= lastKnownLocationNames[player] then
			lastKnownLocationNames[player] = locationName
			OnLocationChanged(player, locationName)
		end
	end
end

function Plugin:Initialise()
    self.Enabled = true
    md = TGNSMessageDisplayer.Create("LAPS")
    self:CreateCommands()

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

	local originalGetIsPlayerValidForCommander
	originalGetIsPlayerValidForCommander = TGNS.ReplaceClassMethod("CommandStructure", "GetIsPlayerValidForCommander", function(playerValidSelf, player)
		local client = TGNS.GetClient(player)
		local result = originalGetIsPlayerValidForCommander(playerValidSelf, player)
		if result and enabled[client] then
			md:ToPlayerNotifyError(player, string.format("Execute sh_laps to disable Laps before entering the %s.", TGNS.GetTeamCommandStructureCommonName(TGNS.GetPlayerTeamNumber(player))))
			result = false
		end
		return result
	end)


    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("lapstracker", Plugin )
