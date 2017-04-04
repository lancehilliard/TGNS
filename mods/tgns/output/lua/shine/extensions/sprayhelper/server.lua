Plugin.HasConfig = false
-- Plugin.ConfigName = "sprayhelper.json"

local lastSprays = {}
local md = TGNSMessageDisplayer.Create("SPRAYS")
local fetchedSprays = {}

function Plugin:ClientConfirmConnect(client)
	TGNS.DoFor(fetchedSprays, function(s)
		if s.exists == nil then
			s.exists = GetFileExists(s.path)
		end
		if s.exists then
			TGNS.ScheduleAction(0, function()
				if Shine:IsValidClient(client) then
					TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), "SH_readyroomrave_CreateSpray", { originX = s.x, originY = s.y, originZ = s.z, yaw = s.yaw, pitch = s.pitch, roll = s.roll, path = s.path })
				end
			end)
		end
	end)
end

local function storeLastSpray(client, path, x, y, z, yaw, roll, pitch)
	local spray = {}
	spray.mapName = TGNS.GetCurrentMapName()
	spray.path = path
	spray.x = x
	spray.y = y
	spray.z = z
	spray.yaw = yaw
	spray.roll = roll
	spray.pitch = pitch
	spray.playerid = TGNS.GetClientSteamId(client)
	lastSprays[client] = spray
end

local function updateFetchedSprays()
	local url = string.format("%s&m=%s", TGNS.Config.SpraysEndpointBaseUrl, TGNS.UrlEncode(TGNS.GetCurrentMapName()))
	TGNS.GetHttpAsync(url, function(responseJson)
		local response = json.decode(responseJson) or {}
		if response.success then
			fetchedSprays = TGNS.Select(response.sprays, function(s)
				s.mapName = TGNS.GetCurrentMapName()
				return s
			end)
		else
			TGNS.DebugPrint(string.format("sprayhelper ERROR: Unable to get sprays. msg: %s | response: %s | stacktrace: %s | url: %s", response.msg, responseJson, response.stacktrace, url), not TGNS.IsProduction())
		end
	end)
end

function Plugin:PlayerSay(client, networkMessage)
	if TGNS.IsClientReadyRoom(client) then
		-- local teamOnly = networkMessage.teamOnly
		local message = StringTrim(networkMessage.message)
		if TGNS.ToLower(message) == "keep" then
			local player = TGNS.GetPlayer(client)
			if TGNS.IsClientSM(client) then
				local spray = lastSprays[client]
				if spray then
					if TGNS.Contains(spray.path, TGNS.GetClientSteamId(client)) then
						local clientName = TGNS.GetClientName(client)
						local url = string.format("%s&mapName=%s&path=%s&x=%s&y=%s&z=%s&yaw=%s&roll=%s&pitch=%s&playerid=%s", TGNS.Config.SpraysEndpointBaseUrl, TGNS.UrlEncode(spray.mapName), TGNS.UrlEncode(spray.path), TGNS.UrlEncode(spray.x), TGNS.UrlEncode(spray.y), TGNS.UrlEncode(spray.z), TGNS.UrlEncode(spray.yaw), TGNS.UrlEncode(spray.roll), TGNS.UrlEncode(spray.pitch), TGNS.UrlEncode(spray.playerid))
						TGNS.GetHttpAsync(url, function(responseJson)
							local response = json.decode(responseJson) or {}
							if response.success then
								if TGNS.IsGameInProgress() then
									md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Spray kept. It will appear at all times for all players.")
								else
									md:ToAllNotifyInfo(string.format("Spray kept for %s (and removed from other Ready Rooms). It will appear here at all times for all players.", clientName))
								end
								lastSprays[client] = nil
								updateFetchedSprays()
							else
								md:ToPlayerNotifyError(player, "Spray not kept. Unexpected error.")
								TGNS.DebugPrint(string.format("sprayhelper ERROR: Unable to persist spray. msg: %s | response: %s | stacktrace: %s | url: %s", response.msg, responseJson, response.stacktrace, url))
							end
						end)
					else
						md:ToPlayerNotifyError(player, "Only personalized sprays may be kept on the game server. Create a CAA thread to submit your personalized spray image.")
						return ""
					end
				else
					md:ToPlayerNotifyError(player, "No new spray. Spray and try again.")
					return ""
				end
			else
				md:ToPlayerNotifyError(player, "Only Supporting Members may keep sprays on the server.")
				return ""
			end
		end
	end
end

function Plugin:Initialise()
    self.Enabled = true
    -- self:CreateCommands()

	TGNS.ScheduleAction(5, function()
		local md = TGNSMessageDisplayer.Create()
		if Shine.Commands.sh_sound then
			Shine.Commands.sh_sound.Func = function(client)
				md:ToPlayerNotifyError(TGNS.GetPlayer(client), "This feature is not available.")
			end
		end
		if Shine.Commands.sh_rave then
			Shine.Commands.sh_rave.Func = function(client)
				md:ToPlayerNotifyError(TGNS.GetPlayer(client), "This feature is not available.")
			end
		end
		if Shine.Commands.sh_spray then
			local originalSprayFunc = Shine.Commands.sh_spray.Func
			Shine.Commands.sh_spray.Func = function(client)
				if TGNS.IsClientReadyRoom(client) then
					local originalShineGetUserData = Shine.GetUserData
					Shine.GetUserData = function(shineSelf, getUserDataClient)
						local userData = {}
						userData.Decal = {}
						local steamId = TGNS.GetClientSteamId(client)
						local customPath = string.format("ui/sprays/%s.material", steamId)
						local materialPath = (TGNS.IsClientSM(client) and GetFileExists(customPath)) and customPath or "ui/sprays/tgns.material"
						table.insert(userData.Decal, materialPath)
						return userData, getUserDataClient
					end
					local originalGetEntitiesWithinRange = GetEntitiesWithinRange
					GetEntitiesWithinRange = function(className, origin, range)
						if className == "Player" then
							range = 10000
						end
						return originalGetEntitiesWithinRange(className, origin, range)
					end
					local originalSendNetworkMessage = Shine.Plugins.readyroomrave.SendNetworkMessage
					Shine.Plugins.readyroomrave.SendNetworkMessage = function(raveSelf, player, messageName, messageTable, reliable)
						storeLastSpray(client, messageTable.path, messageTable.originX, messageTable.originY, messageTable.originZ, messageTable.yaw, messageTable.roll, messageTable.pitch)
						originalSendNetworkMessage(raveSelf, player, messageName, messageTable, reliable)
					end
					originalSprayFunc(client)
					GetEntitiesWithinRange = originalGetEntitiesWithinRange
					Shine.GetUserData = originalShineGetUserData
					Shine.Plugins.readyroomrave.SendNetworkMessage = originalSendNetworkMessage
				end
			end
		end
	end)

	TGNS.HookNetworkMessage(self.SPRAY_REQUESTED, function(client)
		if Shine.Commands.sh_spray then
			Shine.Commands.sh_spray.Func(client)
		end
	end)


	TGNS.DoWithConfig(updateFetchedSprays)

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end