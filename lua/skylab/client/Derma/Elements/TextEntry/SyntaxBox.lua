if not SSLE then return end 

local function getLeftLen(str)
    if not str then return 0 end 
    local _,_,r = string.find(str, "^(%s*)")
    return #r or 0
end

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
    return isUpper(char) == true or isLower(char) == true or isNumber(char) == true
end

local function isSpecial(char)
    return isNumber(char) == false and isLower(char) == false and isUpper(char) == false 
end 

local fontBank = {}

local function dark(n,a)
    if a == nil then a = 255 end 
    return Color(n,n,n,a)
end

local function isFolding(line)
    return line and line.folding and line.folding.folds and #line.folding.folds > 0 
end

local self = {}

local offset = 25 
local textoffset = 3

local function mSub(x, strength) return x - (math.floor(x) % strength) end

local function tableSame(a, b)
    if not a and not b then return true end -- both are nil, lol 
    if not a or not b then return false end 
    for k, v in pairs(a) do 
        if not b[k] or b[k] ~= v then return false end     
    end
    return true 
end

AccessorFunc(self, "tabSize", "TabSize", FORCE_NUMBER)
AccessorFunc(self, "colors", "Colors")

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

    self.tabSize = 4

    self.caret = {
        x = 0,
        y = 0, 
        char = 0,
        line = 1,
        actualLine = 1
    }
    self.lastCaret = table.Copy(self.caret)
    self.lastCaret.char = -1 

    self.lastCaretClick = table.Copy(self.caret)
    self.lastCaretClick.char = -1 

    self.caretBlink = RealTime()

    self.lastCaret.char = -1 

    self.caretRegion = {-1,-2,-3}

    self.highlights = {}
    self.selection = {
        start = {
            char = -1,
            line = 0
        },
        ending = {
            char = 0,
            line = 0
        }
    }

    self.textPos = {
        char = 1,
        line = 1
    } 
    
    function self.textPos:Set(add)
        add = add or 0 
        local scroll = super.scroller:GetScroll() + add  
        self.line = math.ceil(scroll + 1)
        super.scroller:SetScroll(scroll)
    end

    self.lastTextPos = {char=-1,line=-1}

    self.font = {
        w = 0,
        h = 0,
        s = 0,
        n = "",
        an = ""
    }

    self.refresh = 0
    self.mouseCounter = 1

    self.foldButtons = {}

    self.allTabs = {}

    self.undo = {}
    self.redo = {}

    self.lastCode = 0x0

    self.data = table.Copy(SSLE.DataContext)

    self.data.LineFolded = function(_, line, len, b)
        self:ClearHighlights()
        self.pressedWord = nil 
        self:ResetBGProg()
        self:GetTabLevels()
        self:UpdateSurroudingPairs()

        b = b.button

        if IsValid(b) == true then 
            b:SetFolded(true)
        end

        if self.caret.actualLine <= line + len then return end

        self.caret.actualLine = self.caret.actualLine - len 
    end

    self.data.LineUnfolded = function(_, line, len, b)
        self:ClearHighlights()
        self.pressedWord = nil 
        self:ResetBGProg()
        self:GetTabLevels()
        self:UpdateSurroudingPairs()

        b = b.button

        if IsValid(b) == true then 
            b:SetFolded(false)
        end

        if self.caret.actualLine <= line then return end 
        self.caret.actualLine = self.caret.actualLine + len 
    end

    self.data.FoldingAvailbilityCheckStarted = function() 
        self:HideButtons()
    end
    self.data.FoldingAvailbilityFound = function(_, i, len, t)
        local b = self:MakeFoldButton()

        b.super = self.data.context[i]
        b.isHovered = false 
        b.Think = function(self)
            if ( self:GetAutoStretchVertical() ) then
                self:SizeToContentsY()
            end

            if self:IsHovered() == true and self.isHovered == false then 
                super.data:ValidateFoldingAvailability(i)
                self.isHovered = true
            elseif self:IsHovered() == false then self.isHovered = false end  
        end

        b.DoClick = function(_)
            local super = b.super 

            if not super then 
                self:HideButtons()
                return 
            end
        
            local line = self.data:GetKeyForIndex(super.index)

            if not line then return end 

            if #super.folding.folds == 0 then  
                local l = self.data.context[line]

                if self:IsShift() == true then 
                    local max = line + l.folding.available
                    self:SetSelection(0, line + 1, #self.data.context[max].text, max)
                    return 
                else 
                    self:ResetSelection()
                end

                if not l or not l.folding then
                    self:HideButtons()
                    return 
                end 

                if not l.folding.available then 
                    self:HideButtons()
                    self.data:ValidateFoldingAvailability(i)
                    return 
                end

                local limit = l.index + l.folding.available

                self.data:FoldLine(line)

                if self.caret.line > l.index and self.caret.line <= limit then 
                    self:SetCaret(self.caret.char, i) -- if the caret is inside an area that is being folded, push it the fuck out of there xoxoxo
                end

                b:SetFolded(true)
            else             
                self:ResetSelection()
                self.data:UnfoldLine(line)
                self:HideButtons()
                b:SetFolded(false)
            end
        end

        self.data.context[i].button = b

        table.insert(self.foldButtons, b)
    end

    self.data:ResetProfile()

    local super = self 

    self.entry = vgui.Create("TextEntry", self)
    self.entry:SetSize(0,0)
    self.entry:SetMultiline(true)
    self.entry.OnLoseFocus = function(self)       
        super:_FocusLost()           
    end
    self.entry.OnTextChanged = function(self)       
        super:_TextChanged()         
    end
    self.entry.OnKeyCodeTyped = function(self, code) 
        super:_KeyCodePressed(code)  
    end
    self.entry.OnKeyCodeReleased = function(self, code) 
        super:_KeyCodeReleased(code) 
    end
    self.entry.super = self
    
    self.entry:RequestFocus()
   
    self.scroller = vgui.Create("DVScrollBar", self)
    self.scroller:Dock(RIGHT)
    self.scroller.Dragging = false
    self.scroller.super = self 

    self:SetFont("Consolas", 16)

    self.runBackgroundWorker = false  
    self.bgLineCounter = 1
    self.bgSuperHistory = {}
    self.bgLast = {}

    self:SetCursor("beam")
end

function self:InitBackgroundWorker() -- Initializes the background thread, this thread will constantly loop through the lines to make sure everything is in correct order.
    self.runBackgroundWorker = true 

    self.bgLast = {}

    self.backgroundWorker = coroutine.create(function() -- DO NOT TOUCH THIS UNDER ANY CIRCUMSTANCES ANY BUG WILL CAUSE A FREEZE
        local function reset()
            self.bgSuperHistory = {{collection=self.data.context,counter=1}}
            self.bgLineCounter = 1 
            self.bgLast = {}
        end

        reset()

        local function reload()
            self.bgLineCounter = 1
            self.bgLast = {} 
        end

        while self.runBackgroundWorker == true do 
            if IsValid(self) == false then break end 

            if not self.bgSuperHistory or #self.bgSuperHistory == 0 then -- insurance incase something fucks up
                reset() 
                coroutine.wait(0.1)
            end 

            if self:IsVisible() == false then -- If its not visible, why parse?
                coroutien.wait(1)
                continue 
            end

            local entry = self.bgSuperHistory[#self.bgSuperHistory]

            if not entry then 
                reset() 
                coroutine.wait(0.1)
                continue 
            end

            if entry.counter > #entry.collection then
                if #self.bgSuperHistory > 1 then 
                    table.remove(self.bgSuperHistory) -- just remove it, dont need to reset the counter in that case
                    entry = self.bgSuperHistory[#self.bgSuperHistory]
                else 
                    entry.counter = 1
                    reload()
                    coroutine.wait(0.1)
                    continue 
                end 
            end

            local item = entry.collection[entry.counter] 

            if item then 
                item.index = self.bgLineCounter 
                self.data.latestParsedLine = self.bgLineCounter
                item.tokens = self.data:ParseRow(item.text, self.bgLast.tokens or {}) 

                local countedLevel, offset = self.data:CountIndentation(item.tokens or {})
                
                item.offset = offset 
                item.nextLineIndentationOffsetModifier = countedLevel + (self.bgLast.nextLineIndentationOffsetModifier or 0)
                item.level = math.max((self.bgLast.nextLineIndentationOffsetModifier or 0) + math.min(countedLevel, 0), 0)
            end

            self.bgLineCounter = self.bgLineCounter + 1

            if self.bgLineCounter > #self.data.context then 
                reset()
                coroutine.wait(0.05)
                continue 
            end

            entry.counter = entry.counter + 1

            self.bgLast = item

            if item.folding and #item.folding.folds > 0 then 
                table.insert(self.bgSuperHistory, {
                    collection = item.folding.folds, 
                    counter = 1
                })
            end

            if self.bgLineCounter % 50 == 0 then 
                coroutine.wait(0.05)
            end 
        end
    end)

    coroutine.resume(self.backgroundWorker)
end

function self:ContinueBackgroundWorker()
    if not self.data.context or #self.data.context == 0 or self.stopBGWorker == true then return end 

    if not self.backgroundWorker then 
        self:InitBackgroundWorker()
        return 
    end

    if coroutine.status(self.backgroundWorker) == "running" then return end 

    if coroutine.status(self.backgroundWorker) == "suspended" or (self.backgroundWorker ~= nil and coroutine.status(self.backgroundWorker) ~= "running") then 
        coroutine.resume(self.backgroundWorker)
    elseif coroutine.status(self.backgroundWorker) == "dead" and not self.backgroundWorker then 
        self:ResetBGProg()
    end
end

function self:ResetBGProg(newProg)
    if not self.backgroundWorker then 
        self:InitBackgroundWorker()
        return 
    end
    
    if coroutine.status(self.backgroundWorker) ~= "dead" then
        self.bgLineCounter = newProg or 1
        self.bgLast = self.data.context[self.bgLineCounter - 1] or {}
        self.bgSuperHistory = {{collection=self.data.context,counter=1}}
    end
end

function self:KillBGWorker()
    if not self.backgroundWorker then return end 

    if coroutine.status(self.backgroundWorker) ~= "dead" then
        self.bgLineCounter = 1
        self.bgLast = {}
        self.bgSuperHistory = {{collection=self.data.context,counter=1}}
        self.runBackgroundWorker = false 
        self.backgroundWorker = nil 
    end
end

function self:GetTab()
    return string.rep(" ", self.tabSize)
end

function self:HandleBadButton(v)
    if IsValid(v) == false then 
        if v.super then v.super.button = nil end 
        return 
    elseif IsValid(v) == true and not v.super then 
        v:Remove()
    end 

    v:SetVisible(false) 
end

function self:SetSelection(...)
    local startChar, startLine, endingChar, endingLine = select(1, ...), select(2, ...), select(3, ...), select(4, ...)

    if startChar == nil then return end 

    if type(startChar) == "table" and startLine == nil then 
        self.selection.start = table.Copy(startChar)
        self.selection.ending = table.Copy(startChar)
        return 
    end 
    
    if type(startChar) == "table" and type(startLine) == "table" then 
        self.selection.start = table.Copy(startChar)
        self.selection.ending = table.Copy(startLine) 
        return 
    end 
    
    if type(startChar) == "number" and type(startLine) == "number" and endingChar == nil then 
        endingChar = startChar 
        endingLine = startLine  
    end

    self.selection = {
        start = {
            char = startChar, 
            line = startLine
        },
        ending = {
            char = endingChar,
            line = endingLine 
        }
    }
end 

function self:SetSelectionEnd(t, lol)
    if type(t) == "table" then 
        self.selection.ending = table.Copy(t)
        return 
    end  

    self.selection.ending.char = t
    self.selection.ending.line = lol 
end

function self:IsSelecting()
    return self.selection.start.char ~= self.selection.ending.char or self.selection.start.line ~= self.selection.ending.line 
end

function self:ResetSelection()
    self:SetSelection(self.caret.char, self.caret.actualLine)
end

function self:HideButtons()
    for k, v in pairs(self.foldButtons) do 
        if IsValid(v) == false then 
            self:HandleBadButton(v)
            self.foldButtons[k] = nil 
            continue 
        end
        
        v:SetVisible(false)
    end 
end

function self:GetLine(i)
    for k, v in pairs(self.data.context) do 
        if v.index == i then 
            return v 
        end
    end

    return nil 
end

local function insertChar(text, char, index)
    if not text or not char then return end 
    index = index or #text 
    return string.sub(text, 1, index) .. char .. string.sub(text, index + 1, #text) 
end

local function removeChar(text, index)
    if not text then return end 
    index = index or #text 
    return string.sub(text, 1, index - 1)  .. string.sub(text, index + 1, #text)
end

local function removeArea(text, start, ending)
    if not text or not start or not ending then return end 
    return string.sub(text, 1, start) .. string.sub(text, ending, #text)
end

local function getLR(text, index)
    if not text or not index then return end 
    return string.sub(text, 1, index), string.sub(text, index + 1, #text) 
end

function self:TextChanged() 
    self:ParseVisibleLines()
    self:GetTabLevels()
    self:HideButtons()
    self:ClearHighlights()
    self.pressedWord = nil 
    self:UpdateSurroudingPairs()
    self:ResetSelection()
end 

function self:RemoveSelection()
    if self:IsSelecting() == true then
        self:RemoveText(self.selection.start, self.selection.ending)
    end 
end

function self:InsertText(text, char, line)
    char = char or self.caret.char 
    line = line or self.caret.actualLine
    char, line = self.data:InsertTextAt(text, char, line)
    if char then self:SetCaret(char, line) end
end

function self:RemoveText(a,b,c,d)
    local sc, sl, ec, el = self.data:RemoveTextArea(a, b, c, d)
    if sc and sl then 
        self:SetCaret(sc, sl)
    end 
end

function self:_TextChanged()
    local new = self.entry:GetText()

    if new == "" then return end 

    self:RemoveSelection()

    self.data:UnfoldLine(self.caret.actualLine)
    self.caret.actualLine = self.caret.actualLine + self.data:UnfoldLine(self.caret.actualLine - 1)

    local function foo()
        if new == "\n" then return end 

        local line = self.data.context[self.caret.actualLine]
        
        if not line then return end  

        self:InsertText(new)
    end

    foo()

    self:GetTabLevels()

    self.data:ValidateFoldingAvailability(self.caret.actualLine - 1)

    self.entry:SetText("")

    self:TextChanged()
end

function self:_KeyCodeReleased(code)
end

function self:OnKeyCombo(key1, key2)
end

function self:HopTextLeft(char, line)
    local entry = self.data.context[line]
    if not entry then return end  

    local curChar = entry.text[char]

    local function skipWhitespaces()
        while string.gsub(curChar, "%s", "") == "" do
            local temp = entry.text[char] 
            if not temp or temp == "" then 
                line = line - 1
                entry = self.data.context[line]
                if not entry or not entry.text then return end 
                char = #entry.text 
                temp = entry.text[char] 
            else 
                char = char - 1
            end
            curChar = entry.text[char] 
        end
    end

    skipWhitespaces()

    if isSpecial(curChar) == true then 
        while isSpecial(curChar) == true and string.gsub(curChar, "%s", "") ~= "" do
            char = char - 1  
            curChar = entry.text[char]  
        end 
    else 
        while isLetter(curChar) == true and string.gsub(curChar, "%s", "") ~= "" do
            char = char - 1  
            curChar = entry.text[char]  
        end 
    end 

    return char, line 
end

function self:HopTextRight(char, line)
    local entry = self.data.context[line]
    if not entry then return end  

    char = char + 1

    local curChar = entry.text[char]

    local function skipWhitespaces()
        while string.gsub(curChar, "%s", "") == "" do
            local temp = entry.text[char] 
            if not temp or temp == "" then 
                line = line + 1
                char = 1 
                entry = self.data.context[line]
                if not entry then return end 
                temp = entry.text[char] 
            else 
                char = char + 1
            end 
            curChar = temp
        end
    end

    skipWhitespaces()

    if isSpecial(curChar) == true then 
        while isSpecial(curChar) == true and string.gsub(curChar, "%s", "") ~= "" do
            char = char + 1  
            curChar = entry.text[char]  
        end 
    else 
        while isLetter(curChar) == true and string.gsub(curChar, "%s", "") ~= "" do
            char = char + 1  
            curChar = entry.text[char]  
        end 
    end 

    char = char - 1

    return char, line 
end

function self:_KeyCodePressed(code)
    self.lastCode = code 

    self:ToggleCaret()

    do 
        local keyA 

        if self:IsShift() then 
            keyA = input.IsKeyDown(KEY_LSHIFT) and KEY_LSHIFT or KEY_RSHIFT
        elseif self:IsCtrl() then 
            keyA = input.IsKeyDown(KEY_LCONTROL) and KEY_LCONTROL or KEY_RCONTROL
        end

        self:OnKeyCombo(keyA, code)
    end

    local line = self.data.context[self.caret.actualLine]

    if not line then return end 

    local left, right = getLR(line.text, self.caret.char) 

    local savedCaret = table.Copy(self.caret or {}) 

    local function handleSelection()
        if self:IsShift() == true then 
            if self:IsSelecting() == false then 
                self:SetSelection(savedCaret.char, savedCaret.actualLine, self.caret.char, self.caret.actualLine)
            else 
                self:SetSelectionEnd(self.caret.char, self.caret.actualLine)
            end
        else 
            self:ClearHighlights()
            self.pressedWord = nil 
            self:ResetSelection()
        end 
    end

    if self:IsCtrl() then
        if code == KEY_C then 
            if self:IsSelecting() == true then
                local copy = self.data:GetTextArea(self.selection.start, self.selection.ending)
                if copy then  
                    SetClipboardText(copy)
                end 
            end 
        elseif code == KEY_K then 
            self.data:FoldAll()
        elseif code == KEY_J then 
            self.data:UnfoldAll()
        elseif code == KEY_A then 
            local c = self.data.context 
            self:SetSelection(0,1,#c[#c].text, #c) 
        elseif code == KEY_DOWN then 
            self.textPos:Set(1)
        elseif code == KEY_UP then 
            self.textPos:Set(-1)
        elseif code == KEY_RIGHT then 
            local char, line = self:HopTextRight(self.caret.char, self.caret.actualLine)
            if char and line then 
                self:ResetSelection()
                self:SetCaret(char, self.data:GetIndexForKey(line))
            end
        elseif code == KEY_LEFT then 
            local char, line = self:HopTextLeft(self.caret.char, self.caret.actualLine)
            if char and line then 
                self:ResetSelection()
                self:SetCaret(char, self.data:GetIndexForKey(line))
            end
        elseif code == KEY_Z then 
            local char, line = self.data:Undo()
            if char and line then 
                self:SetCaret(char, line)
            end
        elseif code == KEY_Y then 
            local char, line = self.data:Redo()
            if char and line then 
                self:SetCaret(char, line)
            end
        end

        return
    end

    if code == KEY_DOWN then
        self:SetCaret(self.caret.char, self.caret.line + 1, true)
        handleSelection()
    elseif code == KEY_UP then
        self:SetCaret(self.caret.char, self.caret.line - 1, true)
        handleSelection()
    elseif code == KEY_RIGHT then 
        self:SetCaret(self.caret.char + 1, self.caret.line, true)
        handleSelection()
    elseif code == KEY_LEFT then 
        self:SetCaret(self.caret.char - 1, self.caret.line, true)
        handleSelection()
    elseif code == KEY_ENTER then 
       if self.data:UnfoldLine(self.caret.actualLine) > 0 then self.data:ValidateFoldingAvailability(self.caret.actualLine) end 
        if self.caret.char ~= #line.text and self.data:UnfoldLine(self.caret.actualLine - 1) > 0 then self.data:ValidateFoldingAvailability(self.caret.actualLine - 1) end

        local a, b = self.data:AddText("\n", self.caret.char, self.caret.actualLine)
        if a and b then self:SetCaret(a, b) end

        self:TextChanged()
    elseif line then 
        if code == KEY_BACKSPACE then 
            if self:IsSelecting() == true then
                self:RemoveSelection()
            else 
                if self.caret.char - 1 < 0 then -- Remove line 
                    self.data:UnfoldLine(self.caret.actualLine)
                    self.data:UnfoldLine(self.caret.actualLine - 1)

                    local prevLine = self.data.context[self.caret.actualLine - 1]

                    if not prevLine then return end 

                    local a, b = self.data:RemoveText("\n", #prevLine.text, self.caret.actualLine - 1)
                    if a and b then self:SetCaret(a, b) end

                    self.data:ValidateFoldingAvailability(self.caret.actualLine)
                else -- Normal character remove
                    local save = self.caret.actualLine
                    local unfolds = self.data:UnfoldLine(save)

                    local left = getLeftLen(line.text)

                    if self.caret.char <= left then 
                        local save = self.caret.char

                        local diffCheck = self.caret.char
                        if diffCheck % self.tabSize == 0 then 
                            diffCheck = diffCheck - self.tabSize 
                        else 
                            diffCheck = diffCheck - diffCheck % self.tabSize 
                        end

                        local diff = save - diffCheck
                        
                        local a, b = self.data:RemoveTextArea(self.caret.char - diff, self.caret.actualLine, self.caret.char, self.caret.actualLine)
                        if a and b then self:SetCaret(a, b) end
                    else 
                        self.data:UnfoldLine(self.caret.actualLine - 1)

                        local a, b = self.data:RemoveTextArea(self.caret.char - 1, self.caret.actualLine, self.caret.char, self.caret.actualLine)
                        if a and b then self:SetCaret(a, b) end

                        self.data:ValidateFoldingAvailability(self.caret.actualLine - 1)
                    end

                    if unfolds > 0 then 
                        self.data:ValidateFoldingAvailability(save)
                    end
                end 
            end 

            self:TextChanged()
     elseif code == KEY_TAB then
            local save    = self.caret.actualLine 
            local unfolds = self.data:UnfoldLine(save)

            local left = getLeftLen(line.text)

            if self.caret.char <= left then 
                local save = self.caret.char

                local diffCheck = self.caret.char 
                if diffCheck % self.tabSize == 0 then 
                    diffCheck = diffCheck + self.tabSize 
                else 
                    diffCheck = diffCheck - diffCheck  % self.tabSize + self.tabSize 
                end
                local diff = diffCheck - save        

                local a, b = self.data:AddText(string.rep(" ", diff), self.caret.char, self.caret.actualLine)
                if a and b then self:SetCaret(a, b) end
            else
                self.data:UnfoldLine(self.caret.actualLine - 1)

                local a, b = self.data:AddText(self:GetTab(), self.caret.char, self.caret.actualLine)
                if a and b then self:SetCaret(a, b) end

                self.data:ValidateFoldingAvailability(self.caret.actualLine - 1)
            end

            self.tabbed = true

            if unfolds > 0 then 
                self.data:ValidateFoldingAvailability(save)
            end

            self:TextChanged()
        end
    end
end

function self:_FocusLost()
    if self:HasFocus() == true or self.tabbed then 
        self.entry:RequestFocus()
        self.tabbed = nil 
    end
end

function self:OnFocusChanged(gained)
    if gained == false then return end
    self.entry:RequestFocus()
end

function self:ProfileSet() end 
function self:SetProfile(profile)
    self:TimeRefresh(10)
    self.data:SetRulesProfile(profile)
    self:ProfileSet(self.data.profile)
end

function self:ProfileReset() end 
function self:ClearProfile()
    self.data:ResetProfile()
    self:ProfileReset()
    self:ClearProfile()
end

function self:SetText(text)
    if not text then return end
    self:TimeRefresh(10)
    self.data:SetContext(text)
    self:TextChanged()
    self:GetTabLevels()
    self.entry:RequestFocus()
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

local function isWhitespace(str)
    return string.gsub(str, "%s", "") == "" 
end

function self:GetTabLevels()
    local s = self.textPos.line 
    local e = self.textPos.line + self:VisibleLines()

    self.allTabs = {}

    local temp = {}
    local lastLevel = -1

    for i = s, e, 1 do 
        local item = self.data.context[i] 

        if not item then break end 

        if string.gsub(item.text, "%s", "") == "" then 
            table.insert(temp, item.index)
        else 
            local len = getLeftLen(item.text) 

            if len < lastLevel then 
                for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(len / self.tabSize) + 1 end
            elseif lastLevel == -1 then -- If all of the start was whitespaces
                local lastValidLen = 0

                for i = s, 1, -1 do 
                    local item = self.data.context[i] 

                    if not item then break end 

                    if string.gsub(item.text, "%s", "") ~= "" then 
                        lastValidLen = getLeftLen(item.text)
                        break 
                    end
                end

                if lastValidLen ~= 0 then
                    for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(math.min(lastValidLen, len) / self.tabSize) + 1 end
                end 
            else 
                for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(lastLevel / self.tabSize) + 1 end
            end

            temp = {}

            self.allTabs[item.index] = math.ceil(len / self.tabSize)

            lastLevel = len 
        end
    end

    if #temp then -- If all at the end was whitespaces 
        for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(lastLevel / self.tabSize) + 1 end 
    end
end

function self:GetTokenAtPoint(char, line)
    local line = self.data.context[line]
    if not line or not line.tokens then return end
    for i = 1, #line.tokens, 1 do 
        local token = line.tokens[i]
        if token.start <= char and token.ending >= char then 
            return token, char, line, i
        end
    end
end

function self:GetSurroundingPairs(char, line)
    if not char or not line then return end 
    if not self.data.profile.closingPairs then return end 

    local token, _, _, tokenIndex = self:GetTokenAtPoint(char, line) 

    if (not token or (not tokenIndex and char == 1)) and line ~= 1 then 
        line = line - 1
        local entry = self.data.context[line]
        if not entry then return end 
        tokenIndex = #entry.tokens 
        token = entry.tokens[tokenIndex]
    end

    if not tokenIndex then return end 

    local function isPair(text)
        for k, v in pairs(self.data.profile.closingPairs) do 
            if v.open == text then 
                return "open", k, v 
            elseif v.close == text then 
                return "close", k, v 
            end
        end
    end

    local endArgs 
    local startArgs 
    
    do 
        local curToken = self.data.context[line].tokens[tokenIndex]

        if curToken then 
            local type, name, data = isPair(curToken.text) 

            if type and type == "close" then 
                local prevToken = {}

                local tki = tokenIndex 
                local tkl = line 

                if tki - 1 < 1 then 
                    tkl = tkl - 1 
                    if tkl < 1 then 
                        prevToken = nil 
                    else 
                        tki = #self.data.context[tkl].tokens 
                    end
                else 
                    tki = tki - 1
                end

                if prevToken then 
                    prevToken = self.data.context[tkl].tokens[tki]
                    if prevToken then 
                        tokenIndex = tokenIndex - 1
                        token = prevToken 
                    end 
                end 
            end
        end 
    end 

    local result = {}

    do 
        local function findStartPair(index, line)
            if not index or not line then return end 

            local counter = {}

            while true do 
                if index < 1 then 
                    line = line - 1 
                    if not self.data.context[line] or line < 1 then return end 
                    index = #self.data.context[line].tokens 
                    if not index then continue end 
                end

                local token = self.data.context[line].tokens[index]

                if token then 
                    local type, name, data = isPair(token.text)

                    if type == "open" then
                        if counter[name] == nil then counter[name] = 0 end  

                        if counter[name] == 0 then 
                            return index, line, token, type, name, data
                        else 
                            counter[name] = counter[name] - 1
                        end
                    elseif type == "close" then 
                        if counter[name] == nil then counter[name] = 0 end 
                        counter[name] = counter[name] + 1
                    end
                end 

                index = index - 1
            end 
        end

        startArgs = {findStartPair(tokenIndex, line)}

        if #startArgs == 0 then return end 

        result.start = {
            tkIndex = startArgs[1],
            line = startArgs[2]
        }
    end

    do 
        local function findClosePair(index, line, key)
            if not index or not line then return end 

            local counter = 0

            while true do 
                local item = self.data.context[line]

                if not item or not item.tokens then return end 

                if index > #item.tokens then
                    index = 1
                    line = line + 1
                    if line > #self.data.context then return end 
                end

                local token = self.data.context[line].tokens[index]

                if not token then return end 

                local type, name, data = isPair(token.text)

                if key then 
                    if name and name == key then 
                        if type == "close" then 
                            if counter == 0 then 
                                return index, line, token, type, name, data 
                            else 
                                counter = counter - 1 
                            end
                        elseif type == "open" then 
                            counter = counter + 1
                        end
                    end
                elseif type == "close" then 
                    return index, line, token, type, name, data 
                end

                index = index + 1
            end
        end

        endArgs = {findClosePair(tokenIndex + 1, line, (startArgs ~= nil and startArgs[5] or nil))}

        if #endArgs > 0 then 
            result.ending = {
                tkIndex = endArgs[1],
                line = endArgs[2]
            }
        end 
    end 

    return result 
end

function self:RefreshCaretMoveTimer()
    self.caretMoveTimer = RealTime() + 0.2
end

function self:UpdateSurroudingPairs()
    self.surroundingPairs = self:GetSurroundingPairs(self.caret.char, self.caret.actualLine)
end

function self:CaretStoppedMovingHandler()
    if not self.caretMoveTimer then return end  
    if RealTime() > self.caretMoveTimer then 
        self:UpdateSurroudingPairs()
        self.caretMoveTimer = nil 
    end 
end

function self:TimeRefresh(len)
    self.refresh = RealTime() + (len or 1) 
end

function self:RefreshData() -- As insurance we refresh some of the "bugheavy" stuff sometimes 
    self:GetTabLevels()
    self.data:FixIndeces()
    self:HideButtons()
    self.data:GetGlobalFoldingAvailability()
end

function self:ParseVisibleLines()
    if self:IsVisible() == false then return end  
    self.data:SimpleAreaParse(self.textPos.line , (self.textPos.line + self:VisibleLines()))
end

function self:PosInText(...) return self:pit(...) end 
function self:pit(...) -- short for pos in text. Converts local x, y coordinates to a position in the text 
    if #{...} ~= 2 then return end 

    local x, y = select(1, ...), select(2, ...)

    local panelW, panelH = self:GetSize()

    if x == nil then x = 1 else x = math.Clamp(x, 0, panelW) end
    if y == nil then y = 1 else y = math.Clamp(y, 0, panelH) end 

    x = x - (offset * 2 + self:GetLineNumberWidth() - textoffset)
  --  x = x + self.textPos.char * self.font.w 

    x = math.Round(mSub(x, self.font.w) / self.font.w + self.textPos.char - 1)
    y = math.Round(mSub(y, self.font.h) / self.font.h + self.textPos.line)

    y = math.Clamp(y, 1, #self.data.context)
    x = math.Clamp(x, 0, #(self.data.context[y].text or ""))

    y = self.data.context[y].index 

    return x, y
end

function self:PosOnPanel(...) return self:pop(...) end 
function self:pop(...) -- short for pos on panel. Converts a position in the text to a position on the panel
    if #{...} ~= 2 then return end 

    local char, line = select(1, ...), select(2, ...)

    local x = (char - self.textPos.char + 1) * self.font.w 
    local y = line * self.font.h 

    x = x + offset * 2 + self:GetLineNumberWidth() + textoffset 

    return x, y 
end

function self:SetCaretFromVisLine(...)
    if #{...} < 2 then return end 
    
    local char, line, swapOnReach = select(1, ...), select(2, ...), select(3, ...)

    if not char or not line then return end 

    if swapOnReach == nil then swapOnReach = false end 

    return self:SetCaret(char, self.data:GetIndexForKey(line), swapOnReach)
end

function self:CaretSet(char, line, actualLine) end 
function self:SetCaret(...)
    if #{...} < 2 then return end 

    local char, line, swapOnReach = select(1, ...), select(2, ...), select(3, ...)

    self.lastCaret = table.Copy(self.caret)

    if self.caret.char ~= char or self.caret.line ~= line then 
        if swapOnReach == nil then swapOnReach = false end 

        local actualLine = self.data:GetKeyForIndex(line)

        if not actualLine then 
            local last = self.caret.actualLine
            
            if self.lastCode == KEY_UP or self.lastCode == KEY_LEFT then 
                actualLine = last - 1
            elseif self.lastCode == KEY_DOWN or self.lastCode == KEY_RIGHT then   
                actualLine = last + 1
            else return end  

            actualLine = math.Clamp(actualLine, 1, #self.data.context)

            line = self.data.context[actualLine].index
        end

        self.caret.line = math.max(line, 1)
        self.caret.actualLine = actualLine -- We save this to avoid shitty loops all over the place 

        if swapOnReach == false then 
            self.caret.char = math.Clamp(char, 0, #self.data.context[actualLine].text) 
        else
            if char > #self.data.context[actualLine].text and self.lastCode == KEY_RIGHT then 
                if not self.data.context[actualLine + 1] then return end  
                self:SetCaret(0, self.caret.line + 1)
            elseif char < 0 and (self.lastCode == KEY_LEFT or self.lastCode == KEY_BACKSPACE) then 
                self:SetCaret(#((self.data.context[actualLine - 1] or {}).text or ""), self.caret.line - 1)
            else
                self.caret.char = math.Clamp(char, 0, #self.data.context[actualLine].text) 
            end
        end

        self:ToggleCaret()

        self:CaretSet(self.caret.char, self.caret.line, self.caret.actualLine)

        self.data:ValidateFoldingAvailability(self.caret.actualLine) 

        self:Goto()

        self:RefreshCaretMoveTimer()
    end

    return self.caret.line, self.caret.char 
end

function self:WordAtPoint(char, line)
    if not char or not line then return end 

    local item = self.data.context[line]
    if not item then return end 

    item = item.text 

    local firstChar = item[char]

    if not firstChar then return end 

    if firstChar == " " then 
        for i = char - 1, 0, -1 do 
            local c = item[i] 
            if not c or c ~= " " then 
                local a, b, c = string.find(item, "(%s+)", i + 1)
                if a and b then 
                    return (a - 1), b, (c or string.sub(item, a, b))
                end 
            end
        end 
    else  
        if isSpecial(firstChar) == true then 
            for i = char - 1, 0, -1 do
                local c = item[i] 
                if not c or isSpecial(c) == false or string.gsub(c, "%s", "") == "" then 
                    local a, b, c = string.find(item, "(%p+)", i + 1)
                    if a and b then 
                        return (a - 1), b, (c or string.sub(item, a, b))
                    end 
                end 
            end
        else 
            for i = char - 1, 0, -1 do
                local c = item[i] 
                if not c or isSpecial(c) == true or string.gsub(c, "%s", "") == "" then 
                    local a, b, c = string.find(item, "([^ %p]+)", i + 1)
                    if a and b then 
                        return (a - 1), b, (c or string.sub(item, a, b))
                    end 
                end 
            end 
        end
    end 
end

-- Non recursive function to find words 
function self:FindWords(needle, usePatterns, rangeStart, rangeEnd, checkCallback, filterEmpty)
    if not needle then return {} end 

    checkCallback = checkCallback or function() return true end 

    if usePatterns == nil then usePatterns = true end 
    if filterEmpty == nil then filterEmpty = true end 

    rangeStart = rangeStart or self.textPos.line 
    rangeEnd   = rangeEnd   or (self.textPos.line + self:VisibleLines())

    local result = {}
    
    for line = rangeStart, rangeEnd, 1 do 
        local item = self.data.context[line]

        if not item then break end 

        local i = 1

        while i <= #item.text do 
            local a, b = string.find(item.text, needle, i, !usePatterns) 
            
            if a and b and a == i then

                if filterEmpty == true and string.gsub(string.sub(item.text, i, b), "%s", "") == "" then 
                    i = i + 1
                    continue 
                end 

                local temp = {
                    start = {
                        char = (i - 1),
                        line = line  
                    },
                    ending = {
                        char = b,
                        line = line 
                    }
                }

                if checkCallback(temp) == true then 
                    table.insert(result, temp)
                    i = i + #needle
                    continue 
                end 
            end 

            i = i + 1
        end
    end

    return result 
end

function self:HighlightPressedWord()
    if not self.pressedWord then return end 
    table.Merge(self.highlights, self:FindWords(self.pressedWord, false), nil, nil, function(temp)
        return tableSame(self.selection, temp) == false
    end)
end 

function self:OnMouseClick(code) end 
function self:OnMousePressed(code)
    self:OnMouseClick(code)

    if code == MOUSE_LEFT then 
        self:SetCaret(self:pit(self:LocalCursorPos()))
        
        local line = self.data.context[self.caret.actualLine]

        ::HandleNewMouseCounter:: 

        if line and tableSame(self.caret, self.lastCaretClick) == true then 
            self:ClearHighlights()

            if self.mouseCounter == 1 then 
                local start, ending, word = self:WordAtPoint(self.caret.char, self.caret.actualLine)

                if not start then 
                    self.mouseCounter = self.mouseCounter + 1
                    goto HandleNewMouseCounter
                end

                self:SetSelection(start, self.caret.actualLine, ending, self.caret.actualLine)
            elseif self.mouseCounter == 2 then 
                self:SetSelection(0, self.caret.actualLine, 0, math.min(self.caret.actualLine + 1, #self.data.context))
            else
                self:ResetSelection() 
            end

            self.mouseCounter = self.mouseCounter + 1
            
            if self.mouseCounter > 2 then self.mouseCounter = 0 end 
        else
            self:ClearHighlights()
            self:ResetSelection()
            
            self.pressedWord = ({self:WordAtPoint(self.caret.char, self.caret.actualLine)})[3] or nil 

            self:HighlightPressedWord()

            self.mouseCounter = 1
        end 
    elseif code == MOUSE_RIGHT then 

    end

    self.lastCaretClick = table.Copy(self.caret)

    if self.entry:HasFocus() == false then self.entry:RequestFocus() end 
end

function self:GetLineNumberCharCount(add)
    add = add or 0 
    local n     = self.textPos.line + self:VisibleLines() - 1 + add 
    local entry = self.data.context[n]
    return #tostring(entry and entry.index or n)
end

function self:GetLineNumberWidth(add)
    return self:GetLineNumberCharCount(add) * self.font.w 
end

function self:VisibleLines()
    return math.ceil(self:GetTall() / self.font.h)
end

function self:VisibleChars()
    return math.ceil((self:GetWide() - self:GetLineNumberWidth() - offset * 2) / self.font.w) 
end

function self:PaintBefore(w, h) end 
function self:PaintAfter(w, h) end 

local function drawLine(startX, startY, endX, endY, color)
    surface.SetDrawColor(color)
    surface.DrawLine(startX, startY, endX, endY)
end

function self:Goto(char, line)
    line = line or self.caret.actualLine 
    char = char or self.caret.char 
    
    do 
        local minLine = self.textPos.line  
        local maxLine = minLine + self:VisibleLines()

        local diff = 0

        if line < minLine then 
            diff = line - minLine
        elseif line > maxLine - 1 then 
            diff = line - (maxLine - 1)
        end

        self.textPos:Set(diff)
    end

    do 
        local minChar = self.textPos.char - 1
        local maxChar = minChar + self:VisibleChars() - math.ceil(self.scroller:GetWide() / self.font.w) - 1

        local diff = 0 

        if char < minChar then 
            diff = char - minChar
        elseif char > maxChar then 
            diff = char - maxChar 
        end

        self.textPos.char = math.max(self.textPos.char + diff, 0) 
    end
end

function self:AddHighlight(a, b, c, d)
    ::CheckParamsAgain::

    if a == nil or b == nil then return end 
    
    if type(a) == "table" and type(b) == "table" then 
        c = b.char 
        d = b.line 
        b = a.line 
        a = a.char 

        goto CheckParamsAgain 
    end 

    table.insert(self.highlights, {
        start = {
            char = a, 
            line = b
        },
        ending = {
            char = c, 
            line = d 
        }
    })
end

function self:ClearHighlights()
    self.highlights = {}
end 

function self:Highlight(start, ending, i, c, col)
    if not start or not ending or not i or not c then return end 

    local line = self.data.context[i] 

    if not line then return end 

    line = line.text 

    col = col or self.colors.highlights

    surface.SetDrawColor(col)

    if start.line == ending.line and i == start.line then -- If selection is in the same Line 
        local sx,sy = self:pop(start.char, c)
        local ex,ey = self:pop(ending.char, c)

        if ending.char > start.char then 
            surface.DrawRect(sx, sy, ex - sx, self.font.h)
        else
            surface.DrawRect(ex, ey, sx - ex, self.font.h)
        end
    elseif i == ending.line then -- if multiline, end of line selection
        if ending.line > start.line then 
            local ex,ey = self:pop(ending.char, c)
            local sx,sy = self:pop(0, c)

            surface.DrawRect(sx, sy, ex - sx, self.font.h)
        else
            local sx,sy = self:pop(ending.char, c)
            local ex,ey = self:pop(#line, c)     

            surface.DrawRect(sx, sy, ex - sx, self.font.h)               
        end
    elseif i == start.line then -- if multiline, start of line selection
        if ending.line > start.line then 
            local sx,sy = self:pop(start.char, c)
            local ex,ey = self:pop(#line, c)

            surface.DrawRect(sx, sy, math.max(ex - sx, self.font.w), self.font.h)
        else
            local ex,ey = self:pop(start.char, c)
            local sx,sy = self:pop(0, c)

            surface.DrawRect(sx, sy, math.max(ex - sx, self.font.w), self.font.h)
        end
    elseif ((i >= start.line and i <= ending.line) or (i <= start.line and i >= ending.line)) then -- All Lines inbetween Start and End of Selection  
        local sx,sy = self:pop(0, c)
        local ex,ey = self:pop(#line, c)

        surface.DrawRect(sx, sy, math.max(ex - sx, self.font.w), self.font.h)
    end
end

function self:PaintTokensAt(tokens, x, y, maxChars)
    if not tokens then return end 

    maxChars = maxChars or self:VisibleChars()

    local errors = {}

    local lastY = 0

    for tokenIndex, token in ipairs(tokens) do 
        local txt = token.text

        if token.type == "endofline" and self.textPos.char <= token.start then
            draw.SimpleText("⮯", self.font.n, x + lastY, y, self.colors.tabIndicators)
            break        
        elseif token.type == "error" then 
            table.insert(errors, token)
        end

        if token.ending < self.textPos.char or token.start > self.textPos.char + maxChars then 
            continue
        elseif token.start < self.textPos.char and token.ending >= self.textPos.char then  
            txt = string.sub(txt, self.textPos.char - token.start + 1, #txt)
        end

        local textY, _ = draw.SimpleText(txt, self.font.n, x + lastY, y, (not token.color and self.data.profile.colors[token.type] or self.data.profile.colors[token.color]) or Color(255,255,255))

        lastY = lastY + textY
    end

    return errors 
end

function self:ToggleCaret()
    self.caretBlink = RealTime() + 0.33
    self.caretToggle = true 
end

function self:PaintCaret(x, w, i, c, index)
    if self.caretToggle == nil then self.caretToggle = false end

    if RealTime() > self.caretBlink then 
        self.caretToggle = !self.caretToggle
        self.caretBlink = RealTime() + 0.33
    end 

    if index == self.caret.line then
        draw.RoundedBox(0, 0, c * self.font.h, w, 1, self.colors.currentLineOutlines)
        draw.RoundedBox(0, 0, c * self.font.h, w, self.font.h, self.colors.currentLine)
        draw.RoundedBox(0, 0, (c + 1) * self.font.h, w, 1, self.colors.currentLineOutlines)

        if self.caretToggle == true then 
            if self.caret.char + self.textPos.char >= self.textPos.char then 
                draw.RoundedBox(0, x + self.font.w * (self.caret.char - self.textPos.char + 1), c * self.font.h, 2, self.font.h, self.colors.caret)
            end
        end  
    else 
     --   self.data:TrimRight(i) maybe someday ill add this back (removed cause it will fuck with  undo & redo)
    end
end 

function self:PaintHighlights(i, c)
    if #self.highlights > 0 then 
        for _, v in ipairs(self.highlights) do 
            self:Highlight(v.start, v.ending, i, c)
        end
    end
end

function self:PaintSurroundingPairs(i, c)
    if not self.surroundingPairs then return end 
    surface.SetDrawColor(self.colors.pairHighlights)

    local s = self.surroundingPairs.start 
    local e = self.surroundingPairs.ending 

    if s and e and s.line == e.line and s.tkIndex + 1 == e.tkIndex and i == s.line then 
        local startToken = self.data.context[s.line].tokens[s.tkIndex]
        local endToken   = self.data.context[e.line].tokens[e.tkIndex]
        if startToken and endToken then 
            local x, y = self:pop(startToken.start - 1, c)
            surface.DrawOutlinedRect(x, y, (#startToken.text + #endToken.text) * self.font.w, self.font.h, 1)
            return 
        end 
    end

    if s and s.line == i then 
        local token = self.data.context[s.line].tokens[s.tkIndex]
        if token then 
            local x, y = self:pop(token.start - 1, c)
            surface.DrawOutlinedRect(x, y, #token.text * self.font.w, self.font.h, 1)
        end 
    end
    
    if e and e.line == i then 
        local token = self.data.context[e.line].tokens[e.tkIndex]
        if token then 
            local x, y = self:pop(token.start - 1, c)
            surface.DrawOutlinedRect(x, y, #token.text * self.font.w, self.font.h, 1)
        end 
    end
end

function self:Paint(w, h)
    self:PaintBefore(w, h)

    local i = self.textPos.line 

    local mx, my = self:LocalCursorPos()

    -- Background 
    draw.RoundedBox(0,0,0,w,h,self.colors.background)

    local i = self.textPos.line 
    local c = 0

    local lineNumCharCount = self:GetLineNumberCharCount()
    local lineNumWidth     = self:GetLineNumberWidth()

    local visLines = self:VisibleLines() 
    local visChars = self:VisibleChars()

    local x = offset * 2 + lineNumWidth 

    -- Backgrounds 
    draw.RoundedBox(0, 0, 0, x, h, self.colors.lineNumbersBackground)
    draw.RoundedBox(0, x, 0, 1, h, self.colors.linesEditorDivider)
    
    local currentHover

    local bruh = 1
    while i < self.textPos.line + visLines do 
        if bruh > #self.data.context * 2 then print("infinite loop") break end bruh = bruh + 1 

        local cLine = self.data.context[i]
        if not cLine then break end 

        -- Line Numbers 
        draw.SimpleText(cLine.index, self.font.n, offset + lineNumWidth * ((lineNumCharCount - #tostring(cLine.index)) / lineNumCharCount), c * self.font.h, self.colors.lineNumbers)
        
        self:PaintCaret(textoffset + x, w, i, c, cLine.index)

        -- This does the Syntax Coloring
        self:PaintTokensAt(cLine.tokens, textoffset + x, c * self.font.h, visChars)  

        -- Selection 
        if self:IsSelecting() == true then 
            self:Highlight(self.selection.start, self.selection.ending, i, c, self.colors.selection)
        end

        -- Highlights
        self:PaintHighlights(i, c)

        -- Surrounding Pairs 
        self:PaintSurroundingPairs(i, c)

        do -- Tab Indicators 
            local tab = self.allTabs[cLine.index]

            if tab then 
                for n = 2, tab, 1 do 
                    local tabLen = (n - 1) * self.tabSize

                    if tabLen < 0 or (tabLen >= getLeftLen(cLine.text) and cLine.text ~= "") then break end 

                    local posX = (tabLen - math.max(self.textPos.char - 1, 0)) * self.font.w

                    if posX < 0 then continue end 

                    draw.RoundedBox(0, x + posX, c * self.font.h, 1, self.font.h, self.colors.tabIndicators)
                end
            end
        end 

        -- Code Folding Indication and Preview 
        if IsValid(cLine.button) and cLine.folding and cLine.folding.folds then 
            cLine.button:SetSize(offset * 0.75, cLine.button:GetWide())
            cLine.button:SetVisible((mx > 0 and mx <= textoffset + x) or (#cLine.folding.folds > 0))
            cLine.button:SetPos(x - offset + offset * 0.15, c * self.font.h + (self.font.h / 2 - cLine.button:GetTall() / 2) - 4)

            if cLine.button:IsHovered() == true then 
                currentHover = {cLine, i}

                if #cLine.folding.folds == 0 then -- When unfolded, show the area that will be folded 
                    draw.RoundedBox(0, x, (c + 1) * self.font.h, w, self.font.h * (cLine.folding.available or 0), self.colors.foldingAreaIndicator)
                    draw.RoundedBox(0, x, (c + 1) * self.font.h, self:GetWide() - x, 1, self.colors.foldingIndicator)
                    draw.RoundedBox(0, x, (c + 1 + (cLine.folding.available or 0)) * self.font.h, self:GetWide() - x, 1, self.colors.foldingIndicator)
                else -- If its folded and button is hovered, show the text that could get unfolded 
                    local len = math.min(#cLine.folding.folds, visLines - c - 1)

                    draw.RoundedBox(0, x, (c + 1) * self.font.h, w, len * self.font.h, self.colors.foldsPreviewBackground)

                    for i = 1, len, 1 do 
                        local l = cLine.folding.folds[i]
                        local lf = l.folding

                        if lf and #lf.folds > 0 then 
                            draw.SimpleText(" < " .. #lf.folds .. " Line" .. (#lf.folds > 1 and "s" or "") .. " hidden >", self.font.n, x + math.max(l.tokens[#l.tokens].ending + 1 - self.textPos.char, 0) * self.font.w, (c + i) * self.font.h, self.colors.amountOfFoldedLines)
                            draw.RoundedBox(0, x, (c + i + 1) * self.font.h, self:GetWide() - x, 1, self.colors.foldingIndicator) 
                        end

                        -- Color the folded lines preview 
                        self:PaintTokensAt(cLine.folding.folds[i].tokens, textoffset + x, (c + i) * self.font.h, visChars)  
                    end

                    draw.RoundedBox(0, 0, (c + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)
                    draw.RoundedBox(0, 0, (c + len + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)

                    c = c + len 
                    skips = len 
                end
            elseif isFolding(cLine) == true then -- WHen folded but not hovered, show where the fold is 
                draw.SimpleText(" < " .. #cLine.folding.folds .. " Line" .. (#cLine.folding.folds > 1 and "s" or "") .. " hidden >", self.font.n, x + math.max(cLine.tokens[#cLine.tokens].ending + 1 - self.textPos.char, 0) * self.font.w, c * self.font.h, self.colors.amountOfFoldedLines)

                if not currentHover 
                or IsValid(currentHover[1].button) == false 
                or (IsValid(currentHover[1].button) == true and (i <= currentHover[2] or currentHover[2] + (currentHover[1].folding.available or 0) <= i)) then  
                    draw.RoundedBox(0, x, c * self.font.h, w, self.font.h, self.colors.foldingAreaIndicator) -- We dont want the indicators to overlap in the case of a fold inside a hovered fold
                end 

                draw.RoundedBox(0, 0, (c + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)
            end
        elseif cLine.button ~= nil then self.data.context[i].button = nil
        elseif IsValid(cLine.button) and cLine.folding and cLine.folding.folds then self:HandleBadButton(cLine.button) end 

        i = i + 1
        c = c + 1
    
        if i > #self.data.context then break end 
    end

    self.scroller:SetUp(visLines + 1, #self.data.context + visLines)

    -- End of Text box 
    local diff = -(i - visLines) + 1 + self.scroller:GetScroll()
    if diff > 0 then 
        draw.RoundedBox(0, 0, c * self.font.h, w, diff * self.font.h, self.colors.endOfText)
    end 

    self:PaintAfter(w, h)
end

function self:IsShift()
    return input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT)
end

function self:IsCtrl()
    return input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)
end

function self:PerformLayout(w, h)

end

function self:OnScrolled() end 
function self:_OnScrolled(diff)
    self:ParseVisibleLines()
    self:GetTabLevels()
    self:HideButtons()
    self:ClearHighlights()
    self:HighlightPressedWord()
    self:OnScrolled(diff)
end

function self:OnMouseWheeled(delta)
    if self:IsCtrl() == false then 
        self.scroller:SetScroll(self.scroller:GetScroll() - delta * 4)
    else 
        self:SetFont(self.font.an, self.font.s - delta * 2)
    end
end

function self:HighlightSelectedWords()
    if tableSame(self.selection, self.lastSelection or {}) == false then 
        self:ClearHighlights()

        local selectedText = self.data:GetTextArea(self.selection.start, self.selection.ending)

        if selectedText then 
            self.pressedWord = selectedText
            self:HighlightPressedWord()
        end

        self.lastSelection = table.Copy(self.selection) 
    end
end

function self:Think()
    self.textPos:Set()

    if self.textPos.line ~= self.lastTextPos.line then 
        self:_OnScrolled(self.textPos.line - self.lastTextPos.line)
    end

    if RealTime() > self.refresh then 
        self:RefreshData()
        self:TimeRefresh(10)
    end

    if input.IsMouseDown(MOUSE_LEFT) == true then 
        if vgui.GetHoveredPanel() == self and self.scroller.Dragging == false and self.mouseCounter == 1 then 
            self:SetCaret(self:pit(self:LocalCursorPos()))

            if self.selectionStartFix then 
                self:SetSelection(self.selection.start.char, self.selection.start.line, self.caret.char, self.caret.actualLine)
            else 
                self.selectionStartFix = true 
                self:ResetSelection()
            end

            if self.selection.start.line == self.selection.ending.line and self.selection.start.char ~= self.selection.ending.char then 
                self:HighlightSelectedWords()
            elseif 
            (self.selection.start.line == self.selection.ending.line and self.selection.start.char == self.selection.ending.char and tableSame(self.caret, self.lastCaret) == false) 
            or self.selection.start.line ~= self.selection.ending.line 
            then 
                self:ClearHighlights()
            end 

        end
    elseif self:IsShift() == true then 
        self:HighlightSelectedWords()
    end

    self:ContinueBackgroundWorker()
    self:CaretStoppedMovingHandler()

    self.lastTextPos = table.Copy(self.textPos)
end

local bFont 
function self:MakeFoldButton()
    local button = vgui.Create("DButton", self)

    if not bFont then 
        bFont = {
            font      = "Consolas",
            size      = 35,
            weight    = 550 
        }
        surface.CreateFont("SSLEFoldButtonFont", bFont)
    end

    button:SetFont("SSLEFoldButtonFont")

    button:SetVisible(false)
    button.Paint = function()
        button:SetTextColor((button:IsHovered() or button.foldStatus == true) and dark(160) or dark(110))
    end

    button.foldStatus = false 
    button.SetFolded = function(self, status)
        if status == true then 
            button:SetText("⯈")
        else
            button:SetText("⯆")
        end
        self.foldStatus = status 
    end

    button:SetTextColor(dark(110))

    button:SetAutoStretchVertical(true)
    button:SizeToContentsY()

    button:SetFolded(false)

    return button 
end

vgui.Register("DSyntaxBox", self, "DPanel")

