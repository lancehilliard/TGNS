//NS2 GUI Menu Base

Script.Load("lua/GUIScript.lua")

class 'GUIMenuBase' (GUIScript)

local kFontName = "fonts/AgencyFB_medium.fnt"
local kFontScale = GUIScale(Vector(1,1,0)) * 0.7
local kTextYOffset = GUIScale(-250)
local kTextYIncrement = GUIScale(25)
local kTextXOffset = GUIScale(75)
local kDescriptionTextXOffset = GUIScale(90)
local kUpdateLifetime = 10

local function OnSelectMenuOption(parm1)
	Shared.ConsoleCommand(string.format("menubaseselection %s", parm1))
end

//Hardcoded binds for extra slots :/
local function UpdateGUIMenu(slot)
	local GUIMenuBase = GetGUIManager():GetGUIScriptSingle("gui/GUIMenuBase")
	if GUIMenuBase then
		GUIMenuBase:ExternalKeyInputs(slot)
	end
end

local function slot6()
	UpdateGUIMenu("6")
end

Event.Hook("Console_slot6", slot6)

local function slot7()
	UpdateGUIMenu("7")
end

Event.Hook("Console_slot7", slot7)

local function slot8()
	UpdateGUIMenu("8")
end

Event.Hook("Console_slot8", slot8)

local function slot9()
	UpdateGUIMenu("9")
end

Event.Hook("Console_slot9", slot9)

local function slot0()
	UpdateGUIMenu("0")
end

Event.Hook("Console_slot0", slot0)

local bindings = LoadConfigFile("ConsoleBindings.json") or { }

if bindings["Num6"] == nil then
	Shared.ConsoleCommand("bind Num6 slot6")
end
if bindings["Num7"] == nil then
	Shared.ConsoleCommand("bind Num7 slot7")
end
if bindings["Num8"] == nil then
	Shared.ConsoleCommand("bind Num8 slot8")
end
if bindings["Num9"] == nil then
	Shared.ConsoleCommand("bind Num9 slot9")
end
if bindings["Num0"] == nil then
	Shared.ConsoleCommand("bind Num0 slot0")
end

