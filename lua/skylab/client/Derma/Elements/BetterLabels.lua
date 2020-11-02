local fontBank = {}

local label = {}

function label:Init()
    self.text = ""

    self.orientation = TEXT_ALIGN_LEFT 

    self.textColor = Color(255,255,255)

    self.textOffset = 0

    self.font = {
        w = 0,
        h = 0,
        s = 0,
        n = "",
        an = ""
    }

    self:SetFont("Consolas", 14)
end

function label:SetText(t)
    t = t or ""
    
    if t:find("\n") then 
        t = string.Split(t, "\n")[1] -- No \n allowed in normal Labels!
    end

    self.text = t 
end

function label:GetText(t)
    return self.text 
end

function label:SetTextColor(color)
    if not color or type(color) ~= "table" then return end 
    self.textColor = color 
end

function label:GetTextColor()
    return self.textColor 
end

function label:SetTextOffset(offset)
    if offset == nil then return end
    self.textOffset = offset  
end

function label:GetTextOffset()
    return self.textOffset 
end

function label:SetOrientation(orientation)
    if orientation < 0 or orientation > 4 then return end 
    self.orientation = orientation
end

function label:GetOrientation()
    return self.orientation
end

function label:SetFont(font, size)
    if not font then return end 

    size = size or self.font.s 

    local id = "Bet.Lab.Fon." .. font .. "_" .. size
 
    local data = {
        font      = font,
        size      = size,
        weight    = 500
    }

    fontBank[id] = data 

    surface.CreateFont(id, data)
    surface.SetFont(id)

    local w, h  = surface.GetTextSize(" ") 

    self.font.w = w
    self.font.h = h 
    self.font.n = id 
    self.font.an = font 
    self.font.s = size 
end

function label:GetTextSize()
    surface.SetFont(self.font.n)
    local w, h = surface.GetTextSize(self.text)
    return w, h 
end

function label:GetTextWidth()
    local w, _ = self:GetTextSize()
    return w
end
function label:GetTextWidth()
    local _, h = self:GetTextSize()
    return h
end
function label:GetFont()
    return self.font.n 
end

function label:GetFontSuper()
    return self.font.an 
end

function label:GetFontWidth()
    return self.font.w 
end

function label:GetFontHeight()
    return self.font.h 
end

function label:SizeToContents()
    local textW = #self.text * self.font.w  
    local textH = self.font.h 

    if self.orientation == TEXT_ALIGN_LEFT or self.orientation == TEXT_ALIGN_RIGHT then 
        textW = textW + self.textOffset 
    end 

    if self.orientation == TEXT_ALIGN_TOP or self.orientation == TEXT_ALIGN_BOTTOM then 
        textH = textH + self.textOffset 
    end   

    self:SetSize(textW, textH)
end

function label:PaintBefore() end 
function label:PaintAfter() end 

function label:Paint(w, h)
    self:PaintBefore(w, h)

    local textW, textH = self:GetTextSize()

    if not textW or not textH then return end 

    local x, y

    if self.orientation == TEXT_ALIGN_CENTER then
        x = w / 2 - textW / 2
        y = h / 2 - textH / 2
    elseif self.orientation == TEXT_ALIGN_LEFT then
        x = self.textOffset 
        y = h / 2 - textH / 2
    elseif self.orientation == TEXT_ALIGN_RIGHT then
        x = w - self.textOffset - textW  
        y = h / 2 - textH / 2
    elseif self.orientation == TEXT_ALIGN_TOP then
        x = w / 2 - textW / 2
        y = self.textOffset 
    elseif self.orientation == TEXT_ALIGN_BOTTOM then
        x = w / 2 - textW / 2
        y = h - self.textOffset - textH  
    else return end 

    draw.SimpleText(self.text, self.font.n, x, y, self.textColor)

    self:PaintAfter(w, h)
end

vgui.Register("BetterLabel", label, "DSleekPanel")