--[[
    Custom Derma Button

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

if not SSLE then 
    MsgC(Color(255,0,0), "Couldn't mount Custom Button.") 
	return 
end

local button = {}

local function dark(n)
    return Color(n,n,n)
end

local function GetFontSize(name)
    surface.SetFont(name)
    return surface.GetTextSize(" ")
end

local function oAlpha(color, a)
    local temp = table.Copy(color)
    temp.a = a 
    return temp
end

local function oColor(color, r,g,b,a)
    local temp = table.Copy(color)
    temp.r = r or temp.r 
    temp.g = g or temp.g 
    temp.b = b or temp.b 
    temp.a = a or temp.a 
    return temp 
end

local function oAll(color, depth)
    return oColor(color, depth,depth,depth)
end

local function mAll(color, mult)
    local temp = {}
    temp.r = math.Clamp(color.r * mult, color.r, 255) 
    temp.g = math.Clamp(color.g * mult, color.g, 255) 
    temp.b = math.Clamp(color.b * mult, color.b, 255) 
    return temp 
end

local function vAvg(color)
    return (color.r + color.g + color.b) / 3
end

local function gStrongest(color)
    local r = color.r 
    if color.g > r then r = color.g end
    if color.b > r then r = color.r end
    return r 
end

local function curve(X)
    return -(X ^ math.pi) + 1
end

B_LAYOUT_RIGHT  = 0
B_LAYOUT_LEFT   = 1
B_LAYOUT_TOP    = 2
B_LAYOUT_BOTTOM = 4
B_LAYOUT_NONE = 8

function button:Init()
    self:SetCursor("hand")

    --- Config ---
    self.colors.background = dark(45)
    self.colors.outline = dark(70)
    self.colors.foreground = dark(255)
    self.colors.border     = Color(0,255,255)
    self.boundsMargin    = 1
    self.imageSizeOffset = 0
    self.borderFadeSpeed = 8
    self.pulsationSpeed  = 15 
    self.hoverstrength   = 1.75
    self.clickstrength   = 1.75
    self.clickfadespeed  = 2
    --------------

    self.image = nil 
    self.pulse = {false, 0} 
    self.bgfade = 0
    self.text = ""
    self.font = {
        w = 0,
        h = 0,
        n = "",
        an = ""
    }

    self.textX = 0
    self.textY = 0

    self.imagelayout = B_LAYOUT_NONE
    self.allignToText = true 

    self.lastFrame = RealTime()
    self.lastClickTiming = RealTime()

    self:SetFont("Consolas", 14)
end

function button:OnClick(delay, code) end 
function button:PaintCustom(w, h) end

function button:DoClick()
    self:Pulsate()
    self:OnClick(RealTime() - self.lastClickTiming)
    self.lastClickTiming = RealTime()
end

function button:SetText(text)
    if not text then return end 
    self.text = text 
end

function button:GetText()
    return self.text 
end

function button:SetImageSizeOffset(status)
    if not status then return end 
    self.imageSizeOffset = status 
    self.image:Dock(NODOCK)
end

function button:SetMaterial(material, size, layout)
    self.image = vgui.Create("DImage", self)
    self.image:SetMaterial(material)
    self:SetImageSizeOffset(size)
    if not self.image then self:SetImageTextLayout(B_LAYOUT_LEFT) end 
end

function button:SetImage(URI, size, layout)
    self.image = vgui.Create("DImage", self)
    self.image:SetImage(URI)
    self:SetImageSizeOffset(size)
    if not self.image then self:SetImageTextLayout(B_LAYOUT_LEFT) end 
end

function button:SetImageTextLayout(layout, nextToText)
    if not layout then return end 
    if nextToText == nil then nextToText = true end 
    self.allignToText = nextToText
    self.imagelayout = layout 
end

function button:RemoveImage()
    self.image:Remove()
end

function button:GetImage()
    return self.image:GetImage()
end

function button:SetFont(font, size)
    size = size or 16
    font = font or "Consolas"
    local n = "SLFDTB"..font..size 
    local data = {
        font      = font,
        size      = size,
        weight    = 500
    }
    surface.CreateFont(n, data)
    surface.SetFont(n)
    local w, h  = surface.GetTextSize(" ")
    self.font.w  = w
    self.font.h  = h 
    self.font.n  = n 
    self.font.an = font 
end

function button:Pulsate()
    self.bgfade = 150
    self.pulse = {true, RealTime()} 
end

function button:SizeToContents()
    local cH = self.font.h 

    if IsValid(self.image) == true and cH < self.image:GetTall() then 
        cH = self.image:GetTall()
    end

    local cW
    if not self.imagelayout or self.imagelayout == B_LAYOUT_NONE then 
        if IsValid(self.image) == true then 
            cW = self.image:GetWide() / 2 
        else
            cW = self.font.w * #self.text + self.font.w * 2
        end 
    else 
        cW = self.font.w * #self.text + self.image:GetWide() / 2 + self.imageSizeOffset * 2 
    end

    self:SetSize(cW, cH)
end

function button:OnMousePressed(code)
    self:OnClick(RealTime() - self.lastClickTiming, code)
    if code ~= MOUSE_LEFT then return end 
    self:Pulsate()
    self.lastClickTiming = RealTime()
    self:KillFocus()
end

function button:PaintText(w, h)
    local textWidth = #self.text * self.font.w 
    local textHeight = self.font.h 

    if self.imagelayout ~= B_LAYOUT_NONE and IsValid(self.image) == true then 
        local izo = self.imageSizeOffset 

        if self.allignToText == true then 
            izo = izo / 2
        end

        local iw  = self.image:GetWide() + izo
        local ih  = self.image:GetTall() + izo
              
        if self.imagelayout == B_LAYOUT_LEFT then 
            textWidth = textWidth - iw 
        elseif self.imagelayout == B_LAYOUT_RIGHT then 
            textWidth = textWidth + iw 
        elseif self.imagelayout == B_LAYOUT_BOTTOM then 
            textHeight = textHeight + ih 
        elseif self.imagelayout == B_LAYOUT_TOP then 
            textHeight = textHeight - ih 
        end
    elseif IsValid(self.image) == false then  
        textWidth = textWidth + self.font.w / 2
    end

    local x, y = (w / 2 - textWidth / 2), (h / 2 - textHeight / 2)

    draw.SimpleText(self.text, self.font.n, x, y, Color(255,255,255))

    self.textX = x 
    self.textY = y 
end

function button:PerformLayout(w, h)
    local wh 

    if w > h then wh = h else wh = w end 

    wh = wh - self.imageSizeOffset

    if self.image then 
        self.image:SetSize(wh,wh)

        if self.imagelayout == B_LAYOUT_NONE then 
            self.image:SetPos(w / 2 - self.image:GetWide() / 2, h / 2 - self.image:GetTall() / 2)
            return 
        end

        local iW, iH = self.image:GetSize()

        if self.allignToText == false then 
            if self.imagelayout == B_LAYOUT_LEFT then 
                self.image:SetPos(self.imageSizeOffset, h / 2 - wh / 2)
            elseif self.imagelayout == B_LAYOUT_RIGHT then 
                self.image:SetPos(w - self.imageSizeOffset - iW, h / 2 - wh / 2)
            elseif self.imagelayout == B_LAYOUT_BOTTOM then 
                self.image:SetPos(w / 2 - wh / 2, h - self.imageSizeOffset - iH)
            elseif self.imagelayout == B_LAYOUT_TOP then 
                self.image:SetPos(w / 2 - wh / 2, self.imageSizeOffset)
            end
        else 
            if self.imagelayout == B_LAYOUT_LEFT then 
                self.image:SetPos(self.textX - self.imageSizeOffset - iW, h / 2 - wh / 2)
            elseif self.imagelayout == B_LAYOUT_RIGHT then 
                self.image:SetPos(self.textX + (#self.text * self.font.w) + self.imageSizeOffset, h / 2 - wh / 2)
            elseif self.imagelayout == B_LAYOUT_BOTTOM then 
                self.image:SetPos(w / 2 - wh / 2, self.textY + self.imageSizeOffset)
            elseif self.imagelayout == B_LAYOUT_TOP then 
                self.image:SetPos(w / 2 - wh / 2, self.textY - self.imageSizeOffset - self.font.h)
            end
        end
    end
end

function button:Paint(w, h)
    self.isDown = false 

    local frameDelay = 1 + (RealTime() - self.lastFrame) * 1.5
    local fadeSpeed  = self.borderFadeSpeed * frameDelay 

    -- Background
    draw.RoundedBox(0, 0, 0, w, h, self.colors.background)

    draw.RoundedBox(0,0,0,w,h,oAlpha(self.colors.border, self.bgfade))
    draw.RoundedBox(0,0,0,w,h,oAlpha(self.colors.outline, 255 - self.bgfade))

    local bFrame = false

    if self.pulse[1] == false then 
        if self:HasFocus() == true then      
            if self.bgfade < 255 then 
                self.bgfade = self.bgfade + fadeSpeed
            end
        elseif self:IsHovered() then 
            if self.bgfade < 150 then 
                self.bgfade = math.min(self.bgfade + fadeSpeed, 150)
            elseif self.bgfade > 150 then 
                self.bgfade = self.bgfade - fadeSpeed
            end
        elseif self.bgfade > 0 then 
            self.bgfade = self.bgfade - fadeSpeed
        end

        do 
            local c = mAll(self.colors.background, self.bgfade / 100)
            draw.RoundedBox(0, self.boundsMargin, self.boundsMargin, w - self.boundsMargin * 2, h - self.boundsMargin * 2, c)
        end
    else
        local y = 1 

        if input.IsMouseDown(MOUSE_LEFT) == true and self:IsHovered() == true then 
            self.isDown = true 
        else 
            y = math.max(curve((RealTime() - self.pulse[2]) * self.clickfadespeed), 0)
        end

        do 
            local c = mAll(self.colors.background, (self.bgfade / 100))
            c = mAll(c, (self.clickstrength * y))

            draw.RoundedBox(0, self.boundsMargin, self.boundsMargin, w - self.boundsMargin * 2, h - self.boundsMargin * 2, c)
        end

        if y <= 0 then 
            self.lastFrame = self.pulse[2]
            self:KillFocus()
            self.pulse[1] = false 
            bFrame = true
        end
    end 

    if (self.imagelayout == B_LAYOUT_NONE and IsValid(self.image)) == false then 
        self:PaintText(w, h)
    end

    self:PaintCustom(w, h)

    if bFrame == true then return end 

    self.lastFrame = RealTime()
end

function button:IsDown() 
    if self.isDown == nil then return false end
    return self.isDown 
end 

vgui.Register("DSleekButton", button, "DSleekPanel")