function GUIMenuBase:Initialize()
	self.headerText = GUIManager:CreateTextItem()
    self.headerText:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.headerText:SetTextAlignmentX(GUIItem.Align_Min)
    self.headerText:SetTextAlignmentY(GUIItem.Align_Center)
    self.headerText:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 1), 0))
    self.headerText:SetInheritsParentAlpha(true)
    self.headerText:SetFontName(kFontName)
    self.headerText:SetScale(kFontScale)
    self.headerText:SetColor(Color(1,1,1,1))
	
	self.option1text = GUIManager:CreateTextItem()
    self.option1text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option1text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option1text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option1text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 2), 0))
    self.option1text:SetInheritsParentAlpha(true)
    self.option1text:SetFontName(kFontName)
    self.option1text:SetScale(kFontScale)
    self.option1text:SetColor(Color(1,1,1,1))
	
	self.option1desctext = GUIManager:CreateTextItem()
    self.option1desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option1desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option1desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option1desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 2), 0))
    self.option1desctext:SetInheritsParentAlpha(true)
    self.option1desctext:SetFontName(kFontName)
    self.option1desctext:SetScale(kFontScale)
    self.option1desctext:SetColor(Color(1,1,1,1))
	
	self.option2text = GUIManager:CreateTextItem()
    self.option2text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option2text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option2text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option2text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 3), 0))
    self.option2text:SetInheritsParentAlpha(true)
    self.option2text:SetFontName(kFontName)
    self.option2text:SetScale(kFontScale)
    self.option2text:SetColor(Color(1,1,1,1))
	
	self.option2desctext = GUIManager:CreateTextItem()
    self.option2desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option2desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option2desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option2desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 3), 0))
    self.option2desctext:SetInheritsParentAlpha(true)
    self.option2desctext:SetFontName(kFontName)
    self.option2desctext:SetScale(kFontScale)
    self.option2desctext:SetColor(Color(1,1,1,1))
	
	self.option3text = GUIManager:CreateTextItem()
    self.option3text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option3text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option3text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option3text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 4), 0))
    self.option3text:SetInheritsParentAlpha(true)
    self.option3text:SetFontName(kFontName)
    self.option3text:SetScale(kFontScale)
    self.option3text:SetColor(Color(1,1,1,1))
	
	self.option3desctext = GUIManager:CreateTextItem()
    self.option3desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option3desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option3desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option3desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 4), 0))
    self.option3desctext:SetInheritsParentAlpha(true)
    self.option3desctext:SetFontName(kFontName)
    self.option3desctext:SetScale(kFontScale)
    self.option3desctext:SetColor(Color(1,1,1,1))
	
	self.option4text = GUIManager:CreateTextItem()
    self.option4text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option4text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option4text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option4text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 5), 0))
    self.option4text:SetInheritsParentAlpha(true)
    self.option4text:SetFontName(kFontName)
    self.option4text:SetScale(kFontScale)
    self.option4text:SetColor(Color(1,1,1,1))
	
	self.option4desctext = GUIManager:CreateTextItem()
    self.option4desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option4desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option4desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option4desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 5), 0))
    self.option4desctext:SetInheritsParentAlpha(true)
    self.option4desctext:SetFontName(kFontName)
    self.option4desctext:SetScale(kFontScale)
    self.option4desctext:SetColor(Color(1,1,1,1))
	
	self.option5text = GUIManager:CreateTextItem()
    self.option5text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option5text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option5text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option5text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 6), 0))
    self.option5text:SetInheritsParentAlpha(true)
    self.option5text:SetFontName(kFontName)
    self.option5text:SetScale(kFontScale)
    self.option5text:SetColor(Color(1,1,1,1))
	
	self.option5desctext = GUIManager:CreateTextItem()
    self.option5desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option5desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option5desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option5desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 6), 0))
    self.option5desctext:SetInheritsParentAlpha(true)
    self.option5desctext:SetFontName(kFontName)
    self.option5desctext:SetScale(kFontScale)
    self.option5desctext:SetColor(Color(1,1,1,1))
	
	self.option6text = GUIManager:CreateTextItem()
    self.option6text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option6text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option6text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option6text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 7), 0))
    self.option6text:SetInheritsParentAlpha(true)
    self.option6text:SetFontName(kFontName)
    self.option6text:SetScale(kFontScale)
    self.option6text:SetColor(Color(1,1,1,1))
	
	self.option6desctext = GUIManager:CreateTextItem()
    self.option6desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option6desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option6desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option6desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 7), 0))
    self.option6desctext:SetInheritsParentAlpha(true)
    self.option6desctext:SetFontName(kFontName)
    self.option6desctext:SetScale(kFontScale)
    self.option6desctext:SetColor(Color(1,1,1,1))
	
	self.option7text = GUIManager:CreateTextItem()
    self.option7text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option7text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option7text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option7text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 8), 0))
    self.option7text:SetInheritsParentAlpha(true)
    self.option7text:SetFontName(kFontName)
    self.option7text:SetScale(kFontScale)
    self.option7text:SetColor(Color(1,1,1,1))
	
	self.option7desctext = GUIManager:CreateTextItem()
    self.option7desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option7desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option7desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option7desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 8), 0))
    self.option7desctext:SetInheritsParentAlpha(true)
    self.option7desctext:SetFontName(kFontName)
    self.option7desctext:SetScale(kFontScale)
    self.option7desctext:SetColor(Color(1,1,1,1))
	
	self.option8text = GUIManager:CreateTextItem()
    self.option8text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option8text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option8text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option8text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 9), 0))
    self.option8text:SetInheritsParentAlpha(true)
    self.option8text:SetFontName(kFontName)
    self.option8text:SetScale(kFontScale)
    self.option8text:SetColor(Color(1,1,1,1))
	
	self.option8desctext = GUIManager:CreateTextItem()
    self.option8desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option8desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option8desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option8desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 9), 0))
    self.option8desctext:SetInheritsParentAlpha(true)
    self.option8desctext:SetFontName(kFontName)
    self.option8desctext:SetScale(kFontScale)
    self.option8desctext:SetColor(Color(1,1,1,1))
	
	self.option9text = GUIManager:CreateTextItem()
    self.option9text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option9text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option9text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option9text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 10), 0))
    self.option9text:SetInheritsParentAlpha(true)
    self.option9text:SetFontName(kFontName)
    self.option9text:SetScale(kFontScale)
    self.option9text:SetColor(Color(1,1,1,1))
	
	self.option9desctext = GUIManager:CreateTextItem()
    self.option9desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option9desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option9desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option9desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 10), 0))
    self.option9desctext:SetInheritsParentAlpha(true)
    self.option9desctext:SetFontName(kFontName)
    self.option9desctext:SetScale(kFontScale)
    self.option9desctext:SetColor(Color(1,1,1,1))
	
	self.option10text = GUIManager:CreateTextItem()
    self.option10text:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option10text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option10text:SetTextAlignmentY(GUIItem.Align_Center)
    self.option10text:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 11), 0))
    self.option10text:SetInheritsParentAlpha(true)
    self.option10text:SetFontName(kFontName)
    self.option10text:SetScale(kFontScale)
    self.option10text:SetColor(Color(1,1,1,1))
	
	self.option10desctext = GUIManager:CreateTextItem()
    self.option10desctext:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.option10desctext:SetTextAlignmentX(GUIItem.Align_Min)
    self.option10desctext:SetTextAlignmentY(GUIItem.Align_Center)
    self.option10desctext:SetPosition(Vector(kDescriptionTextXOffset, kTextYOffset + (kTextYIncrement * 11), 0))
    self.option10desctext:SetInheritsParentAlpha(true)
    self.option10desctext:SetFontName(kFontName)
    self.option10desctext:SetScale(kFontScale)
    self.option10desctext:SetColor(Color(1,1,1,1))
	
	self.footerText = GUIManager:CreateTextItem()
    self.footerText:SetAnchor(GUIItem.Left, GUIItem.Middle)
    self.footerText:SetTextAlignmentX(GUIItem.Align_Min)
    self.footerText:SetTextAlignmentY(GUIItem.Align_Center)
    self.footerText:SetPosition(Vector(kTextXOffset, kTextYOffset + (kTextYIncrement * 12), 0))
    self.footerText:SetInheritsParentAlpha(true)
    self.footerText:SetFontName(kFontName)
    self.footerText:SetScale(kFontScale)
    self.footerText:SetColor(Color(1,1,1,1))
	
	self.option1text:SetText("1: = ")
	self.option2text:SetText("2: = ")
	self.option3text:SetText("3: = ")
	self.option4text:SetText("4: = ")
	self.option5text:SetText("5: = ")
	self.option6text:SetText("6: = ")
	self.option7text:SetText("7: = ")
	self.option8text:SetText("8: = ")
	self.option9text:SetText("9: = ")
	self.option10text:SetText("0: = ")
	
	self.headerText:SetIsVisible(false)
	self.option1text:SetIsVisible(false)
	self.option2text:SetIsVisible(false)
	self.option3text:SetIsVisible(false)
	self.option4text:SetIsVisible(false)
	self.option5text:SetIsVisible(false)
	self.option6text:SetIsVisible(false)
	self.option7text:SetIsVisible(false)
	self.option8text:SetIsVisible(false)
	self.option9text:SetIsVisible(false)
	self.option10text:SetIsVisible(false)
	self.option1desctext:SetIsVisible(false)
	self.option2desctext:SetIsVisible(false)
	self.option3desctext:SetIsVisible(false)
	self.option4desctext:SetIsVisible(false)
	self.option5desctext:SetIsVisible(false)
	self.option6desctext:SetIsVisible(false)
	self.option7desctext:SetIsVisible(false)
	self.option8desctext:SetIsVisible(false)
	self.option9desctext:SetIsVisible(false)
	self.option10desctext:SetIsVisible(false)
	self.footerText:SetIsVisible(false)
	
	self.options = { }
	self.options["header"] = self.headerText
	self.options["option1"] = self.option1desctext
	self.options["option2"] = self.option2desctext
	self.options["option3"] = self.option3desctext
	self.options["option4"] = self.option4desctext
	self.options["option5"] = self.option5desctext
	self.options["option6"] = self.option6desctext
	self.options["option7"] = self.option7desctext
	self.options["option8"] = self.option8desctext
	self.options["option9"] = self.option9desctext
	self.options["option10"] = self.option10desctext
	self.options["Hoption1"] = self.option1text
	self.options["Hoption2"] = self.option2text
	self.options["Hoption3"] = self.option3text
	self.options["Hoption4"] = self.option4text
	self.options["Hoption5"] = self.option5text
	self.options["Hoption6"] = self.option6text
	self.options["Hoption7"] = self.option7text
	self.options["Hoption8"] = self.option8text
	self.options["Hoption9"] = self.option9text
	self.options["Hoption10"] = self.option10text
	self.options["footer"] = self.footerText
	
	self.cachedupdate = { }
	self.cachedupdate["header"] = ""
	self.cachedupdate["option1"] = ""
	self.cachedupdate["option2"] = ""
	self.cachedupdate["option3"] = ""
	self.cachedupdate["option4"] = ""
	self.cachedupdate["option5"] = ""
	self.cachedupdate["option6"] = ""
	self.cachedupdate["option7"] = ""
	self.cachedupdate["option8"] = ""
	self.cachedupdate["option9"] = ""
	self.cachedupdate["option10"] = ""
	self.cachedupdate["footer"] = ""
	self.cachedupdate["inputallowed"] = "false"
	self.cachedupdate["menutime"] = 0
