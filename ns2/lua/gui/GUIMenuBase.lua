//NS2 GUI Menu Base

Script.Load("lua/GUIScript.lua")

class 'GUIMenuBase' (GUIScript)

local kScale = 1.2

GUIMenuBase.kFontName = "fonts/AgencyFB_medium.fnt"
GUIMenuBase.kFontScale = GUIScale(Vector(1,1,0)) * 0.7

GUIMenuBase.kBgSize = GUIScale(Vector(230, 50, 0)) * kScale

GUIMenuBase.kTextYOffset = GUIScale(6) * kScale
GUIMenuBase.kTextYIncrement = GUIScale(2) * kScale
GUIMenuBase.kTextXOffset = GUIScale(10) * kScale
GUIMenuBase.kDescriptionTextXOffset = GUIScale(15) * kScale

GUIMenuBase.kUpdateLifetime = 5

GUIMenuBase.kBgPosition = Vector(GUIMenuBase.kBgSize.x * -.5, GUIScale(-150) * kScale, 0)

local kBackgroundPixelCoords = { 0, 0, 230, 50 }
local kForegroundPixelCoords = { 0, 50, 230, 100 }

local function OnCommandMenuUpdate(MenuBaseUpdateMessage)
	local GUIMenuBase = GetGUIManager():GetGUIScriptSingle("gui/GUIMenuBase")
	if GUIMenuBase then
		GUIMenuBase:MenuUpdate(MenuBaseUpdateMessage)
	end
end

Client.HookNetworkMessage("GUIMenuBase", OnCommandMenuUpdate)

local function OnCommandMenuBase(parm1)
	local idNum = tonumber(parm1)
	if idNum ~= nil then
		Client.SendNetworkMessage("GUIMenuBaseSelected", { optionselected = idNum }, true)
	end
end

Event.Hook("Console_menubase", OnCommandMenuBase)

