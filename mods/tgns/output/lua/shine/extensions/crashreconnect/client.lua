local Plugin = Plugin

local usableConnectionAt = 0
local queriedServerStatusAt = 0
local reconnectingText
local reconnectAlreadyInProgress

local function hideConnectionProblemsIcon(guiIssuesDisplay)
	guiIssuesDisplay.connectionProblemsIcon:SetIsVisible(false)
	GUIIssuesDisplay.Update = function() end
end

function Plugin:SetReconnectAlreadyInProgress()
	reconnectAlreadyInProgress = true
end

function Plugin:Initialise()
	self.Enabled = true

	local originalGUIIssuesDisplayUpdate = GUIIssuesDisplay.Update
	GUIIssuesDisplay.Update = function(guiIssuesDisplaySelf, deltaTime)
		originalGUIIssuesDisplayUpdate(guiIssuesDisplaySelf, deltaTime)

		if reconnectAlreadyInProgress then
			if guiIssuesDisplaySelf.connectionProblemsIcon then
				hideConnectionProblemsIcon(guiIssuesDisplaySelf)
			end
		else
		    if guiIssuesDisplaySelf.connectionProblemsIcon and guiIssuesDisplaySelf.connectionProblemsIcon:GetIsVisible() then
		    	local connectionProblemsIconColor = guiIssuesDisplaySelf.connectionProblemsIcon:GetColor()
		    	local connectionProblemsIconIsRed = connectionProblemsIconColor.r == 1 and connectionProblemsIconColor.g == 0 and connectionProblemsIconColor.b == 0
			    if connectionProblemsIconIsRed then
			    	local secondsSinceUsableConnection = Shared.GetTime() - usableConnectionAt
			    	if secondsSinceUsableConnection >= 3 then
			    		if reconnectingText == nil then
			    			reconnectingText = Shine.ScreenText.Add( "Reconnecting", {
								X = 0.05, Y = 0.55,
								Text = "Checking to see if game server crashed.\n\n(Check your Internet connection, too.)",
								Duration = math.huge,
								R = 0, G = 255, B = 0,
								Alignment = 0,
								Size = 3,
								FadeIn = 0.5
							} )
			    		end
			    		local secondsSinceServerQuery = Shared.GetTime() - queriedServerStatusAt
			    		if secondsSinceServerQuery > 1.5 then
				    		queriedServerStatusAt = Shared.GetTime()
							Shared.SendHTTPRequest("http://rr.tacticalgamer.com/ServerInfo/v1_0", "GET", function(responseJson)
								local response = json.decode(responseJson) or {}
								if #response > 0 then
									local serverInfo = response[1]
									if serverInfo.mapName == "dev_test" and #serverInfo.players < 8 then
										Shine.Plugins.serverstart:Reconnect()
										hideConnectionProblemsIcon(guiIssuesDisplaySelf)
										if reconnectingText then
											function reconnectingText:UpdateText()
												self.Obj:SetText("Game server crashed. Reconnecting now. Please wait.")
											end
										end
									else
										-- Shared.Message("DEBUG mapName: " .. tostring(serverInfo.mapName))
									end
								end
							end)
			    		end
			    	end
			    else
			    	usableConnectionAt = Shared.GetTime()
			    	Shine.ScreenText.Remove( "Reconnecting" )
			    	reconnectingText = nil
			    end
		    else
		    	usableConnectionAt = Shared.GetTime()
		    	Shine.ScreenText.Remove( "Reconnecting" )
		    	reconnectingText = nil
		    end
		end

	end

	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end