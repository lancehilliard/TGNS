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
				y:AddSideButton("TGNS Rules", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-official-rules-announcements/190764-what-rules-server-print.html", "TGNS Rules (also: see TGNS Primer and forum's Required Reading)")
				end)
				y:AddSideButton("TGNS Forums", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection/", "http://www.tacticalgamer.com/natural-selection/")
				end)
				y:AddSideButton("Contact an Admin", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-official-rules-announcements/106028-contact-ns-admin-print.html", "Contact an Admin")
				end)
				y:AddSideButton("Scoreboard Letters", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194304-scoreboard-letters-print.html", "Scoreboard Letters")
				end)
				y:AddSideButton("Reserved Slots", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194548-tgns-reserved-slots-logic-print.html", "Reserved Slots")
				end)
				y:AddSideButton("Seeding with Bots", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194563-bots-seed-accelerator-print.html", "Seeding with Bots")
				end)
				y:AddSideButton("sh_affirm", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194559-sh_affirm-affirming-stranger-print.html", "sh_affirm")
				end)
				y:AddSideButton("Chat Enhancements", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194568-chat-enhancements-print.html", "Chat Enhancements")
				end)
				y:AddSideButton("Captains Games", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194547-captains-games-print.html", "Captains Games")
				end)
				y:AddSideButton("sh_help", function()
					TGNS.ShowUrl("http://www.tacticalgamer.com/natural-selection-general-discussion/194574-sh_help-print.html", "sh_help")
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