function GUIMenuBase:Initialize()
    self.mainmenu = GUIManager:CreateGraphicItem()
    self.mainmenu:SetSize(GUIMenuBase.kBgSize)
    self.mainmenu:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.mainmenu:SetPosition(GUIMenuBase.kBgPosition)
    self.mainmenu:SetTexture(texture)
    self.mainmenu:SetTexturePixelCoordinates(unpack(kBackgroundPixelCoords))
    self.mainmenu:SetColor(Color(1,1,1,0))
	
	self.headerText = GUIManager:CreateTextItem()
    self.headerText:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.headerText:SetTextAlignmentX(GUIItem.Align_Center)
    self.headerText:SetTextAlignmentY(GUIItem.Align_Min)
    self.headerText:SetPosition(Vector(GUIMenuBase.kTextXOffset, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 1), 0))
    self.headerText:SetInheritsParentAlpha(true)
    self.headerText:SetFontName(GUIMenuBase.kFontName)
    self.headerText:SetScale(GUIMenuBase.kFontScale)
    self.headerText:SetColor(Color(1,1,1,1))
	
	self.option1text = GUIManager:CreateTextItem()
    self.option1text:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option1text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option1text:SetTextAlignmentY(GUIItem.Align_Min)
    self.option1text:SetPosition(Vector(GUIMenuBase.kTextXOffset, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 2), 0))
    self.option1text:SetInheritsParentAlpha(true)
    self.option1text:SetFontName(GUIMenuBase.kFontName)
    self.option1text:SetScale(GUIMenuBase.kFontScale)
    self.option1text:SetColor(Color(1,1,1,1))
	
	self.option1desctext = GUIManager:CreateTextItem()
    self.option1desctext:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option1desctext:SetTextAlignmentX(GUIItem.Align_Center)
    self.option1desctext:SetTextAlignmentY(GUIItem.Align_Min)
    self.option1desctext:SetPosition(Vector(GUIMenuBase.kDescriptionTextXOffset, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 2), 0))
    self.option1desctext:SetInheritsParentAlpha(true)
    self.option1desctext:SetFontName(GUIMenuBase.kFontName)
    self.option1desctext:SetScale(GUIMenuBase.kFontScale)
    self.option1desctext:SetColor(Color(1,1,1,1))
	
	self.option2text = GUIManager:CreateTextItem()
    self.option2text:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option2text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option2text:SetTextAlignmentY(GUIItem.Align_Min)
    self.option2text:SetPosition(Vector(GUIMenuBase.kTextXOffset, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 3), 0))
    self.option2text:SetInheritsParentAlpha(true)
    self.option2text:SetFontName(GUIMenuBase.kFontName)
    self.option2text:SetScale(GUIMenuBase.kFontScale)
    self.option2text:SetColor(Color(1,1,1,1))
	
	self.option2desctext = GUIManager:CreateTextItem()
    self.option2desctext:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option2desctext:SetTextAlignmentX(GUIItem.Align_Center)
    self.option2desctext:SetTextAlignmentY(GUIItem.Align_Min)
    self.option2desctext:SetPosition(Vector(GUIMenuBase.kDescriptionTextXOffset, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 3), 0))
    self.option2desctext:SetInheritsParentAlpha(true)
    self.option2desctext:SetFontName(GUIMenuBase.kFontName)
    self.option2desctext:SetScale(GUIMenuBase.kFontScale)
    self.option2desctext:SetColor(Color(1,1,1,1))
	
	self.option3text = GUIManager:CreateTextItem()
    self.option3text:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option3text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option3text:SetTextAlignmentY(GUIItem.Align_Min)
    self.option3text:SetPosition(Vector(0, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 4), 0))
    self.option3text:SetInheritsParentAlpha(true)
    self.option3text:SetFontName(GUIMenuBase.kFontName)
    self.option3text:SetScale(GUIMenuBase.kFontScale)
    self.option3text:SetColor(Color(1,1,1,1))
	
	self.option3desctext = GUIManager:CreateTextItem()
    self.option3desctext:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option3desctext:SetTextAlignmentX(GUIItem.Align_Center)
    self.option3desctext:SetTextAlignmentY(GUIItem.Align_Min)
    self.option3desctext:SetPosition(Vector(0, GUIMenuBase.kDescriptionTextXOffset + (GUIMenuBase.kTextYIncrement * 4), 0))
    self.option3desctext:SetInheritsParentAlpha(true)
    self.option3desctext:SetFontName(GUIMenuBase.kFontName)
    self.option3desctext:SetScale(GUIMenuBase.kFontScale)
    self.option3desctext:SetColor(Color(1,1,1,1))
	
	self.option4text = GUIManager:CreateTextItem()
    self.option4text:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option4text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option4text:SetTextAlignmentY(GUIItem.Align_Min)
    self.option4text:SetPosition(Vector(0, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 5), 0))
    self.option4text:SetInheritsParentAlpha(true)
    self.option4text:SetFontName(GUIMenuBase.kFontName)
    self.option4text:SetScale(GUIMenuBase.kFontScale)
    self.option4text:SetColor(Color(1,1,1,1))
	
	self.option4desctext = GUIManager:CreateTextItem()
    self.option4desctext:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option4desctext:SetTextAlignmentX(GUIItem.Align_Center)
    self.option4desctext:SetTextAlignmentY(GUIItem.Align_Min)
    self.option4desctext:SetPosition(Vector(0, GUIMenuBase.kDescriptionTextXOffset + (GUIMenuBase.kTextYIncrement * 5), 0))
    self.option4desctext:SetInheritsParentAlpha(true)
    self.option4desctext:SetFontName(GUIMenuBase.kFontName)
    self.option4desctext:SetScale(GUIMenuBase.kFontScale)
    self.option4desctext:SetColor(Color(1,1,1,1))
	
	self.option5text = GUIManager:CreateTextItem()
    self.option5text:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option5text:SetTextAlignmentX(GUIItem.Align_Center)
    self.option5text:SetTextAlignmentY(GUIItem.Align_Min)
    self.option5text:SetPosition(Vector(0, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 6), 0))
    self.option5text:SetInheritsParentAlpha(true)
    self.option5text:SetFontName(GUIMenuBase.kFontName)
    self.option5text:SetScale(GUIMenuBase.kFontScale)
    self.option5text:SetColor(Color(1,1,1,1))
	
	self.option5desctext = GUIManager:CreateTextItem()
    self.option5desctext:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.option5desctext:SetTextAlignmentX(GUIItem.Align_Center)
    self.option5desctext:SetTextAlignmentY(GUIItem.Align_Min)
    self.option5desctext:SetPosition(Vector(0, GUIMenuBase.kDescriptionTextXOffset + (GUIMenuBase.kTextYIncrement * 6), 0))
    self.option5desctext:SetInheritsParentAlpha(true)
    self.option5desctext:SetFontName(GUIMenuBase.kFontName)
    self.option5desctext:SetScale(GUIMenuBase.kFontScale)
    self.option5desctext:SetColor(Color(1,1,1,1))
	
	self.footerText = GUIManager:CreateTextItem()
    self.footerText:SetAnchor(GUIItem.Middle, GUIItem.Top)
    self.footerText:SetTextAlignmentX(GUIItem.Align_Center)
    self.footerText:SetTextAlignmentY(GUIItem.Align_Min)
    self.footerText:SetPosition(Vector(0, GUIMenuBase.kTextYOffset + (GUIMenuBase.kTextYIncrement * 7), 0))
    self.footerText:SetInheritsParentAlpha(true)
    self.footerText:SetFontName(GUIMenuBase.kFontName)
    self.footerText:SetScale(GUIMenuBase.kFontScale)
    self.footerText:SetColor(Color(1,1,1,1))
	
    self.mainmenu:AddChild(self.headerText)
	self.mainmenu:AddChild(self.option1text)
	self.mainmenu:AddChild(self.option2text)
	self.mainmenu:AddChild(self.option3text)
	self.mainmenu:AddChild(self.option4text)
	self.mainmenu:AddChild(self.option5text)
	self.mainmenu:AddChild(self.option1desctext)
	self.mainmenu:AddChild(self.option2desctext)
	self.mainmenu:AddChild(self.option3desctext)
	self.mainmenu:AddChild(self.option4desctext)
	self.mainmenu:AddChild(self.option5desctext)
	self.mainmenu:AddChild(self.footerText)
	
	self.mainmenu:SetIsVisible(false)
	self.lastupdate = nil
	self.lastupdatetime = 0
	self.menuvisible = false