end

function GUIMenuBase:MenuUpdate(message)
	if message ~= nil then
		local parm = string.sub(message, 0, string.find(message,"|") - 1)
		local value = string.sub(message, string.find(message,"|") + 1)
		if parm == "menutime" and value == "0" then
			self:OnClose()
		elseif parm ~= nil or parm ~= "" then
			self.cachedupdate[parm] = value
			if parm == "menutime" or parm == "inputallowed" then
				if parm == "menutime" then
					self.cachedupdate["menutime"] = tonumber(value) or 0
				elseif parm == "inputallowed" then
					self.cachedupdate["inputallowed"] = value
				end
			elseif self.options[parm] ~= nil then
				self.options[parm]:SetText(value)
				self:UpdateDisplayedMenu(parm, value)
			end
		end
	end
end

function GUIMenuBase:Uninitialize()
    if self.headerText then
        GUI.DestroyItem(self.headerText)
        self.headerText = nil
    end
	if self.option1text then
        GUI.DestroyItem(self.option1text)
        self.option1text = nil
    end
	if self.option2text then
        GUI.DestroyItem(self.option2text)
        self.option2text = nil
    end
	if self.option3text then
        GUI.DestroyItem(self.option3text)
        self.option3text = nil
    end
	if self.option4text then
        GUI.DestroyItem(self.option4text)
        self.option4text = nil
    end
	if self.option5text then
        GUI.DestroyItem(self.option5text)
        self.option5text = nil
    end
	if self.option6text then
        GUI.DestroyItem(self.option6text)
        self.option6text = nil
    end
	if self.option7text then
        GUI.DestroyItem(self.option7text)
        self.option7text = nil
    end
	if self.option8text then
        GUI.DestroyItem(self.option8text)
        self.option8text = nil
    end
	if self.option9text then
        GUI.DestroyItem(self.option9text)
        self.option9text = nil
    end
	if self.option10text then
        GUI.DestroyItem(self.option10text)
        self.option10text = nil
    end
	if self.option1desctext then
        GUI.DestroyItem(self.option1desctext)
        self.option1desctext = nil
    end
	if self.option2desctext then
        GUI.DestroyItem(self.option2desctext)
        self.option2desctext = nil
    end
	if self.option3desctext then
        GUI.DestroyItem(self.option3desctext)
        self.option3desctext = nil
    end
	if self.option4desctext then
        GUI.DestroyItem(self.option4desctext)
        self.option4desctext = nil
    end
	if self.option5desctext then
        GUI.DestroyItem(self.option5desctext)
        self.option5desctext = nil
    end
	if self.option6desctext then
        GUI.DestroyItem(self.option6desctext)
        self.option6desctext = nil
    end
	if self.option7desctext then
        GUI.DestroyItem(self.option7desctext)
        self.option7desctext = nil
    end
	if self.option8desctext then
        GUI.DestroyItem(self.option8desctext)
        self.option8desctext = nil
    end
	if self.option9desctext then
        GUI.DestroyItem(self.option9desctext)
        self.option9desctext = nil
    end
	if self.option10desctext then
        GUI.DestroyItem(self.option10desctext)
        self.option10desctext = nil
    end
	if self.footerText then
        GUI.DestroyItem(self.footerText)
        self.footerText = nil
    end
