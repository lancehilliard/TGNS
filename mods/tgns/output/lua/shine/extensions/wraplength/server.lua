local md
local pdr
local lastSentLength = {}

local function updateClientWraplength(client, wraplength)
	TGNS.SendNetworkMessageToPlayer(TGNS.GetPlayer(client), Shine.Plugins.wraplength.WRAPLENGTH_DATA, {l=wraplength})
	lastSentLength[client] = wraplength
end

local function getWraplengthDescription(client, wraplengthData)
	local length = wraplengthData.wraplength ~= nil and wraplengthData.wraplength or lastSentLength[client]
	local result = (length == nil or length == 0) and "Using default wrapping (25%%)." or string.format("Wrap length is currently %s%%.", length)
	return result
end

-- function Plugin:ClientConfirmConnect(client)
-- 	TGNS.ScheduleAction(3, function()
-- 		if Shine:IsValidClient(client) then
-- 			pdr:Load(TGNS.GetClientSteamId(client), function(loadResponse)
-- 				if loadResponse.success then
-- 					local length = loadResponse.value.wraplength
-- 					if length ~= nil then
-- 						updateClientWraplength(client, length)
-- 						md:ToClientConsole(client, getWraplengthDescription(client, loadResponse.value))
-- 					end
-- 				else
-- 					Shared.Message(string.format("wraplength ERROR: Unable to access data for %s", TGNS.GetClientNameSteamIdCombo(client)))
-- 				end
-- 			end)
-- 		end
-- 	end)
-- end

function Plugin:ClientConnect(client)
	pdr:Load(TGNS.GetClientSteamId(client), function(loadResponse)
		if loadResponse.success then
			local length = loadResponse.value.wraplength
			if length ~= nil then
				updateClientWraplength(client, length)
				md:ToClientConsole(client, getWraplengthDescription(client, loadResponse.value))
			end
		else
			Shared.Message(string.format("wraplength ERROR: Unable to access data for %s", TGNS.GetClientNameSteamIdCombo(client)))
		end
	end)
end

local function showHelp(client)
	md:ToClientConsole(client, "Help: sh_help sh_wraplength")
end

function Plugin:CreateCommands()
	local wraplengthCommand = self:BindCommand( "sh_wraplength", nil, function(client, lengthCandidate)
		pdr:Load(TGNS.GetClientSteamId(client), function(loadResponse)
			local wraplengthData = loadResponse.value
			if loadResponse.success then
				local length = tonumber(lengthCandidate)
				if length == nil then
					md:ToClientConsole(client, getWraplengthDescription(client, wraplengthData))
					showHelp(client)
				elseif length ~= 0 and length < self.MINIMUM_CHAT_WIDTH_PERCENTAGE then
					md:ToClientConsole(client, string.format("Lowest allowable non-zero length percentage is %s. %s", self.MINIMUM_CHAT_WIDTH_PERCENTAGE, getWraplengthDescription(client, wraplengthData)))
					showHelp(client)
				elseif length > self.MAXIMUM_CHAT_WIDTH_PERCENTAGE then
					md:ToClientConsole(client, string.format("Highest allowable length percentage is %s. %s", self.MAXIMUM_CHAT_WIDTH_PERCENTAGE, getWraplengthDescription(client, wraplengthData)))
					showHelp(client)
				else
					wraplengthData.wraplength = length == 0 and nil or length
					pdr:Save(wraplengthData, function(saveResponse)
						if saveResponse.success then
							updateClientWraplength(client, length)
							md:ToClientConsole(client, getWraplengthDescription(client, wraplengthData))
							showHelp(client)
						else
							md:ToClientConsole(client, string.format("Unable to save wrap length percentage (you did everything right). %s", getWraplengthDescription(client, wraplengthData)))
							showHelp(client)
							Shared.Message(string.format("wraplength ERROR: Unable to save data for %s", TGNS.GetClientNameSteamIdCombo(client)))
						end
					end)
				end
			else
				md:ToClientConsole(client, string.format("Unable to access or change wrap length percentage (you did everything right). %s", getWraplengthDescription(client, wraplengthData)))
				showHelp(client)
				Shared.Message(string.format("wraplength ERROR: Unable to access data for %s", TGNS.GetClientNameSteamIdCombo(client)))
			end
		end)
	end, true)
	wraplengthCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	wraplengthCommand:Help(string.format("<length percentage> To default: 0; Min: %s; Max: %s", self.MINIMUM_CHAT_WIDTH_PERCENTAGE, self.MAXIMUM_CHAT_WIDTH_PERCENTAGE))
end

function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()
    md = TGNSMessageDisplayer.Create("WRAPLENGTH")
    pdr = TGNSPlayerDataRepository.Create("wraplength", function(data)
		data.wraplength = data.wraplength ~= nil and data.wraplength or nil
		return data
	end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end