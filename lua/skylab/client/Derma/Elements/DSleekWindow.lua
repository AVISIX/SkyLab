--[[
    Custom DFrame using garry code as base

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]


if not SSLE then 
	return 
end

local function dark(i)
    return Color(i,i,i)
end

local function oAlpha(color, a)
    local temp = table.Copy(color)
    temp.a = a 
    return temp
end

local window = {}

function window:Init()
	self.colors = {}
	self.colors.background = dark(35)

	self:ShowCloseButton(false)

	self.btnClose = vgui.Create("DSleekButton", self)
	self.btnClose:SetImage("icon16/cross.png", 7.5)
	self.btnClose:SetFont("Consolas", 25)
	local parent = self 
	self.btnClose.OnClick = function(self, delay)
		if (parent:OnClose() or true) == true then 
			parent:Close()
		end 
	end

	self.doubleClickFullScreen = true 
	self.resizeOnBoundsHit = true 
	self.sebc = true 

	self:SetSize(250,250)

	self.lastSize = {}
end

function window:SetEnableBoundariesClamp(status)
	self.sebc = status 
end

function window:SetEnableResizeOnBoundsHit(status)
	self.resizeOnBoundsHit = status 
end

function window:SetAllowedDoubleClickFullscreen(status)
	self.doubleClickFullScreen = status 
end

function window:BeforeClose() end 

function window:Close()
	self:BeforeClose()
	self:SetVisible( false )
	if ( self:GetDeleteOnClose() ) then
		self:Remove()
	end
end

function window:Paint(w, h)
	if self.sebc == true then 
		local x, y = self:GetPos()
        x = math.Clamp(x, 0, ScrW() - w)
        y = math.Clamp(y, 0, ScrH() - h)
        self:SetPos(x, y)
	end

	draw.RoundedBox(0,0,0,w,h,self.colors.background)

	do 
		local x, y = self.btnClose:GetPos()
		local w, h = self.btnClose:GetSize()
		draw.RoundedBox(0, x - 1, y - 1, w + 2, h + 2, oAlpha(dark(255),10))
	end 
end
  
function window:IsFullScreen()
	local w, h = self:GetSize()
	return w == ScrW() and h == ScrH()
end

function window:OnMouseReleased()
	self.Dragging = nil
	self.Sizing = nil
	self:MouseCapture( false )

	if self:IsFullScreen() == true then return end 

	local mx, my = input.GetCursorPos()

	if mx <= 0 then 
		self:AssTicTac(ScrW() / 2, ScrH(),0,0)
	elseif mx >= ScrW() - 1 then 
		self:AssTicTac(ScrW() / 2, ScrH(),ScrW() / 2,0)
	elseif my <= 0 then 
		self:AssTicTac(ScrW(), ScrH() / 2,0,0)
	elseif my >= ScrH() - 1 then 
		self:AssTicTac(ScrW(), ScrH() / 2,0,ScrH() / 2)
	end
end

function window:AssTicTac(w, h, x, y)
	self.lastSize.w = self:GetWide()
	self.lastSize.h = self:GetTall()

	local x, y = self:GetPos()
	self.lastSize.x = x 
	self.lastSize.y = y 

	self:SetSize(w, h)

	if x and y then 
		self:SetPos(x, y)
	end
end

function window:IsCornered()
	local x, y = self:GetPos()
	local w, h = self:GetSize()
	if x <= 0 or x >= ScrW() - 1 then return true end
	if y <= 0 or y >= ScrH() - 1 then return true end
end

function window:OnMousePressed(code) 
	self:RequestFocus()

	if self.lastClick and RealTime() - self.lastClick <= 0.2 and self.doubleClickFullScreen == true then 
		if self:IsFullScreen() or self:IsCornered() then 
			self:SetSize(self.lastSize.w, self.lastSize.h)
			self:SetPos(self.lastSize.x, self.lastSize.y)
		else 
			self:AssTicTac(ScrW(), ScrH(),0,0)
		end
	end

	self.lastClick = RealTime() 

	-- Garry code 
	local screenX, screenY = self:LocalToScreen( 0, 0 )

	if ( self.m_bSizable && gui.MouseX() > ( screenX + self:GetWide() - 20 ) && gui.MouseY() > ( screenY + self:GetTall() - 20 ) ) then
		self.Sizing = { gui.MouseX() - self:GetWide(), gui.MouseY() - self:GetTall() }
		self:MouseCapture( true )
		return
	end

	if ( self:GetDraggable() && gui.MouseY() < ( screenY + 24 ) ) then
		self.Dragging = { gui.MouseX() - self.x, gui.MouseY() - self.y }
		self:MouseCapture( true )
		return
	end
end

-- Modified Garry code lol
function window:PerformLayout(w, h)
	local titlePush = 0

	if ( IsValid( self.imgIcon ) ) then

		self.imgIcon:SetPos( 5, 5 )
		self.imgIcon:SetSize( 16, 16 )
		titlePush = 16

	end

	self.btnClose:SetPos( self:GetWide() - 45 - 5.5, 3.99999 )
	self.btnClose:SetSize( 45, 22 )

	self.lblTitle:SetPos( 8 + titlePush, 2 )
	self.lblTitle:SetSize( self:GetWide() - 25 - titlePush, 20 )
end

vgui.Register("DSleekWindow", window, "DFrame")