end

function GUIMenuBase:UpdateDisplayedMenu(parm, value)
	if value ~= "" then
		if self.options["H" .. parm] ~= nil then
			self.options["H" .. parm]:SetIsVisible(true)
		end
		self.options[parm]:SetIsVisible(true)
	else
		if self.options["H" .. parm] ~= nil then
			self.options["H" .. parm]:SetIsVisible(false)
		end
		self.options[parm]:SetIsVisible(false)
	end
end

function GUIMenuBase:OnClose()
	self.headerText:SetIsVisible(false)
	self.option1text:SetIsVisible(false)
	self.option2text:SetIsVisible(false)
	self.option3text:SetIsVisible(false)
	self.option4text:SetIsVisible(false)
	self.option5text:SetIsVisible(false)
	self.option6text:SetIsVisible(false)
	self.option7text:SetIsVisible(false)
	self.option8text:SetIsVisible(false)
	self.option9text:SetIsVisible(false)
	self.option10text:SetIsVisible(false)
	self.option1desctext:SetIsVisible(false)
	self.option2desctext:SetIsVisible(false)
	self.option3desctext:SetIsVisible(false)
	self.option4desctext:SetIsVisible(false)
	self.option5desctext:SetIsVisible(false)
	self.option6desctext:SetIsVisible(false)
	self.option7desctext:SetIsVisible(false)
	self.option8desctext:SetIsVisible(false)
	self.option9desctext:SetIsVisible(false)
	self.option10desctext:SetIsVisible(false)
	self.footerText:SetIsVisible(false)
	self.cachedupdate["header"] = ""
	self.cachedupdate["option1"] = ""
	self.cachedupdate["option2"] = ""
	self.cachedupdate["option3"] = ""
	self.cachedupdate["option4"] = ""
	self.cachedupdate["option5"] = ""
	self.cachedupdate["option6"] = ""
	self.cachedupdate["option7"] = ""
	self.cachedupdate["option8"] = ""
	self.cachedupdate["option9"] = ""
	self.cachedupdate["option10"] = ""
	self.cachedupdate["footer"] = ""
	self.cachedupdate["inputallowed"] = "false"
	self.cachedupdate["menutime"] = 0
