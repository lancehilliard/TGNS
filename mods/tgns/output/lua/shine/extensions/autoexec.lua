local pdr = TGNSPlayerDataRepository.Create("autoexec", function(data)
	data.commands = data.commands ~= nil and data.commands or {}
	return data
end)

local md = TGNSMessageDisplayer.Create("AUTOFPS")

//local function ShowCurrentCommands(client)
//	local steamId = TGNS.GetClientSteamId(client)
//	local data = pdr:Load(steamId)
//	md:ToClientConsole(client, "")
//	md:ToClientConsole(client, "Your current commands:")
//	TGNS.DoFor(data.commands, function(c)
//		md:ToClientConsole(client, string.format("    %s", c))
//	end)
//	md:ToClientConsole(client, "")
//	md:ToClientConsole(client, " * Re-specifying any existing command will remove it from the list.")
//	md:ToClientConsole(client, "")
//end
//
//local function ShowUsage(client)
//	md:ToClientConsole(client, "")
//	md:ToClientConsole(client, " Usage:")
//	md:ToClientConsole(client, "     sv_autoexec <command>")
//	md:ToClientConsole(client, " Notes:")
//	md:ToClientConsole(client, " * Configured commands execute only when you connect as a Supporting Member")
//	md:ToClientConsole(client, "")
//	ShowCurrentCommands(client)
//	md:ToClientConsole(client, "")
//end

local Plugin = {}

function Plugin:CreateCommands()
	local autofpsCommand = self:BindCommand("sh_autofps", "autofps", function(client)
		local steamId = TGNS.GetClientSteamId(client)
		pdr:Load(steamId, function(loadResponse)
			if loadResponse.success then
				local data = loadResponse.value
				local message
				if TGNS.Has(data.commands, "fps") then
					TGNS.RemoveAllMatching(data.commands, "fps")
					message = "You have toggled off the FPS counter automatic display."
				else
					table.insert(data.commands, "fps")
					message = "You have toggled on the FPS counter automatic display."
				end
				pdr:Save(data, function(saveResponse)
					if saveResponse.success then
						md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), message)
					else
						md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Unable to save player data.")
					end
				end)
			else
				md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Unable to access player data.")
			end
		end)
	end, true)
	autofpsCommand:Help("Toggle FPS counter automatic display.")
end

function Plugin:ClientConfirmConnect(client)
	local steamId = TGNS.GetClientSteamId(client)
	pdr:Load(steamId, function(loadResponse)
		if loadResponse.success then
			local data = loadResponse.value
			TGNS.DoFor(data.commands, function(command)
				TGNS.SendClientCommand(client, command)
			end)
		else
			md:ToPlayerNotifyInfo(TGNS.GetPlayer(client), "Unable to access player data.")
		end
	end)
end

function Plugin:Initialise()
    self.Enabled = true
    self:CreateCommands()
    return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end

Shine:RegisterExtension("autoexec", Plugin )