//NS2 GUI Vote Base

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

local function OnCommandMenuUpdate(MenuBaseUpdateMessage)
	self.lastupdate = MenuBaseUpdateMessage
	Print(ToString(MenuBaseUpdateMessage))
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
    self.votemenu = GUIManager:CreateGraphicItem()
    self.votemenu:SetSize(GUIMenuBase.kBgSize)
    self.votemenu:SetAnchor(GUIItem.Middle, GUIItem.Center)
    self.votemenu:SetPosition(GUIMenuBase.kBgPosition)
    self.votemenu:SetTexture(texture)
    self.votemenu:SetTexturePixelCoordinates(unpack(kBackgroundPixelCoords))
    self.votemenu:SetColor(Color(1,1,1,0))
	
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
	
    self.votemenu:AddChild(self.headerText)
	self.votemenu:AddChild(self.option1text)
	self.votemenu:AddChild(self.option2text)
	self.votemenu:AddChild(self.option3text)
	self.votemenu:AddChild(self.option4text)
	self.votemenu:AddChild(self.option5text)
	self.votemenu:AddChild(self.option1desctext)
	self.votemenu:AddChild(self.option2desctext)
	self.votemenu:AddChild(self.option3desctext)
	self.votemenu:AddChild(self.option4desctext)
	self.votemenu:AddChild(self.option5desctext)
	self.votemenu:AddChild(self.footerText)
	
	self.votemenu:SetIsVisible(false)
	self.lastupdate = nil
	self.lastupdatetime = 0
	self.menuvisible = false
end

function GUIMenuBase:Uninitialize()
    if self.votemenu then
        GUI.DestroyItem(self.votemenu)
        self.votemenu = nil
    end
end

function GUIMenuBase:DisplayUpdate()
    if self.lastupdate ~= nil then
		self.menuvisible = true
        self.votemenu:SetIsVisible(self.menuvisible)
    end
end

function GUIMenuBase:OnClose()
	self.menuvisible = false
	self.votemenu:SetIsVisible(self.menuvisible)
	self.lastupdate = nil
end

function GUIMenuBase:Update(deltaTime)
	if self.lastupdate ~= nil then
		if self.lastupdate.votetime < Shared.GetTime() + GUIMenuBase.kUpdateLifetime then
			self:OnClose()
		else
			if self.lastupdate.votetime > self.lastupdatetime then
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
				self.lastupdatetime = self.lastupdate.votetime
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
//local kVoteBaseUpdateMessage = 
//{
//	header         		= string.format("string (%d)", kMaxVoteStringLength),
//	option1         	= string.format("string (%d)", kMaxVoteStringLength),
//	option1desc         = string.format("string (%d)", kMaxVoteStringLength),
//	option2        		= string.format("string (%d)", kMaxVoteStringLength),
//	option2desc         = string.format("string (%d)", kMaxVoteStringLength),
//	option3        		= string.format("string (%d)", kMaxVoteStringLength),
//	option3desc         = string.format("string (%d)", kMaxVoteStringLength),
//	option4        		= string.format("string (%d)", kMaxVoteStringLength),
//	option4desc         = string.format("string (%d)", kMaxVoteStringLength),
//	option5         	= string.format("string (%d)", kMaxVoteStringLength),
//	option5desc         = string.format("string (%d)", kMaxVoteStringLength),
//	footer         		= string.format("string (%d)", kMaxVoteStringLength),
//  inputallowed		= "boolean",
//	votetime   	  		= "time"
//}