end

function GUIMenuBase:Update(deltaTime)
	if self.cachedupdate ~= nil and self.cachedupdate["menutime"] + kUpdateLifetime < Shared.GetTime() then
		self:OnClose()
	end
end

function GUIMenuBase:SendKeyEvent(key, down)
	
	if self.cachedupdate ~= nil and self.cachedupdate["inputallowed"] == "true" and down then
		local optselect
		if GetIsBinding(key, "Weapon1") and self.cachedupdate["option1"] ~= nil then
			optselect = 1
		elseif GetIsBinding(key, "Weapon2") and self.cachedupdate["option2"] ~= nil then
			optselect = 2
		elseif GetIsBinding(key, "Weapon3") and self.cachedupdate["option3"] ~= nil then
			optselect = 3
		elseif GetIsBinding(key, "Weapon4") and self.cachedupdate["option4"] ~= nil then
			optselect = 4
		elseif GetIsBinding(key, "Weapon5") and self.cachedupdate["option5"] ~= nil then
			optselect = 5
		end
		if optselect then
			OnSelectMenuOption(optselect)
			self.cachedupdate["inputallowed"] = "false"
			return true
		end
	end
	
end

function GUIMenuBase:ExternalKeyInputs(key)
	
	if self.cachedupdate ~= nil and self.cachedupdate["inputallowed"] == "true" then
		local optselect
		if key == "6" and self.cachedupdate["option6"] ~= nil then
			optselect = 6
		elseif key == "7" and self.cachedupdate["option7"] ~= nil then
			optselect = 7
		elseif key == "8" and self.cachedupdate["option8"] ~= nil then
			optselect = 8
		elseif key == "9" and self.cachedupdate["option9"] ~= nil then
			optselect = 9
		elseif key == "0" and self.cachedupdate["option10"] ~= nil then
			optselect = 10
		end
		if optselect then
			OnSelectMenuOption(optselect)
			self.cachedupdate["inputallowed"] = "false"
			return true
		end
	end
	
end