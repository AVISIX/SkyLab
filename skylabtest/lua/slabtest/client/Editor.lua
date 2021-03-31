--[[
    Notes:
    
    - Make RichTextBox
        SetColor()
        AddText(char, line, text)
        RemoveText(startChar, startLine, endChar, endLine)
    
    - Use Line ID's to Save Folded lines in Seperate Table



]]

include("slabtest/client/utils.lua")

-- ############################################ --

local caret = {
    char = 1,
    line = 1, 
    last = {},
    __call = function(self, ...)
        if self:Set(...) == true then return end 
        return self:Get() 
    end 
}
caret.__index = caret

function caret:OnSet() end
function caret:Set(...)
    local args = {...}
    if #args == 0 or #args ~= 2 then return false end 
    self.last = {char = self.char, line = self.line}
    self.char, self.line = args[1], args[2] 
    self:OnSet(self.char, self.line, self.last)
    return true 
end

function caret:Get() return self.char, self.line end

-- ############################################ --

local fontBank = {}

local self = {}

function self:Init()
    local super = self 

    self.colors = {}
    self.colors.background = dark(40)
    self.colors.lineNumbersBackground = dark(55)
    self.colors.linesEditorDivider = Color(240,130,0, 100)
    self.colors.lineNumbers = Color(240,130,0)

    self.colors.highlights = Color(0,60,220,35)
    self.colors.selection = Color(0,60,220,90)

    self.colors.caret = Color(25,175,25)
    self.colors.endOfText = dark(150,10)

    self.colors.tabIndicators = Color(175,175,175,35)
    self.colors.caretAreaTabIndicator = Color(175,175,175,125)

    self.colors.currentLine = dark(175,5)
    self.colors.currentLineOutlines = dark(200,25)

    self.colors.foldingIndicator = dark(175,35)
    self.colors.foldingAreaIndicator = Color(100,150,180, 15)
    self.colors.foldsPreviewBackground = dark(35)
    self.colors.amountOfFoldedLines = Color(10,255,10,75)

    self.colors.pairHighlights = dark(255, 255)

    self.tokens  = table.Copy(TokenTable)
    self.caret   = table.Copy(caret)
    self.textPos = table.Copy(caret) -- the textpos shit needs the same stuff 

    self:SetFont("Consolas", 16)

    self:SetCursor("beam")
end 

function self:SetProfile(profile)
    if profile == nil or type(profile) ~= "table" then return end
    self.tokens:SetRulesProfile(profile) 
end

function self:FontChanged(newFont, oldFont) end 
function self:SetFont(name, size)
    if not name then return end 

    size = size or 16 
    size = math.Clamp(size, 14, 48)

    local newFont = "SSLEF" .. name  .. size

    if not fontBank[newfont] then
        local data = 
        {
            font      = name,
            size      = size,
            weight    = 520 
        }

        surface.CreateFont(newFont, data)

        fontBank[newFont] = data 
    end 

    surface.SetFont(newFont)

    local w, h = surface.GetTextSize(" ")

    local oldFont = table.Copy(self.font)

    self.font = 
    {
        w = w,
        h = h,
        n = newFont,
        an = name,
        s = size 
    }

    self:FontChanged(self.font, oldFont)
end 

function self:PaintBefore(w, h) end 
function self:PaintAfter(w, h) end 
function self:Paint(w, h)
    if self:IsVisible() == false then return end 

    self:PaintBefore(w, h)

    

    self:PaintAfter(w, h)
end

vgui.Register("SkyLabEditorDEBUG", self, "DPanel")
