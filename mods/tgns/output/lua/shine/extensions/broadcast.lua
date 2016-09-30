local supportedSimpleServerNames = {"Taunt", "Chuckle"}
local thisServerSimpleName

local dr = TGNSDataRepository.Create("broadcast", function(data)
	TGNS.DoFor(supportedSimpleServerNames, function(simpleServerName)
		data[simpleServerName] = data[simpleServerName] or {}
	end)
	return data
end)

local md = TGNSMessageDisplayer.Create("BROADCAST")

local function processNewMessageData()
	local dataWereProcessed = false
	dr.Load(nil, function(loadResponse)
		if loadResponse.success then
			local data = loadResponse.value
			local unprocessedMessageData = data[thisServerSimpleName]
			TGNS.DoFor(unprocessedMessageData, function(d)
				md:ToAllNotifyInfo(string.format("%s (%s): %s", d.senderName, d.fromServer, d.message))
				dataWereProcessed = true
			end)
			if dataWereProcessed then
				data[thisServerSimpleName] = {}
				dr.Save(data, nil, function(saveResponse)
					if not saveResponse.success then
						TGNS.DebugPrint(string.format("Broadcast ERROR: Unable to clear data. msg: %s | stacktrace: %s", saveResponse.msg, saveResponse.stacktrace))
					end
				end)
			end
		else
			TGNS.DebugPrint("broadcast ERROR: unable to access data.", true)
		end
	end)
end

local Plugin = {}

function Plugin:Broadcast(client, message)
	dr.Load(nil, function(loadResponse)
		if loadResponse.success then
			local data = loadResponse.value
			local senderName = TGNS.GetClientName(client)
			TGNS.DoFor(supportedSimpleServerNames, function(simpleServerName)
				if simpleServerName ~= thisServerSimpleName then
					data[simpleServerName] = data[simpleServerName] or {}
					table.insert(data[simpleServerName], {senderName=senderName, when=TGNS.GetSecondsSinceEpoch(), fromServer=thisServerSimpleName, message=message})
				end
			end)
			dr.Save(data, nil, function(saveResponse)
				if saveResponse.success then
					md:ToAllNotifyInfo(string.format("%s: %s", senderName, message))
				else
					md:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to send broadcast message.")
					TGNS.DebugPrint(string.format("Broadcast ERROR: Unable to save data. msg: %s | stacktrace: %s", saveResponse.msg, saveResponse.stacktrace))
				end
			end)
		else
			md:ToPlayerNotifyError(TGNS.GetPlayer(client), "Unable to access broadcast data.")
			TGNS.DebugPrint(string.format("Broadcast ERROR: Unable to access data. msg: %s | stacktrace: %s", loadResponse.msg, loadResponse.stacktrace))
		end
	end)
end

function Plugin:CreateCommands()
	local broadcastCommand = self:BindCommand( "sh_broadcast", "broadcast", function(client, message)
		local player = TGNS.GetPlayer(client)
		if message == nil or message == "" then
			md:ToPlayerNotifyError(player, "You must specify a message.")
		else
			self:Broadcast(client, message)
			TGNS.Log(string.format("%s executed sh_broadcast with message '%s'.", TGNS.GetClientNameSteamIdCombo(client), message))
		end
	end)
	broadcastCommand:AddParam{ Type = "string", TakeRestOfLine = true, Optional = true }
	broadcastCommand:Help( "<message> Broadcast message to all servers." )
end

function Plugin:Initialise()
    self.Enabled = true
	self:CreateCommands()
	TGNS.ScheduleAction(60, function() TGNS.ScheduleActionInterval(10, processNewMessageData) end)
	TGNS.ScheduleAction(10, function() thisServerSimpleName = TGNS.GetSimpleServerName() end)
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("broadcast", Plugin )