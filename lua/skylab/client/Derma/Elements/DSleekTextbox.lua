--[[
    Custom Derma Textbox

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

local textbox = {}

local function isUpper(char)  
    if not char or char == "" then return false end 
    local n = string.byte(char)
    return n >= 65 and n <= 90 
end

local function isLower(char)  
    if not char or char == "" then return false end 
    local n = string.byte(char)
    return n >= 97 and n <= 122 
end

local function isNumber(char) 
    if not char or char == "" then return false end 
    local n = string.byte(char)
    return n >= 48 and n <= 57 
end

local function isLetter(char)
    return isLower(char) == true or isUpper(char) == true or isNumber(char) == true 
end

local function isSpecial(char)
    return isNumber(char) == false and isLower(char) == false and isUpper(char) == false 
end 

local function dark(n)
    return Color(n,n,n)
end

local function GetFontSize(name)
    surface.SetFont(name)
    return surface.GetTextSize(" ")
end

local function limitString(str, font, max)
    local w, h = GetFontSize(font)

    do 
        return str 
    end 

    local result = ""

    if #str * w > max then 
        result = ".." .. string.sub(str, -(max / w) + 2, #str)
    end

    return result 
end

local function insert(text, word, index)
    if not text or not word or not index then return "" end 
    return string.sub(text, 1, index) .. word .. string.sub(text, index + 1, #text)
end

local function remove(text, start, ending)
    if not text or not start or not ending then return "" end 
    return string.sub(text, 1, start) .. string.sub(text, ending + 1, #text)
end

local function sub(text, start, ending)
    if not text or not ending or not start then return "" end 
    return string.sub(text, start, ending)
end

local function oAlpha(color, a)
    local temp = table.Copy(color)
    temp.a = a 
    return temp
end

function textbox:Init()
    self:SetCursor("beam")

    self.colors = {}
    
    -- Config --
    self.colors.outline = dark(70)
    self.colors.background  = dark(45)
    self.colors.foreground  = dark(255)
    self.colors.border      = Color(0,255,255)
    self.colors.caret       = Color(0,255,0)
    self.colors.selection   = Color(0,255,0,45)
    self.colors.placeholder = dark(85)
    self.boundsMargin = 1
    self.borderFadeSpeed = 8
    self.textoffset = 5
    ------------

    self.placeholder = ""
    self.textpos = 0
    self.caret = 0 
    self.bgfade = 0
    self.text = ""
    self.font = {
        s = 0,
        w = 0,
        h = 0,
        n = "",
        an = ""
    }

    self.selection = nil 

    self.lastFrame = 0

    self.lastText = {"", 0}
    self.lt = ""

    local parent = self 

    self.entry = vgui.Create("TextEntry", self)
    self.entry:SetSize(0,0)
    local tbox                   = self.entry 
	self.entry.Parent            = parent
    self.entry.OnLoseFocus       = function(self)       tbox.Parent:_FocusLost()           end
    self.entry.OnTextChanged     = function(self)       tbox.Parent:_TextChanged()         end
    self.entry.OnKeyCodeTyped    = function(self, code) tbox.Parent:_KeyCodePressed(code)  end

    self.entry.OnFocusChanged = function(self, status)
        parent:FocusChanged(status)
    end

    self:ResetCaretHistory()

    self:SetFont("Consolas", 20)
end 

--- Override these ---
function textbox:PaintExtras(w, h) end 
function textbox:TextChanged() end 
function textbox:OnKeyCombo(a, b) end 
function textbox:CaretMoved(old, new) end
function textbox:FocusChanged(status) end 
----------------------


--- Setters ---
function textbox:SetCaret(char)
    if not char then return end 
    char = math.Clamp(char, 0, #self.text)
    local save = self.caret
    self.caret = char 
    self:CaretMoved(save, char)
end

function textbox:SetPlaceholderText(text)
    if not text then return end 
    if type(text) ~= "string" then text = tostring(text) end 
    self.placeholder = text 
end
---------------


--- Getters ---
function textbox:GetText()
    return self.text 
end

function textbox:HasSelection()
    if not self.selection then return false end 
    return (self.selection.start ~= nil and self.selection.ending ~= nil) or (self.selection.start ~= self.selection.ending)
end
---------------


--- Actions ---
function textbox:ResetCaretHistory()
    self.caretHistory = {-1,-2,-3}
end 

function textbox:MakeSelection(start, ending)
    if not start or not ending then return end 
    self.selection.start = start 
    self.selection.ending = ending 
end

function textbox:RemoveSelection(p, del)
    if self:HasSelection() == false then return end 
    p = p or true 
    self:CheckSelection()
    self:ST(remove(self.text, self.selection.start, self.selection.ending))
    if p == true then 
        self:SetCaret(self.selection.start)
    end 
    del = del or true 
    if del == false then return end 
    self.selection = {selecting = false}
end
-------------

function textbox:ST(nt)
    self.lastText = {self.text, self.caret}
    self.text = nt 
end

function textbox:_TextChanged()
    local text = self.entry:GetText()
    if text == "\n" then 
     --   self:OnKeyCombo(nil, KEY_ENTER)
        self.entry:SetText("")
        return 
    end
    if not text or text == "" then return end

    local text = string.Split(text, "\n")[1]

    if self:HasSelection() == true then 
        self:RemoveSelection(false)
    end

    self:ST(insert(self.text, text, self.caret))

    self:SetCaret(self.caret + #text)

    self:CheckText()

    self.entry:SetText("")
end

function textbox:CheckText()
    if self.lt ~= self.text then self:TextChanged() end
    self.lt = self.text 
end

function textbox:CheckSelection()
    if self.selection == nil or self.selection.start == nil or self.selection.ending == nil then return end 
    if self:HasSelection() == false then return end 
    if self.selection.start > self.selection.ending then 
        local temp = self.selection.ending 
        self.selection.ending = self.selection.start 
        self.selection.start = temp 
    end
end

function textbox:DoUndo()
    self.selection = {selecting = false}
    self:SetCaret(self.lastText[2])
    self:ST(self.lastText[1])
    self:ReCaret()
end

function textbox:DoFullSelect()
    self.selection.start = 0
    self.selection.ending = #self.text 
    self.caret = #self.text 
end

function textbox:DoCopy()
    if self:HasSelection() == true then 
        self:CheckSelection()
        SetClipboardText(string.sub(self.text, self.selection.start + 1, self.selection.ending) or "")
    end
end

function textbox:DoCut()
    if self:HasSelection() == true then
        self.caret = self.selection.start  
        self:RemoveSelection()
    end
end

function textbox:_KeyCodePressed(code)
    local shift   = input.IsKeyDown(KEY_LSHIFT)   or input.IsKeyDown(KEY_RSHIFT)
    local control = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
    
    if control then 
        if code == KEY_Z then 
            self:DoUndo()
            self:OnKeyCombo(KEY_LCONTROL, KEY_Z)
            return 
        end

        if code == KEY_A  then 
            self:DoFullSelect()
            self:OnKeyCombo(KEY_LCONTROL, KEY_A)
            return 
        end 

        if code == KEY_C then 
            self:DoCopy()
            self:OnKeyCombo(KEY_LCONTROL, KEY_C)
            return      
        end

        if code == KEY_X then 
            self:DoCut()
            self:OnKeyCombo(KEY_LCONTROL, KEY_X)
            return 
        end

        self:OnKeyCombo(KEY_LCONTROL, code)
        return 
    end

    if code == KEY_RIGHT then
        self:SetCaret(self.caret + 1) 
        if shift then 
            if not self.selection.start then 
                self.selection.start = self.caret - 1
            end
            self.selection.ending = self.caret 
            self:OnKeyCombo(SHIFT, KEY_RIGHT)
        else 
            self.selection = {selecting = false}
            self:OnKeyCombo(nil, KEY_RIGHT)
        end 
    elseif code == KEY_LEFT then 
        self:SetCaret(self.caret - 1)
        if shift then 
            if not self.selection.start then 
                self.selection.start = self.caret + 1
            end
            self.selection.ending = self.caret 
            self:OnKeyCombo(SHIFT, KEY_LEFT)
        else 
            self.selection = {selecting = false}
            self:OnKeyCombo(nil, KEY_LEFT)
        end 
    elseif code == KEY_TAB then 
        if self:HasSelection() == true then 
            self:RemoveSelection()
        else 
            self:ST(insert(self.text, string.rep(" ", 4), self.caret))
            self:SetCaret(self.caret + 4)
        end 
        self.tabgarry = "what the fuck garry"
        self:OnKeyCombo(nil, KEY_TAB)
    elseif code == KEY_BACKSPACE then 
        if self:HasSelection() == true then 
            if input.IsMouseDown(MOUSE_LEFT) == true then 
                self:RemoveSelection(false, false)
                self.selection.start = self.caret 
            else 
                self:RemoveSelection()
            end
        else 
            if self.caret > 0 then 
                if sub(self.text, self.caret - 3, self.caret) == string.rep(" ", 4) then 
                    self:ST(remove(self.text, self.caret - 4, self.caret))
                    self:SetCaret(self.caret - 4)
                else 
                    self:ST(remove(self.text, self.caret - 1, self.caret))
                    self:SetCaret(self.caret - 1)
                end
            end 
        end  

        self:OnKeyCombo(nil, KEY_BACKSPACE)
    else 
        self:OnKeyCombo(nil, code)
    end
end

function textbox:OnFocusChanged(status)
    if status == false then return end 
    if self:HasFocus() == true then return end 
    self.entry:RequestFocus()
end

function textbox:_FocusLost()
    if self.tabgarry then 
        self.entry:RequestFocus()
        self.tabgarry = nil 
    end

    self:ResetCaretHistory()
  --  if not self.selection then return end 

   -- self.selection.start = self.caret 
  --  self.selection.ending = self.caret 
end

function textbox:CheckFocus()
    local mx, my = self:LocalCursorPos()
    local w, h = self:GetSize()
    if mx < self.boundsMargin or mx > w - self.boundsMargin then 
        self.entry:KillFocus()
        self:KillFocus()
    elseif my < self.boundsMargin or my > h - self.boundsMargin then 
        self.entry:KillFocus()
        self:KillFocus()
    end 
end

function textbox:Think()
    self:Goto(self.caret)
    if input.IsMouseDown(MOUSE_LEFT) and self.selection and self.selection.selecting == true then 

        if self.entry:HasFocus() == false then 
            self.entry:RequestFocus() 
        end 

        self:ReCaret()
        if not self.selection then return end 
        self.selection.ending = self.caret 
    elseif input.IsMouseDown(MOUSE_LEFT) and self:IsHovered() == false and (self.selection or {}).selecting == false then 
        self:CheckFocus()
        self.selection = {selecting = false}
    elseif input.IsMouseDown(MOUSE_LEFT) == false and self.selection then
        if self:HasSelection() == true then 
            self.selection.selecting = false 
        end
    end
    self:CheckText()
end

function textbox:SetFont(font, size)
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
    self.font.s = size 
    self.font.w  = w
    self.font.h  = h 
    self.font.n  = n 
    self.font.an = font 
end

function textbox:SetText(text)
    text = text or ""
    self:ST(string.Split(text, "\n")[1])
    self.textpos = 0
    self:SetCaret(#self.text) 
    self.bgfade = 0
end

function textbox:Goto(char)
    local v = self:vChars()
    if char > self.textpos + v - 1 then 
        self.textpos = self.textpos + char - (self.textpos + v - 1)
    elseif char < self.textpos - 1 then 
        self.textpos = self.textpos + (char - self.textpos) + 1
    elseif #self.text >= v and #string.sub(self.text, self.textpos, #self.text) < v then 
        self.textpos = self.textpos - 1
    end
end

function textbox:PointInText(y)
    return math.Clamp(math.Round((y - self.textoffset) / self.font.w) + math.max(self.textpos - 1, 0), 0, #self.text)
end

function textbox:PointOnPanel(char)
    return ((char - self.textoffset) * self.font.w) + self.textoffset
end

function textbox:vChars()
    return math.ceil((self:GetWide() - (self.textoffset * 2)) / self.font.w) - 1
end

function textbox:OnSizeChanged(nw, nh)
   -- self.selection = {false}
end

function textbox:PaintCaret(w, h, alpha)
    local caretPosIT = (self.caret -  math.max(self.textpos - 1, 0)) 
    local caretX = self.textoffset + (caretPosIT * self.font.w)

    if self.caret == 0 or self.caret == #self.text then 
        draw.RoundedBox(0, caretX, h / 2 - self.font.h / 2, 1.5, self.font.h, oAlpha(Color(255,150,0), alpha))
    else 
        draw.RoundedBox(0, caretX, h / 2 - self.font.h / 2, 1.5, self.font.h, oAlpha(self.colors.caret, alpha))
    end 

    if self.caret ~= #self.text then 
        draw.RoundedBox(0, caretX, h / 2 - self.font.h / 2, self.font.w, self.font.h, oAlpha(self.colors.caret, math.min(alpha,20)))
    end
end

function textbox:PaintSelection(w, h, alpha)
    if not self.selection or not self.selection.start or not self.selection.ending then return end 
    local start = self.selection.start 
    local ending = self.selection.ending 

    start  = start  - math.max(self.textpos - 1, 0) + 1
    ending = ending - math.max(self.textpos - 1, 0) + 1

    if start == ending then return end 

    if start > ending then 
        local temp = ending 
        ending = start 
        start = temp 
    end

    if ending > #self.text + 1 then 
        ending = #self.text + 1
    end

    start = math.max(start, 1)

    draw.RoundedBox(0, start * self.font.w - self.font.w / 2, h / 2 - self.font.h / 2, (ending - start) * self.font.w, self.font.h, self.colors.selection) 
end

function textbox:ReCaret()
    local mx, my = self:LocalCursorPos()

    local w, h = self:GetSize()

    self:SetCaret(self:PointInText(mx))

 --   if mx < self.boundsMargin or mx > w - self.boundsMargin then 
 --       return 
 --   end 

 --   if my < self.boundsMargin or my > h - self.boundsMargin then 
 --       return 
 --   end 
end

function textbox:PaintText(w, h)
    local text = string.sub(self.text, self.textpos, math.max(self.textpos - 1, 0) + self:vChars())
    local x, y = draw.SimpleText(text, self.font.n, self.textoffset, h / 2, self.colors.foreground, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function textbox:OnMousePressed(code)
    if (code == MOUSE_LEFT or code == MOUSE_RIGHT) then
        self:ReCaret()

        table.insert(self.caretHistory, self.caret) 
        if #self.caretHistory > 3 then 
            table.remove(self.caretHistory , 1)
        end

        if self.caretHistory[1] == self.caretHistory[2] and self.caretHistory[2] == self.caretHistory[3] then 
            self.selection.start = 0
            self.selection.ending = #self.text 
            self.caret = #self.text 
            self:ResetCaretHistory()
            self.caretHistory[1] = self.caret 
        elseif self.caretHistory[2] == self.caretHistory[3] and self.caretHistory[2] ~= self.caretHistory[1] and self.caretHistory[3] ~= self.caretHistory[1] then 
            local start, ending, text = self:WordAtPont(self.caret)
            if not self.selection then self.selection = {} end 
            self.selection.selecting = false 
            self.selection.start = start - 1
            self.selection.ending = ending 
        else 
            self.selection = {selecting = true} 
            self.selection.start = self.caret 
        end
    end 

    if self.entry:HasFocus() == false then
        self.entry:RequestFocus()
    end
end

function textbox:WordAtPont(index)
    local char = self.text[index]

    if not char then return 0,0,"" end 

    local save = char 
    local c    = index 
    
    while true do 
        c = c - 1
        char = self.text[c]

        if not char or c < 1 then 
            char = "x" -- Can be any char, otherwise if the first char is special it wont be selected 
            break 
        end 

        if isSpecial(save) == true then 
            if isSpecial(char) == false then 
                break 
            end 
        elseif isSpecial(char) == true and char ~= "_" then 
            break 
        end
    end

    local s,e,txt

    if isSpecial(char) == true then 
        s, e, txt = string.find(self.text, "([a-zA-Z0-9_]+)", c + 1)
        c = c + 1
    else 
        c = c + 1
        s, e, txt = string.find(self.text, "(%p+)", c)
    end

    if s == nil or e == nil or txt == nil then return 0,0,"" end 

    if s == c then 
        return s,e,txt
    end     

    return 0,0,""
end

function textbox:OnMouseReleased(code)

end

function textbox:Paint(w, h)
    -- Background
    draw.RoundedBox(0, 0, 0, w, h, self.colors.background)

    local frameDelay = 1 + (RealTime() - self.lastFrame) * 1.5
    local fadeSpeed  = self.borderFadeSpeed * frameDelay 


    -- Border Fade
    do 
        if self.entry:HasFocus() == true then      
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
        local col = table.Copy(self.colors.border)
        col.a = self.bgfade
        draw.RoundedBox(0,0,0,w,h,col)
    end

    draw.RoundedBox(0,0,0,w,h,oAlpha(self.colors.outline, 255 - self.bgfade))

    -- Border Fade overlap
    draw.RoundedBox(0, self.boundsMargin, self.boundsMargin, w - self.boundsMargin * 2, h - self.boundsMargin * 2, self.colors.background)

    if self.text == "" then 
        draw.SimpleText(self.placeholder or "", self.font.n, self.textoffset, h / 2, self.colors.placeholder, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    self:PaintText(w, h)
    self:PaintExtras(w, h)
    self:PaintCaret(w, h, self.bgfade)
    self:PaintSelection(w, h, self.bgfade)

    --if self.textpos > 1 then 
        local mult = math.min(self.textpos - 1, 2)
        draw.RoundedBox(0, self.boundsMargin + self.textoffset, self.boundsMargin, self.font.w * mult, self.font.h, oAlpha(dark(255),10))
   -- end

   self.lastFrame = RealTime()
end

vgui.Register("DSleekTextBox", textbox, "DPanel")
