local Plugin = Plugin

TGNS.HookNetworkMessage(Plugin.RECORDING_BOUNDARY, function(message)
	local latestTrhVersionDescriptor = "v0.10"
	local url = string.format("http://localhost:8467/tgns/record_%s?m=%s&b=%s&i=%s&n=%s&t=%s&d=%s&team=%s", message.b, TGNS.GetCurrentMapName(), Shared.GetBuildNumber(), Client.GetSteamId(), TGNS.UrlEncode(message.p), message.s, message.d, TGNS.UrlEncode(message.t))
	Shared.Message("url: " .. tostring(url))
	Shared.SendHTTPRequest(url, "GET", function(responseJson)
		local response = json.decode(responseJson) or {}
		if response.showIcon then
			TGNS.SendNetworkMessage(Shine.Plugins.scoreboard.REQUEST_STREAMING_ICON, {u="http://rr.tacticalgamer.com/Replay"})
		end
		if response.trhVersion then
			if response.trhVersion ~= latestTrhVersionDescriptor then
				Shared.Message(string.format("[TRH] http://rr.tacticalgamer.com/Replay/RecordingHelper has TGNS Recording Helper update (%s).", latestTrhVersionDescriptor))
			end
			if response.casterMode then
				Shared.ConsoleCommand("plus castermode true")
			else
				Shared.ConsoleCommand("plus castermode false")
			end
		end
	end)
end)

function Plugin:Initialise()
	self.Enabled = true
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end