end

function GUIMenuBase:MenuUpdate(MenuBaseUpdateMessage)
	self.lastupdate = MenuBaseUpdateMessage
end

function GUIMenuBase:Uninitialize()
    if self.mainmenu then
        GUI.DestroyItem(self.mainmenu)
        self.mainmenu = nil
    end
end

function GUIMenuBase:DisplayUpdate()
    if self.lastupdate ~= nil then
		self.menuvisible = true
        self.mainmenu:SetIsVisible(self.menuvisible)
    end
end

function GUIMenuBase:OnClose()
	self.menuvisible = false
	self.mainmenu:SetIsVisible(self.menuvisible)
	self.lastupdate = nil
end

function GUIMenuBase:Update(deltaTime)
	if self.lastupdate ~= nil then
		if self.lastupdate.menutime < Shared.GetTime() + GUIMenuBase.kUpdateLifetime then
			self:OnClose()
		else
			if self.lastupdate.menutime > self.lastupdatetime then
				self.headerText:SetText(self.lastupdate.header)
				self.option1text:SetText(self.lastupdate.option1)
				self.option2text:SetText(self.lastupdate.option2)
				self.option3text:SetText(self.lastupdate.option3)
				self.option4text:SetText(self.lastupdate.option4)
				self.option5text:SetText(self.lastupdate.option5)
				self.option1desctext:SetText(self.lastupdate.option1desc)
				self.option2desctext:SetText(self.lastupdate.option2desc)
				self.option3desctext:SetText(self.lastupdate.option3desc)
				self.option4desctext:SetText(self.lastupdate.option4desc)
				self.option5desctext:SetText(self.lastupdate.option5desc)
				self.footerText:SetText(self.lastupdate.footer)
				self.lastupdatetime = self.lastupdate.menutime
				Print(ToString(self.lastupdatetime))
				self:DisplayUpdate()
			end
		end
	end
	
end

function GUIMenuBase:OverrideInput(input)

	if self.lastupdate ~= nil and self.lastupdate.inputallowed then
		local weaponSwitchCommands = { Move.Weapon1, Move.Weapon2, Move.Weapon3, Move.Weapon4, Move.Weapon5 }
		for index, weaponSwitchCommand in ipairs(weaponSwitchCommands) do
		
			if bit.band(input.commands, weaponSwitchCommand) ~= 0 then
				OnCommandMenuBase(index)
				local removeWeaponMask = bit.bxor(0xFFFFFFFF, weaponSwitchCommand)
				input.commands = bit.band(input.commands, removeWeaponMask)
				self:OnClose()
				break
				
			end
			
		end  
	end
    return input

end    

//GUIMenuBase
//local kMenuBaseUpdateMessage = 
//{
//	header         		= string.format("string (%d)", kMaxMenuStringLength),
//	option1         	= string.format("string (%d)", kMaxMenuStringLength),
//	option1desc         = string.format("string (%d)", kMaxMenuStringLength),
//	option2        		= string.format("string (%d)", kMaxMenuStringLength),
//	option2desc         = string.format("string (%d)", kMaxMenuStringLength),
//	option3        		= string.format("string (%d)", kMaxMenuStringLength),
//	option3desc         = string.format("string (%d)", kMaxMenuStringLength),
//	option4        		= string.format("string (%d)", kMaxMenuStringLength),
//	option4desc         = string.format("string (%d)", kMaxMenuStringLength),
//	option5         	= string.format("string (%d)", kMaxMenuStringLength),
//	option5desc         = string.format("string (%d)", kMaxMenuStringLength),
//	footer         		= string.format("string (%d)", kMaxMenuStringLength),
//  inputallowed		= "boolean",
//	menutime   	  		= "time"
//}

