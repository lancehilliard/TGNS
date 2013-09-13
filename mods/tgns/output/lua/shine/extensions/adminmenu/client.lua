local Plugin = Plugin

local tgnsMenuDisplayer
local helpTexts = {}

local function getPageNameHelpText(pageName)
	local result = helpTexts[pageName]
	return result
end

function Plugin:Initialise()
	self.Enabled = true
	tgnsMenuDisplayer = TGNSMenuDisplayer.Create(function(menu)
		menu:EditPage("Main", function(x)
			x:AddPage("Info", "Info", {"Choose an option to learn more about this server, called \"TGNS\"."}, "Main")
			x:EditPage("Info", function(y)
				y:AddSideButton("TGNS Primer", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/190765-read-sign-tgns-primer-print.html", "TGNS Primer")
				end)
				y:AddSideButton("TGNS Forums", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection/", "http://www.tacticalgamer.com/natural-selection/")
				end)
				y:AddSideButton("Scoreboard Letters", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194304-scoreboard-letters-print.html", "Scoreboard Letters")
				end)
			end)
			x:AddSideButton("Info", function()
				x:SetPage("Info")
			end)
		end)
	end)
	TGNS.HookNetworkMessage(self.MAIN_BUTTONS_REQUESTED, function(message)
		tgnsMenuDisplayer = TGNSMenuDisplayer.Create(function(menu)
			menu:EditPage("Main", function(x)
				x:AddSideButton(message.pageName, function()
					TGNS.SendNetworkMessage(self.ADMIN_MENU_REQUESTED, {commandIndex=0, argName=message.pageName, argValue=""})
				end)
			end)
		end)
	end)
	TGNS.HookNetworkMessage(self.HELP_TEXT, function(message)
		helpTexts[message.pageName] = message.helpText
	end)
	TGNS.HookNetworkMessage(self.MENU_DATA, function(message)
		local argName = message.argName
		local pageId = message.pageId
		local pageName = message.pageName
		local backPageId = message.backPageId
		local chatCmd = message.chatCmd
		local pageNameHelpText = getPageNameHelpText(pageName)
		local helpText = TGNS.HasNonEmptyValue(pageNameHelpText) and pageNameHelpText or string.format("%s%s -- Help in console: sh_help %s", pageName, (TGNS.HasNonEmptyValue(chatCmd) and string.format(" (chat: !%s)", chatCmd) or ""), pageName)
		local buttons = json.decode(message.buttonsJson)
		tgnsMenuDisplayer = TGNSMenuDisplayer.Create(function(menu)
			if TGNS.HasNonEmptyValue(backPageId) then
				menu:AddPage(pageId, pageName, {helpText}, backPageId)
				menu:EditPage(pageId, function(x)
					TGNS.DoFor(buttons, function(b)
						x:AddSideButton(b.n, function()
							TGNS.SendNetworkMessage(self.ADMIN_MENU_REQUESTED, {commandIndex=b.c, argName=argName, argValue=TGNS.HasNonEmptyValue(b.v) and b.v or b.n})
						end)
					end)
				end)
				menu:SetPage(pageId)
			else
				menu:Finish()
			end
		end)
	end)
	return true
end

function Plugin:Cleanup()
    --Cleanup your extra stuff like timers, data etc.
    self.BaseClass.Cleanup( self )
end