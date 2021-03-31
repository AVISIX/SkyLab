include("slabtest/client/utils.lua")

local self = {}

function self:Init()    
    local super = self 


    self.colors = {}
    self.colors.background = dark(225)


    self.scroller = vgui.Create("DVScrollBar", self)
    self.scroller:Dock(RIGHT)
    self.scroller.Dragging = false
    self.scroller.super = self 


    self.entry = vgui.Create("TextEntry", self)
    self.entry:SetSize(0,0)
    self.entry:SetMultiline(true)
    self.entry.OnLoseFocus = function(self) super:_FocusLost() end
    self.entry.OnTextChanged = function(self) super:_TextChanged() end
    self.entry.OnKeyCodeTyped = function(self, code) super:_KeyCodePressed(code) end
    self.entry.OnKeyCodeReleased = function(self, code) super:_KeyCodeReleased(code) end

    self.textColor = Color(255,255,255)
    self:SetFont("Consolas", 16)

    self.lines = {}

    self.textPos = 
    {
        char = 1,
        line = 1
    }

    self:SetCursor("beam")
end

function self:_FocusLost()

end

function self:_TextChanged()
    self.entry:SetText("")
end

function self:_KeyCodePressed(code)

end

function self:_KeyCodeReleased(code)

end

local fontBank = {}
function self:SetFont(name, size)
    if not name then return end 

    local newFont 
    local data 

    if type(name) == "table" then 
        data = table.Copy(name) 
        name = data.font 
        size = math.Clamp(data.size, 8, 48)

        newFont = "SSLEF" .. name  .. size

        if not fontBank[newFont] then
            surface.CreateFont(newFont, data)
            fontBank[newFont] = data 
        end 
    else 
        size = size or 16 
        size = math.Clamp(size, 8, 48)

        newFont = "SSLEF" .. name  .. size

        if not fontBank[newFont] then
            data = 
            {
                font      = name,
                size      = size,
                weight    = 520 
            }

            surface.CreateFont(newFont, data)

            fontBank[newFont] = data 
        end 
    end

    surface.SetFont(newFont)

    local w, h = surface.GetTextSize(" ")

    fontBank[newFont].width  = w 
    fontBank[newFont].height = h 
    
    self.font = 
    {
        w = w,
        h = h,
        n = newFont,
        an = name,
        s = size,
        data = data 
    }
end

function self:SetTextColor(char, line, length, color)
    if not char or not line or not length or not color then return end 

end

function self:MakeToken(text)
    if not text then return nil end 

    local temp = {}

    temp.text   = text 
    temp.color  = table.Copy(self.textColor)
    temp.font   = table.Copy(self.font)
    
    function temp:GetWidth() 
        return fontBank[self.font.n].width * #self.text
    end
    
    function temp:GetHeight()
        return fontBank[self.font.n].height
    end

    return temp 
end

local IDCounter = 1
function self:MakeLine()
    local temp = {}
    temp.id = IDCounter
    temp.tokens = {}
    IDCounter = IDCounter + 1
    return temp 
end

function self:TokenAtPos(char, line)
    if not char or not line then return end 
    if not self.lines[line] then return end 

    local cc = 0
    for k, v in ipairs(self.lines[line].tokens) do 
        cc = cc + #v.text
        if char <= cc then return v end 
    end
end

function self:AddText(char, line, text)
    if not char then return end 
    
    if not line and not text then 
        text = char 
        char = 1
        line = 1 
    end

    line = math.Clamp(line, 1, #self.lines + 1)
    if self.lines[line] then 
        char = math.Clamp(char, 1, self.lines[line]:GetLength())
    else 
        char = 1
    end

    if not self.lines[line] then self.lines[line] = self:MakeLine() end 

    local lines = string.Split(text, "\n")

    table.insert(self.lines[line].tokens, self:MakeToken(lines[1])) -- add tokens to the current line 

    for i = line + 1, i < #lines, 1 do 

    end

end

function self:RemoveText(char, line, length)
    if not char or not line or not length then return end 

end

function self:Paint(w, h)

end

function self:Think(w, h)

end

vgui.Register("SleekRichTextBox", self, "DPanel")
