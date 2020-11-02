--[[
    Derma Editor with Syntax Coloring

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

if not SSLE then 
	MsgC(Color(255,0,0), "Couldn't mount SyntaxBox.") 
	return 
end

if not SSLE.modules or not SSLE.modules.lexer then 
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Failed to load DSyntaxBox, Lexer does not exist!")
    return 
end

local coroutine_create = coroutine.create 
local coroutine_yield  = coroutine.yield 
local coroutine_wait   = coroutine.wait 
local coroutine_status = coroutine.status 
local coroutine_resume = coroutine.resume

local string_sub  = string.sub
local string_find = string.find
local string_byte = string.byte  

local table_insert = table.insert 
local table_remove = table.remove
local table_Copy   = table.Copy 
local table_Count  = table.Count 

local syntaxBox = {}
local fontBank = {}

local function dark(i)
    return Color(i,i,i)
end

local function out(s)
    print("'"..s.."'")
end

--[[
                                         _____                       _              ___  _                 
                                        /  __ \                     | |            / _ \| |                
                                        | /  \/ ___  _ __ ___  _ __ | | _____  __ / /_\ \ | __ _  ___  ___ 
                                        | |    / _ \| '_ ` _ \| '_ \| |/ _ \ \/ / |  _  | |/ _` |/ _ \/ __|
                                        | \__/\ (_) | | | | | | |_) | |  __/>  <  | | | | | (_| | (_) \__ \
                                         \____/\___/|_| |_| |_| .__/|_|\___/_/\_\ \_| |_/_|\__, |\___/|___/
                                                              | |                           __/ |          
                                                              |_|                          |___/           
]]

-- SOME OF THESE ALGORITHMS ARE SUPER SHIT!!! IF YOU CAN DO IT BETTER,     DO   IT   !

function syntaxBox:GetTokenAtPoint(char, line)
    if not char or not line then return nil end 
    if not self.lines[line] then return nil end 
    if not self.lines[line][char] then return nil end 
    local tokens = self.tokens[line]
    if tokens == nil then return nil end 
    for _, token in pairs(tokens) do 
        if (token.start <= char and token.ending >= char) then 
            return token, _
        end
    end
    return nil 
end

function syntaxBox:TokenAtCaret()
    return self:GetTokenAtPoint(self.caret.char, self.caret.line)
end

function syntaxBox:GetSurroundingPairs(char, line)
    if not char or not line then return nil end 
    local tokenUnderCaret, tkIndex = self:GetTokenAtPoint(char, line)
    tokenUnderCaret = tokenUnderCaret or {}
    tkIndex = tkIndex or 0
    local start = nil 
    local ending = nil 
    local nextIsPair = false
    if tokenUnderCaret.text then 
        for group, pair in pairs(self.lexer.config.closingPairs) do 
            if tokenUnderCaret.text == pair[2] then 
                ending = {
                    line = line,
                    char = tokenUnderCaret.start,
                    group = group 
                }
                break
            end         
        end
    end 
    if not ending then 
        local nextToken, _ = self:GetTokenAtPoint(char + 1, line)
        if nextToken and nextToken.text then 
            for group, pair in pairs(self.lexer.config.closingPairs) do 
                if nextToken.text == pair[1] then 
                    start = {
                        line = line,
                        char = nextToken.start,
                        group = group 
                    }
                    nextIsPair = true 
                    break
                end         
            end       
        end      
    end 
    if not start then  
        local tkCounter = tkIndex 
        local lnCounter = line
        local tk = tokenUnderCaret 
        local cCounter = {}
        if ending then 
            cCounter[ending.group] = -1
        end
        while true do    
            if tk then 
                local found = false 
                for group, pair in pairs(self.lexer.config.closingPairs) do 
                    if not cCounter[group] then cCounter[group] = 0 end 
                    if tk.text == pair[1] then
                        if cCounter[group] == 0 then  
                            if (ending and ending.group ~= group) or tk.text ~= pair[1] then 
                                continue
                            end
                            start = {
                                line = lnCounter,
                                char = tk.start,
                                group = group 
                            }
                            found = true 
                            break
                        else 
                            cCounter[group] = cCounter[group] - 1
                        end
                    elseif tk.text == pair[2] then 
                        cCounter[group] = cCounter[group] + 1
                    end
                end
                if found == true then 
                    break 
                end
            end 
            tkCounter = tkCounter - 1
            if tkCounter < 1 then 
                lnCounter = lnCounter - 1
            
                if not self.tokens[lnCounter] then 
               --     self.tokens[lnCounter] = self.lexer:ParseLine(lnCounter, self.tokens[lnCounter - 1]) -- super shitty workaround but fuck it
                    self:LexLine(lnCounter, false)
                end
                local lastTK = #(self.tokens[lnCounter] or {})
                tkCounter = lastTK 
                if lnCounter < 1 then break end 
            end
            tk = (self.tokens[lnCounter] or {})[tkCounter] or {}
        end
    end

    if not ending and start then  
        local tkCounter = tkIndex + 1
        local lnCounter = line
        local tk = (self.tokens[lnCounter] or {})[tkCounter] or {}
        local cCounter = {}
        if start and nextIsPair == true then 
            cCounter[start.group] = -1
        end
        while true do    
            if not self.tokens[lnCounter] then 
               -- self.tokens[lnCounter] = self.lexer:ParseLine(lnCounter, self.tokens[lnCounter - 1]) -- super shitty workaround but fuck it
               self:LexLine(lnCounter, false) 
               tk = self.tokens[lnCounter]
            end
            if tk then 
                local found = false 
                for group, pair in pairs(self.lexer.config.closingPairs) do 
                    if not cCounter[group] then cCounter[group] = 0 end 
                    if tk.text == pair[2] then
                        if cCounter[group] == 0 then  
                            if (start and start.group ~= group) or tk.text ~= pair[2] then 
                                continue
                            end
                            ending = {
                                line = lnCounter,
                                char = tk.start,
                                group = group 
                            }
                            found = true 
                            break
                        else 
                            cCounter[group] = cCounter[group] - 1
                        end
                    elseif tk.text == pair[1] then 
                        cCounter[group] = cCounter[group] + 1
                    end
                end
                if found == true then 
                    break 
                end   
            end 
            tkCounter = tkCounter + 1
            if tkCounter > #(self.tokens[lnCounter] or {}) then 
                lnCounter = lnCounter + 1
                tkCounter = 1
                if lnCounter > #(self.lines or {}) then 
                    break 
                end 
            end
            tk = (self.tokens[lnCounter] or {})[tkCounter] or {}
        end 
    end
    if start and ending then 
        return {start = start,ending = ending}
    elseif not start then 
        if ending then 
            return {ending=ending}
        end
        return nil 
    elseif ending and not start then 
        return {start=start}
    elseif (ending or {}).group ~= (start or {}).group then
        if start then return {start=start}
        elseif ending then return {ending=ending}
        else return nil end 
    end 
  --  return {start = start,ending = ending}
end

function syntaxBox:FindPairMatch(char, line)
    local tokenUnderCaret, tkIndex = self:GetTokenAtPoint(char, line)
    if tokenUnderCaret then 
        local selPair = nil
        local isRight = false 
        for _, pair in pairs(self.lexer.config.closingPairs) do 
            if tokenUnderCaret.text == pair[1] or tokenUnderCaret.text == pair[2] then 
                if tokenUnderCaret.text == pair[2] then 
                    isRight = true 
                end
                selPair = pair 
                break
            end
        end
        if selPair then 
            local closer    = nil
            local tkCounter = tkIndex
            local lnCounter = line
            local cCounter  = 0
            if isRight == true then 
                local interrupt = 0
                while true do 
                    tkCounter = tkCounter - 1
                    if tkCounter < 1 then 
                        lnCounter = lnCounter - 1
                        local lastTK = #(self.tokens[lnCounter] or {})
                        if not lastTK then break end 
                        tkCounter = lastTK
                        if lnCounter < 1 then break end 
                    end
                    local tk = self.tokens[lnCounter][tkCounter]
                    if tk == nil then 
                        if not self.lines[lnCounter] then 
                            continue 
                        end 
                      --  self.tokens[lnCounter] = self.lexer:ParseLine(lnCounter, self.tokens[lnCounter - 1] or {}) -- Haha eat my ass 
                        self:LexLines(lnCounter, false)
                        tk = self.tokens[lnCounter]
                    end 
                    if tk.text == selPair[2] then 
                        cCounter = cCounter + 1 
                    elseif tk.text == selPair[1] then 
                        if cCounter <= 0 then 
                            closer = {line=lnCounter, token=tkCounter}
                            break  
                        end
                        cCounter = cCounter - 1  
                    end 
                end
            else
                while true do 
                    tkCounter = tkCounter + 1
                    if tkCounter > #self.tokens[lnCounter] then 
                        lnCounter = lnCounter + 1
                        tkCounter = 0
                        if lnCounter > #self.lines then 
                            break
                         end 
                    end
                    local tk = self.tokens[lnCounter][tkCounter]
                    if tk == nil then 
                        if not self.lines[lnCounter] then continue end 
                     --   self.tokens[lnCounter] = self.lexer:ParseLine(lnCounter, self.tokens[lnCounter - 1] or {}) -- Haha eat my ass 
                        self:LexLines(lnCounter, false)
                        tk = self.tokens[lnCounter]
                    end 
                    if tk.text == selPair[1] then 
                        cCounter = cCounter + 1 
                    elseif tk.text == selPair[2] then 
                        if cCounter <= 0 then 
                            closer = {line=lnCounter, token=tkCounter}
                            break  
                        end
                        cCounter = cCounter - 1  
                    end 
                end
            end
            if closer then 
                local tk = self.tokens[closer.line][closer.token]
                return {
                    start = {
                        char = char,
                        line = line
                    },
                    ending = {
                        char = tk.start,
                        line = closer.line 
                    }
                }
            else 
                return {
                    start = {
                        char = char,
                        line = line
                    }
                }
            end
        end
    end
    return nil 
end

function syntaxBox:TrimRightLine(i)
    local curTokens = self.tokens[i]
    local line = self.lines[i]
    if not curTokens or not line then return end 
    if (curTokens[#curTokens - 1] or {}).type == "whitespace" and (curTokens[#curTokens] or {}).type == "newline" then 
        local _, _, right = string_find(line, "(%s*)$")
        if right then 
            local tempLine = string_sub(line, 1, #line - #right)
            self.lines[i], line = tempLine, tempLine
            table_remove(self.tokens[i], #curTokens - 1)
        end 
    end 
end

function syntaxBox:TrimRight()
    if not self.lines then return end 
    if not self.tokens then return end 
    for i, _ in pairs(self.tokens) do 
        self:TrimRightLine(i)
    end 
end

function syntaxBox:UpdateTabIndicators()
    self.allTabs = {}
    local function saveTab(cc, tab) self.allTabs[cc] = tab end
    local lastTabs = ""
    local visualTabs = {}
    local m = (self.textPos.line - 1) ~= 0 and -1 or 0
    local c = m
    for i = self.textPos.line + m, self.textPos.line + math.ceil(self:GetTall() / self.font.h) + 1, 1 do 
        local line = self.lines[i]
        if not line then continue end 
        local _, _, left = string_find(line, "^([%s\t]*)")
        left = string.gsub(left, "\t", "    ")
        if string.gsub(line, "%s", "") == "" then  
            table_insert(visualTabs, c)
        else 
            if #left < #lastTabs then 
                for _, vt in pairs(visualTabs) do saveTab(vt, left .. " ") end
            else 
                for _, vt in pairs(visualTabs) do saveTab(vt, lastTabs .. " ") end            
            end
            visualTabs = {}   
            saveTab(c, left)
            lastTabs = left
        end
        c=c+1
    end
end

function syntaxBox:IsPair(line, tkIndex)
    if not line or not tkIndex or not self.tokens[line] or not self.tokens[line][tkIndex] then return nil end 
    local tk = self.tokens[line][tkIndex]
    for _, pair in pairs(self.lexer.config.closingPairs) do 
        if pair[1] == tk.text then return "left" 
        elseif pair[2] == tk.text then return "right" end 
    end
    return nil 
end

function syntaxBox:TextIsPair(text)
    if not text then return nil end 
    for t, pair in pairs(self.lexer.config.closingPairs) do 
        if pair[1] == text then return {t, true}  
        elseif pair[2] == text then return {t, false} end 
    end
    return nil 
end

function syntaxBox:TextIsReserved(text) 
    if not text then return nil end 
    for _, group in pairs(self.lexer.config.reserved) do 
        for  _, char in pairs(group) do 
            if text == char then return true end 
        end 
    end
    return nil 
end

function syntaxBox:GetTextFrom(start, ending)
    if not start or not ending then return "" end 
    local function flip()
        local save = table_Copy(ending)
        ending = table_Copy(start)
        start = table_Copy(save)      
    end
    if start.line ~= ending.line and ending.line < start.line then 
        flip()
    elseif start.line == ending.line and start.char > ending.char then 
        flip()
    end
    local r = ""
    local lineCounter = start.line 
    local charCounter = start.char + 1
    local function atEnd() return lineCounter >= ending.line and charCounter > ending.char end
    while true do 
        local line = self.lines[lineCounter]
        if not line then break end 
        if charCounter > #line then 
            r = r .. "\n"
            if atEnd() then break end 
            lineCounter = lineCounter + 1
            charCounter = 0
            continue 
        end 
        local char = line[charCounter] or ""
        r = r .. char 
        charCounter = charCounter + 1
        if atEnd() then break end 
    end
    return r  
end

function syntaxBox:reindex(t)
    if not t then return end 
    local c = 1
    local max = table_Count(t)
    for key, value in pairs(t) do 
        if key ~= c then 
            t[c] = value
        end 
        c = c + 1
    end
    return t 
end

function syntaxBox:PasteTextAt(text, char, line, ressel)
    if not text or not char or not line then return end 
    local right = string_sub(self.lines[line], char + 1, #self.lines[line])
    self.lines[line] = string_sub(self.lines[line], 1, char)
    local lineCounter = line 
    for i = 1, #text, 1 do 
        local char = text[i]
        if char == "\n" then 
            table_insert(self.lines, lineCounter + 1, "")
            lineCounter = lineCounter + 1
            continue 
        end
        self.lines[lineCounter] = self.lines[lineCounter] .. char 
    end
    self.caret.char = #self.lines[lineCounter]
    self.lines[lineCounter] = self.lines[lineCounter] .. right 
    self.caret.line = lineCounter 
    if not ressel then 
        self.arrowSelecting = false 
        self.mouseSelecting = false 
        self:ResetSelection()
    end 
    self:FixCaret()
    self.hasChanges = true 
end

function syntaxBox:RemoveTextFromTo(start, ending)
    if not start or not ending then return end 
    local function flip()
        local save = table_Copy(ending)
        ending = table_Copy(start)
        start = table_Copy(save)      
    end
    if start.line ~= ending.line and ending.line < start.line then 
        flip()
    elseif start.line == ending.line and start.char > ending.char then 
        flip()
    end
    if start.line ~= ending.line then 
        local startline = self.lines[start.line]
        local endline   = self.lines[ending.line]
        if not endline or not startline then return end 
        for i = start.line, ending.line - 1, 1 do 
            table_remove(self.lines, start.line + 1)
        end
        self.lines[start.line] = string_sub(startline, 1, start.char)..string_sub(endline, ending.char + 1, #endline)
    else 
        local line = self.lines[start.line]
        self.lines[start.line] = string_sub(line, 1, start.char)..string_sub(line, ending.char + 1, #line) 
    end 
    self:SetCaret(start)
    self:FixCaret()
end 

function syntaxBox:GetWordAtPoint(char, line)
    if not char or not line then return nil, nil end 
    local line = self.lines[line]
    if not line then return nil, nil end 
    local res = ""
    local back = true 
    local charCounter = char  
    local start = charCounter
    while true do 
        local c = line[charCounter]
        if not c then break end 
        if back == true then 
            if isSpecial(c) == true and not (self.lexer.config.unreserved or {})[c] then 
                back = false 
                charCounter = charCounter + 1
                start = charCounter
                continue 
            end
            charCounter = charCounter - 1
            if charCounter < 0 then 
                start = 0
                charCounter = 0
                back = false 
            end 
        else 
            if isSpecial(c) == true and not (self.lexer.config.unreserved or {})[c] then 
                break 
            end
            res = res .. c 
            charCounter = charCounter + 1
            if charCounter > #line then 
                break 
            end 
        end
    end 
    if res == "" then return nil, nil end 
    return res, start 
end

function syntaxBox:HighlightTokens(word)
    self:ResetHighlighting()
    if not word or whitespace(word) == true then return end 
    for i = self.textPos.line, self.textPos.line + math.ceil(self:GetTall() / self.font.h) - 1, 1 do 
        local tokens = self.tokens[i]
        if not tokens then self:ParseVisibleLines() end
        if not tokens then break end 
        for _, token in pairs(tokens) do 
            if token.text == word then 
                self:AddHighlight(token.start - 1, i, token.ending, i)
            end
        end
    end
end

function syntaxBox:HighlightWords(word)
    self:ResetHighlighting()
    if not word or whitespace(word) == true then return end 
    for i = self.textPos.line, self.textPos.line + math.ceil(self:GetTall() / self.font.h) - 1, 1 do 
        local line = self.lines[i]
        if not line then continue end 
        local l = 1
        while l < #line do 
            local char = line[l]
            local ending = l + #word - 1
            local sub = string_sub(line, l, ending)
            if sub == word then 
                self:AddHighlight(l - 1, i, ending, i)
                l = ending
            end
            l=l+1
        end
    end    
end

local function getLeft(str)
    if not str then return "" end 
    local _,_,left = string.find(str, "^(%s*)")
    if not left then return "" end 
    return left
end

function syntaxBox:CountTokenMatches(i, needle, validator, ...)
    if not needle then return 0 end 
    local tokens = self.tokens[i]
    if not tokens then 
      --  self.lexer:ParseLine(i, self.tokens[i - 1] or nil) 
        self:LexLine(i, false)
        tokens = self.tokens[i]
    end
    if not tokens then return 0 end 
    if not validator then validator = function() return true end end 
    local result = 0
    for _, token in pairs(tokens) do 
        if token.text == needle and validator(token.text, token.start, ...) == true then 
            result = result + 1
        end
    end
    return result 
end

-- I STRONGLY ADVICE TO NOT CHANGE THIS FUNCTION
-- This is already the 4-5th version of the auto-indenting algorithm. Do NOT change this, unless you ABSOLUTELY KNOW what you're doing!
function syntaxBox:GetLineIndention(index)
    if not index or not self.lines[index] then return "" end 
    local tabs = string.rep(" ", self.tabSize)

    local function countClose(c, line)
        local res = 0
        for _, word in pairs((self.lexer.config.indentation or {}).close or {}) do 
            res = res + self:CountTokenMatches(c, word, self.lexer.config.indentation.closeValidation, c, line)
        end
        return res 
    end
    local function countOpen(c, line)
        local res = 0
        for _, word in pairs((self.lexer.config.indentation or {}).open or {}) do 
            res = res + self:CountTokenMatches(c, word, self.lexer.config.indentation.openValidation, c, line)
        end
        return res 
    end

    local iCount = 0

    local top = ""
    do 
        local waitingForWhitespace = true
        for i = index, 1, -1 do 

            -- We have to relex these lines, to avoid conflicts between the previous and current lines 
            self:LexLine(i)

            local line = self.lines[i]

            if not line then 
                return "" 
            end

            if i == index then 
                local closers = countClose(i, line)
                local openers = countOpen(i, line)
                iCount = closers - openers
                continue 
            end 

            if waitingForWhitespace == true then 
                if whitespace(line) == true then 
                    continue 
                else 
                    waitingForWhitespace = false 
                end
            end

            local closers = countClose(i, line)
            local openers = countOpen(i, line)

            if closers == 0 and openers == 0 then continue end 
            if closers == openers then continue end 

            if index == i then continue end 

            if closers > openers then 
                top = getLeft(line)
            else  
                top = getLeft(line) .. tabs
            end 

            break 
        end
    end 

    local bot = ""
    do 
        local waitingForWhitespace = true

        for i = index, #self.lines, 1 do 
            if i == index then continue end 

            -- We have to relex these lines, to avoid conflicts between the previous and current lines 
            self:LexLine(i)

            local line = self.lines[i]
            if not line then 
                return "" 
            end

            if waitingForWhitespace == true then 
                if whitespace(line) == true then 
                    continue 
                else 
                    waitingForWhitespace = false 
                end
            end

            local closers = countClose(i, line)
            local openers = countOpen(i, line)

            if closers == 0 and openers == 0 then continue end 
            if closers == openers then continue end 

            if index == i then continue end 

            if closers < openers then 
                bot = getLeft(line)
            else  
                bot = getLeft(line) .. tabs
            end 

            break 
        end 
    end

    local result = ""

    do 
        local centre = (#top + #bot) / 2 
        centre = centre + (centre % self.tabSize)

        if #bot == #top and #bot == centre then 
            result = string.rep(" ", #bot - (iCount ~= 0 and self.tabSize or 0)) 
        else 
            if iCount ~= 0 then 
                centre = centre - self.tabSize 
            end

            result = string.rep(" ", centre)
        end
    end

    local new = self:TrimIndentation(result, index) 

    if new ~= result and iCount ~= 0 then 
        new = string.rep(" ", self.tabSize) .. new 
    end

    return new
end

function syntaxBox:TrimIndentation(tabs, i)
    if not self.lexer.config.indentation.offsets then 
        return tabs 
    end 

    self:LexLine(i)

    local line = self:GetLine(i) 

    if not line then 
        return tabs 
    end 

    if whitespace(line) == true then 
        return tabs
     end 

    line = string.TrimLeft(line, " ")

    for word, offset in pairs(self.lexer.config.indentation.offsets) do 
        local a,b,_ = string_find(line, word)

        if not a or not b then continue end 
        if a ~= 1 then continue end 

        if string_sub(line, 1, b) == word then 
            if offset == false then 
                return "" 
            end 

            if offset < 0 then 
                offset = math.abs(offset)
                return string_sub(tabs, self.tabSize * (offset) + 1, #tabs)
            end 
            
            return tabs .. string.rep(" ", self.tabSize * offset)
        end
    end

    return tabs  
end

function syntaxBox:LineInsideCapture(i)
    if not i or not self.lines[i] then return false end 
   -- if not self.tokens[i] then self.LexLine(i) end 
    if not self.tokens[i] then return false end 
    for group, data in pairs(self.lexer.config.captures) do 
        if ((self.tokens[i] or {})[1] or {}).type == group then 
            return true 
        end
    end
    return false 
end

function syntaxBox:IntendLine(i)
    if not i or not self.lines[i] or self:LineInsideCapture(i) == true then 
        return "" 
    end 
    local line = self:GetLine(i)
    if self.lexer.config.language == "Plain" or self:LineInsideCapture(i) == true then 
        return getLeft(line) 
    end 
    local _,_,left = string_find(line, "^(%s*)") 
    left = left or ""
    if whitespace(line) == true then 
        local tabs = self:GetLineIndention(i)
        local add = tabs .. line
        self.lines[i] = add
        return add 
    end 
 --   elseif #left == 0 then 
        local add = self:GetLineIndention(i) 
        self.lines[i] = add .. self.lines[i]
        return add 
  --  end 
    --[[
    print("c")
    self.lines[i] = string.TrimLeft(line, " ")
    local ind = self:GetLineIndention(i)
    local r = ind .. string.TrimLeft(line, " ")
    self.lines[i] = r 
    return ind]]
end

function syntaxBox:Undo()
    if self.undoTimeout and self.undoTimeout >= RealTime() then return end 
	if #self.undo or 0 > 0 then
        local undo = self.undo[#self.undo]
        self:ResetSelection()
        self.arrowSelecting = false 
        self.mouseSelecting = false 
        if undo then 
            self:SaveState()
            local released = 0
            local centerLine = 0 
            local c = 0
            for i, str in pairs(undo) do 
                centerLine = centerLine + i 
                c = c + 1
                if str == false then 
                    self.lines[i] = nil 
                    released = released + 1
                    continue 
                end
                self.lines[i] = str
                released = released + #str
            end
           -- centerLine = math.Round(centerLine / math.max(c, 1))
           -- self:Goto(0, centerLine)
            released = released / 1024 
            self.undoMemory = math.max(self.undoMemory - released, 0)
            self:CompState(true)
            self:OnUndo(undo)
            self.undo[#self.undo] = nil 
            self.undoTimeout = RealTime() + 0.01
            self:FixCaret()
            self.hasChanges = true 
        end
    end 
end

function syntaxBox:Redo()
    if self.redoTimeout and self.redoTimeout >= RealTime() then return end 
    if #self.redo or 0 > 0 then
        self:ResetSelection()
        self.arrowSelecting = false 
        self.mouseSelecting = false 
        local redo = self.redo[#self.redo]
        if redo then 
            self:SaveState()
            local centerLine = 0 
            local c = 0
            for i, str in pairs(redo) do    
                c = c + 1      
                centerLine = centerLine + i       
                if str == false then 
                    self.lines[i] = nil 
                    continue 
                end
                self.lines[i] = str
            end
       --     centerLine = math.Round(centerLine / math.max(c, 1))
       --     self:Goto(0, centerLine)
            self:CompState(-1)
            self:OnRedo(redo)
            self.redo[#self.redo] = nil 
            self.redoTimeout = RealTime() + 0.01
            self:FixCaret()
            self.hasChanges = true 
        end
    end
end

-- fix dis later
function syntaxBox:CheckGay() -- Funny Easteregg
 --   local function gu(i) 
 --       if not self.undo or not self.undo[#self.undo - i] then return "" end 
 --       return self.undo[#self.undo - i].text 
 --   end

 --   if string.lower(gu(2) .. gu(1) .. gu(0)) == "gay" then 
 --       self.gaymode = RealTime() + 3
 --   end
end

function syntaxBox:GetUndoMemory()
    return math.Round(self.undoMemory, 1).."kb"
end

function syntaxBox:SaveState()
    self.tempLines = table_Copy(self.lines)
end

function syntaxBox:ClearState()
    self.tempLines = nil 
end

function syntaxBox:CompState(isRedo)
    if not self.tempLines then return end 
    if not self.undo then self.undo = {} end
    local memory = 0
    local comp = compareLines(self.lines, self.tempLines)
    self:OnLinesChanged(comp[1], comp[2])
    self:_LinesChanged(comp[1], comp[2])
    local temp = {}
    for i = comp[1], comp[2], 1 do 
        local s = (self.tempLines[i] and self.tempLines[i] or false)
        temp[i] = s
        memory = memory + (type(s) == "string" and #s or 1) 
    end
    memory = memory / 1024 
    if not isRedo or isRedo == -1 then 
        self.undo[#self.undo + 1] = table_Copy(temp)
        if isRedo ~= -1 then 
            self.undoMemory = ((self.undoMemory or 0) + memory) or memory 
        end 
        if #self.undo > 1000 or self.undoMemory > 10485760 then -- 10mib
            MsgC(Color(255,0,0), "Undo or Undo-Memory limit exceeded! First Undo entry removed.\n\n")
            table_remove(self.undo, 1) 
        end
        if #self.redo > 0 and isRedo ~= -1 then self.redo = {} end    
    else 
        self.redo[#self.redo + 1] = table_Copy(temp)
    end
    self.tempLines = nil 
end

function syntaxBox:OverrideLines(start, ending, newLines)
    if not start or not ending or not newLines then return end
    local function flip()
        local save = ending
        ending = start
        start = save     
    end
    if start ~= ending and ending < start then 
        flip()
    end
    local c = 1
    for i = start, ending, 1 do 
        if not self.lines[i] or not newLines[c] then continue end 
        self.lines[i] = newLines[c]
        c=c+1
    end
end

function syntaxBox:GetLines(start,ending)
    if not start or not ending then return end
    local function flip()
        local save = ending
        ending = start
        start = save     
    end
    if start ~= ending and ending < start then 
        flip()
    end
    local c = 1
    local r = {}
    for i = start, ending, 1 do 
        if not self.lines[i] then continue end 
        r[c] = self.lines[i]
        c=c+1
    end
    return r 
end

--[[

                                 _____             _            ______           
                                /  ___|           | |           | ___ \          
                                \ `--. _   _ _ __ | |_ __ ___  _| |_/ / _____  __
                                 `--. \ | | | '_ \| __/ _` \ \/ / ___ \/ _ \ \/ /
                                /\__/ / |_| | | | | || (_| |>  <| |_/ / (_) >  < 
                                \____/ \__, |_| |_|\__\__,_/_/\_\____/ \___/_/\_\
                                        __/ |                                    
                                       |___/                                     

]]
function syntaxBox:Init()
    self:SetCursor("beam")

    ---- Config ----
    self.tabSize = 4 -- Tab space length
    self.scrollMult = 4 -- Scroll speed multiplier
    self.rescaleMult = 1
    self.lineNumMargin = 0.25 -- Line Number margin to the left of the numbers and right of the numbers
    self.textOffset = 2 -- offset after the right line margin
    self.tokenizationLinesLimit = 20000 -- After this amount of lines, tokenization will stop.

    self.colors.editorBG = dark(45)
    self.colors.editorFG = dark(255)
    self.colors.lineNumbersBG = dark(35)
    self.colors.lineNumbersColor = Color(240,130,0)
    self.colors.lineNumbersOutline = dark(150)
    self.colors.caret = Color(25,175,25)
    self.colors.caretBlock = Color(25,150,25,50)
    self.colors.caretLine = Color(150,150,150,25)
    self.colors.tabIndicators = Color(175,175,175,35)
    self.colors.pairs = Color(0, 230, 230, 86)

    self.colors.highlights = Color(0,60,220,50)
    self.colors.selection = Color(185, 230, 45, 40)
    ---------------

    self.syntax = {}
    self.tokens = {}

    self.lexer = table.Copy(SSLE.modules.lexer)
    self:ResetProfile()

    self.caret = {
        ["char"]= 0,
        ["line"]= 1
    }

    self.selection = {
        ["start"] = {
            ["char"] = 0,
            ["line"] = 0
        },
        ["dest"] = {
            ["char"] = 0,
            ["line"] = 0
        }
    }

    self.textPos = {
        ["line"] = 1,
        ["char"] = 1
    }

    self.font = {
        ["w"]  = 0,
        ["h"]  = 0,
        ["n"]  = "",
        ["s"]  = 0,
        ["an"] = ""
    }

   -- self.altFonts = {}
    self.lines = {}
    self.undo = {}
    self.redo = {}
    self.highlights = {}

    -- Scrollbar
    self.scrollBar = vgui.Create("DVScrollBar", self)
    self.scrollBar:Dock(RIGHT)
    self.scrollBar.Dragging = false
    scrollbarOverride(self.scrollBar)

    -- TextEntry
    self.textBox = vgui.Create("TextEntry", self)
    self.textBox:SetSize(0,0)
    self.textBox:SetMultiline(true)
    local tbox                     = self.textBox 
    self.textBox.OnLoseFocus       = function(self)       tbox.Parent:_FocusLost()           end
    self.textBox.OnTextChanged     = function(self)       tbox.Parent:_TextChanged()         end
    self.textBox.OnKeyCodeTyped    = function(self, code) tbox.Parent:_KeyCodePressed(code)  end
    self.textBox.OnKeyCodeReleased = function(self, code) tbox.Parent:_KeyCodeReleased(code) end
	self.textBox.Parent            = self
                
    self.lastCaret = table_Copy(self.caret)
    self.lastTextPos = table_Copy(self.textPos)
    self.allTabs = {}
    self.lastOffset = 0
    self.caretTimer = 0
    self.mouseSelecting = false 
    self.arrowSelecting = false 
    self.pairMatches = nil 

    self.parseTimer = RealTime()

    self:FixCaret()
    self:ResetSelection()

    self:SetFont("Consolas", 16)

    self.lexProg = 0

    -- Derma Objects
    --[[ 
        This turned out to be shit

    self.fontSizeWang = vgui.Create("DNumberWang", self)
    self.fontSizeWang:SetMin(8)
    self.fontSizeWang:SetMax(48)
    self.fontSizeWang:SetDecimals(0)
    self.fontSizeWang:SetValue(self.font.s)
    self.fontSizeWang:SetSize(35,21)
    local this = self 
    self.fontSizeWang.OnValueChanged = function(self)
        this:SetFont(this.font.an, self:GetValue())
    end
    self.fontSizeWang:SetTextColor(Color(255,255,255,255))
    self.fontSizeWang.Paint = function(self, w, h)
        draw.SimpleText(self:GetValue().."", "DermaDefault", w / 4, h / 2, Color(255,255,255,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.RoundedBox(2, 0, 0, w * 2, h, Color(255,255,255,30))
    end

    self.fontSizeLabel = vgui.Create("DLabel", self)
    self.fontSizeLabel:SetText("Fontsize:")

    self.languageLabel = vgui.Create("DLabel", self)
    self.languageLabel:SetText("Language:")]]
end 

function syntaxBox:OnMouseClick(code) end 
function syntaxBox:OnTextChanged() end 
function syntaxBox:OnFocusLost() end 
function syntaxBox:OnKeyCodePressed(code) end 
function syntaxBox:OnKeyCodeReleased(code) end 
function syntaxBox:OnKeyCombo(code1, code2) end 
function syntaxBox:OnScrolled(delta) end 
function syntaxBox:OnUndo(t) end 
function syntaxBox:OnRedo(t) end 
function syntaxBox:OnTextWritten(text) end 
function syntaxBox:OnLinesChanged(start, ending) end

--[[
                                      ___  ______ _____ 
                                     / _ \ | ___ \_   _|
                                    / /_\ \| |_/ / | |  
                                    |  _  ||  __/  | |  
                                    | | | || |    _| |_ 
                                    \_| |_/\_|    \___/                                                          
]]

function syntaxBox:SetProfile(syntaxConfig)
    if not syntaxConfig then return end 
    self.lexer:SetConfig(syntaxConfig)
    if not self.lexer.config.language or string.gsub(self.lexer.config.language, "%s", "") == "" then 
        self:ResetProfile()
    end
end

function syntaxBox:ResetProfile()
    self:SetProfile({
        language     = "Plain",
        filetype     = ".txt",
        reserved     = {},
        unreserved   = {},
        closingPairs = {},
        intending    = {},
        Matches      = {},
        captures     = {},
        colors       = {}})
end

function syntaxBox:SetCaret(char, line)
    self.lastCaret = table_Copy(self.caret)
    if not line and type(char) == "table" then 
        self.caret = table_Copy(char)
      --  self:FixCaret()
        return 
    end
    line = line or self.caret.line 
    self.caret.char, self.caret.line = char, line 
  --  self:FixCaret()
end

function syntaxBox:FontChanged(font, size, fontdata) end

function syntaxBox:SetFont(font, size)
    if not self.fontweight then self.fontweight = 500 end
    if not font then return end 
    size = math.Clamp(size, 8, 48)
    local newFont = "SLF" .. font  .. size
    if not fontBank[newfont] then
        local fontData_default = {
            font      = font,
            size      = size,
            weight    = self.fontweight
        }
        surface.CreateFont(newFont, fontData_default)
        fontBank[newFont] = size 
    end
    surface.SetFont(newFont)
    local w, h  = surface.GetTextSize(" ")
    self.font = {["w"]=w,["h"]=h,["n"]=newFont,["s"]=size,["an"]=font}
    self:FontChanged(font, size, self.font)
end

function syntaxBox:SetWeight(weight)
    if not weight or weight == 0 then return end 
    self.fontweight = weight 
    for font, size in pairs(fontBank) do 
        local fontData_override = {
            font      = self.font.an,
            size      = size,
            weight    = weight
        }
        surface.CreateFont(font, fontData_override)
        fontBank[font] = fontData_override.size 
    end 
    surface.SetFont(self.font.n)
    local w, h  = surface.GetTextSize(" ")
    self.font.w = w 
    self.font.h = h 
end

function syntaxBox:SetText(text)
    self.lines = string.Split(text, "\n")
    self:FixCaret()
    self.lexer:SetLines(self.lines)

    self.caret = {["char"]=1,["line"]=-1}
    self.selection = {["start"]={["char"]=0,["line"]=0}, ["dest"]={["char"]=0,["line"]=0}}
    self.textPos = {["line"]=1,["char"]=1}

    self.lastCaret = table_Copy(self.caret)
    self.lastTextPos = table_Copy(self.textPos)

    self.lastLines = {}
    self.highlights = {}
    self.allTabs = {}
    self.lastOffset = 0
    self.caretTimer = 0
    self.mouseSelecting = false 
    self.arrowSelecting = false 
    self.pairMatches = nil 

    self:ResetHighlighting()
    self:ResetSelection()
    self.mouseSelecting = false 
    self.arrowSelecting = false 

    for i, line in pairs(self.lines) do 
        if not line then break end 
        if self:LexLine(i, false) == false then break end 
    end

    timer.Simple(0.001, function()
        self:UpdateTabIndicators()
        self:TrimRight()
    end)
end

function syntaxBox:GetSelectedText()
    return self:GetTextFrom(self.selection.start, self.selection.dest)
end

function syntaxBox:GetText()
    return table_concat(self.text.lines, "\n")
end

function syntaxBox:GetLine(i)
    if not i then return nil end 
    return self.lines[i] 
end

function syntaxBox:AddHighlight(startChar, startLine, endChar, endLine)
    local start = {["char"]=startChar, ["line"]=startLine}
    local dest  = {["char"]=endChar, ["line"]=endLine}
    table_insert(self.highlights, {["start"]=start, ["ending"]=dest})
end 

function syntaxBox:ResetHighlighting()
    self.highlights = {}
end

function syntaxBox:StartSelection(char, line)
    if not line and type(char) == "table" then 
        self.selection.start = table_Copy(char)
        return 
    end
    self.selection.start = {char = char, line = line}
end

function syntaxBox:EndSelection(char, line)
    if not line and type(char) == "table" then 
        self.selection.dest = table_Copy(char)
        return 
    end
    self.selection.dest = {char = char, line = line}
end

function syntaxBox:HasSelection()
    return self.selection.start.char ~= self.selection.dest.char or self.selection.start.line ~= self.selection.dest.line
end

function syntaxBox:ResetSelection()
    self.selection.start = table_Copy(self.caret)
    self.selection.dest  = table_Copy(self.caret)
end

function syntaxBox:OverrideSelection(text)
    self:FlipSelection()
    local save = table_Copy(self.selection.start)
    self:RemoveSelectedText()
    self:FixCaret()
    self:PasteTextAt(text, save.char, save.line )
end

function syntaxBox:RemoveSelectedText(ressr)
    self:RemoveTextFromTo(self.selection.start, self.selection.dest)   
    if not ressr then 
        self:ResetSelection()
        self.arrowSelecting = false 
        self.mouseSelecting = false 
        self.hasChanges = true 
    end
end

function syntaxBox:FixCaret()
    self.lastCaret = table_Copy(self.caret)
    local line = math.Clamp(self.caret.line, 1, #self.lines)
    local char = math.Clamp(self.caret.char, 0, #(self.lines[self.caret.line] or ""))
    self.caret = {char = char, line = line}
    self:RetimeRematch()
end

function syntaxBox:FixPoint(char, line)
    local y = math.Clamp(line, 1, #self.lines)
    local x = math.Clamp(char, 0, #self.lines[y]) 
    return x, y
end

function syntaxBox:RematchPairs()
    local pairs = self:GetSurroundingPairs(self.caret.char, self.caret.line)
    if pairs and not self.lexerDiffCheck then 
        self.pairMatches = pairs 
    else 
        self.pairMatches = nil 
    end
end

function syntaxBox:ReTimeCaret()
    self.caretTimer  = RealTime() + 0.5
    self.caretToggle = true 
end

function syntaxBox:PosInText(x, y)
    x = x - self.lastOffset - self.font.w / 2 
    y = math.Round(mSub(y, self.font.h) / self.font.h + self.textPos.line)
    x = math.Round(mSub(x, self.font.w) / self.font.w + self.textPos.char)
    return x, y
end

function syntaxBox:PosOnPanel(char, line)
    local x, y = self.lastOffset, 0
  --  local tk = self:GetTokenAtPoint(char, line)
    local w =  self.font.w--(not tk and self.font.w or self:FontData(tk).w)
    x = x + char * w
    x = math.max(x - (self.textPos.char - 1) * w, self.lastOffset)
    y = line * self.font.h 
    return x, y
end

function syntaxBox:CaretFromLocal(x, y)
    local px, py = self:PosInText(x, y)
    self:SetCaret(px, py)
    self:FixCaret()
    self:ReTimeCaret()
end

function syntaxBox:RunLexer() -- Buggy piece of shit
    if self.runLexCoroutine and coroutine_status(self.runLexCoroutine) ~= "running" then 
        self.runLexCoroutine = nil 
    elseif self.runLexCoroutine and coroutine_status(self.runLexCoroutine) == "running" then 
        coroutine_yield(self.runLexCoroutine) 
        self.runLexCoroutine = nil 
    end
    self.lexAll = true 
end

function syntaxBox:ParseVisibleLines()
    if not self.lastLines then self.lastLines = {} end 
    for i = self.textPos.line, self.textPos.line + math.ceil(self:GetTall() / self.font.h) - 1, 1 do 
        self:LexLine(i, true)
    end
end

function syntaxBox:ParseChangedVisibleLines()
    if not self.lastLines then self.lastLines = {} end 
    for i = self.textPos.line, self.textPos.line + math.ceil(self:GetTall() / self.font.h) - 1, 1 do 
        self:LexLine(i) 
    end  
end

function syntaxBox:LexLine(i, lexSameLines)
    if i > self.tokenizationLinesLimit then return false end 
    local line = self.lines[i]
    if not line then return false end
    if lexSameLines == nil then lexSameLines = false end 
    if line == self.lastLines[i] and lexSameLines == false then return false end 
    self.tokens[i] = self.lexer:ParseLine(i, self.tokens[i - 1] or nil)
    self.lastLines[i] = line   
    return true 
end

function syntaxBox:Goto(char, line)
    local reps = 0

    ::rep::

    do -- Line Difference 
        local bot = self.textPos.line + 2
        local top = bot + math.ceil(self:GetTall() / self.font.h) - 5
        local diff = 0
        if line < bot then
            diff = line - bot   
        elseif line > top then
            diff = line - top 
        end

        local mabs = math.abs(diff)
        if diff ~= 0 then  -- was mabs
         --   if mabs > 1 then 
         --       self.scrollBar:AnimateTo(self.scrollBar:GetScroll() + diff, 0.25)
         --   else    
                self.scrollBar:SetScroll(self.scrollBar:GetScroll() + diff)
         --   end
            self:UpdateTabIndicators()
        end
    end

    do -- Char Difference
        local bot = self.textPos.char - 1
        local top = self.textPos.char + math.ceil((self:GetWide() - self.scrollBar:GetWide() - self.lastOffset - self.font.w) / self.font.w) - 4
        local diff = 0
        if char < bot then
            diff = char - bot         
        elseif char > top then 
            diff = char - top 
        end

        if math.abs(diff) > 0 then 
            self.textPos.char = self.textPos.char + diff
        end 
    end

    -- Bruvh
    if reps == 0 then 
        reps = reps + 1
        goto rep 
    end

    self:ParseVisibleLines()
end

function syntaxBox:Highlight(start, ending, i, col)
    if not start or not ending or not i then return end 
    col = col or self.colors.highlights

    surface.SetDrawColor(col)

    local limit = self.font.w / 2
    local c = i - self.textPos.line  
    local line = self.lines[i]

    if start.line == ending.line and i == start.line then -- If selection is in the same Line 
        local sx,sy = self:PosOnPanel(start.char, c)
        local ex,ey = self:PosOnPanel(ending.char, c)
        if ending.char > start.char then 
            surface.DrawRect(sx, sy, ex - sx, self.font.h)
        else
            surface.DrawRect(ex, ey, sx - ex, self.font.h)
        end
    elseif i == ending.line then -- if multiline, end of line selection
        if ending.line > start.line then 
            local ex,ey = self:PosOnPanel(ending.char, c)
            local sx,sy = self:PosOnPanel(0, c)
            surface.DrawRect(sx, sy, ex - sx, self.font.h)
        else
            local sx,sy = self:PosOnPanel(ending.char, c)
            local ex,ey = self:PosOnPanel(#line, c)     
            surface.DrawRect(sx, sy, ex - sx, self.font.h)               
        end
    elseif i == start.line then -- if multiline, start of line selection
        if ending.line > start.line then 
            local sx,sy = self:PosOnPanel(start.char, c)
            local ex,ey = self:PosOnPanel(#line, c)
            surface.DrawRect(sx, sy, math.max(ex - sx, limit), self.font.h)
        else
            local ex,ey = self:PosOnPanel(start.char, c)
            local sx,sy = self:PosOnPanel(0, c)
            surface.DrawRect(sx, sy, math.max(ex - sx, limit), self.font.h)
        end
    elseif ((i >= start.line and i <= ending.line) or (i <= start.line and i >= ending.line)) then -- All Lines inbetween Start and End of Selection  
        local sx,sy = self:PosOnPanel(0, c)
        local ex,ey = self:PosOnPanel(#line, c)
        surface.DrawRect(sx, sy, math.max(ex - sx, limit), self.font.h)
    end
end

function syntaxBox:RetimeDiffCheck()     self.lexerDiffCheck = RealTime()    + 0.33 end
function syntaxBox:RetimeRematch()       self.pairMatchTimer = RealTime()    + 0.25 end

function syntaxBox:LineHasTokenTexts(i, texts)
    if not i or not type then return false end 
    if not self.tokens[i] then return false end 
    for _, t in pairs(self.tokens[i]) do 
        if table.HasValue(texts, t.text) then return true end 
    end
    return false 
end

 --[[                              
                                 _   _             _        
                                | | | |           | |       
                                | |_| | ___   ___ | | _____ 
                                |  _  |/ _ \ / _ \| |/ / __|
                                | | | | (_) | (_) |   <\__ \
                                \_| |_/\___/ \___/|_|\_\___/
                                ]]

function syntaxBox:_TextChanged()
    self:SaveState()

    local text = self.textBox:GetText()

    if text == "\n" or not text or text == "" or #text == 0 then 
        self.textBox:SetText("")
        return 
    end 

    self:FixCaret()

    if #text > 1 then 
        if self.pasteCooldown and self.pasteCooldown >= RealTime() then else  
            local cSave = table_Copy(self.caret)

            if self:HasSelection() == true then 
                self:FlipSelection()
                self:RemoveSelectedText()
                self:ParseVisibleLines()
                self:FixCaret()
                self:PasteTextAt(text, self.caret.char, self.caret.line )
            else     
                self:PasteTextAt(text, self.caret.char, self.caret.line)
            end 

            if #string.Split(text, "\n") == 1 then 
                local line = self.lines[self.caret.line]
                self:IntendLine(self.caret.line)
                self:SetCaret((#self.lines[self.caret.line] - #line) + self.caret.char)
            end

            self.pasteCooldown = RealTime() + 0.066
        end 

        self:OnTextWritten(text)
    else
        if self:HasSelection() then
            self:RemoveSelectedText()
        end

        local function add(t)
            local line = self:GetLine(self.caret.line)
            self.lines[self.caret.line] = string_sub(line, 1, self.caret.char) .. t .. string_sub(line, self.caret.char + 1, #line) 
            self:SetCaret(self.caret.char + #t)  
        end

        local save = text 

        add(text)

        local line = self:GetLine(self.caret.line)
        for _, v in pairs(self.lexer.config.autoPairing or {}) do 
            local sub = string_sub(line, self.caret.char - #v.word + 1, self.caret.char - 1) .. text 

            if sub == v.word  and v.validation(line, self.caret.char or 0, self.caret.line or 1) == true then 
                add(v.pair)
                save = save .. v.pair 
                self:SetCaret(self.caret.char - #v.pair)
                break 
            end
        end

        self:OnTextWritten(save)
    end

    self:CompState() 

    self:ResetSelection()
    self.arrowSelecting = false 
    self.mouseSelecting = false 

    self.textBox:SetText("")
    self:FixCaret()
    self:Goto(self.caret.char, self.caret.line)
    self.hasChanges = true 

    PrintTable(self.tokens[self.caret.line])
end

function syntaxBox:FlipSelection()
    if self.selection.start.line > self.selection.dest.line or (self.selection.start.line == self.selection.dest.line and self.selection.start.char > self.selection.dest.char) then 
        self.selection.start, self.selection.dest = swap(self.selection.start, self.selection.dest)
    end 
end

function syntaxBox:IndentCaret()
    local len = self:IntendLine(self.caret.line) 

    if #len == 0 then 
        self:IntendLine(self.caret.line)
    end

    self:SetCaret(self.caret.char + #len)

    return #len 
end

function syntaxBox:DoCopy()
    SetClipboardText(self:GetSelectedText())
    self:ResetHighlighting()
end

function syntaxBox:DoUndo()
    self:Undo()
    self:ResetHighlighting()
    self.hasChanges = true 
end

function syntaxBox:DoRedo()
    self:Redo()
    self:ResetHighlighting()
    self.hasChanges = true 
end

function syntaxBox:DoCut()
    if self:HasSelection() == true then 
        self:SaveState()
        self:RemoveSelectedText()
        self.hasChanges = true 
        self:CompState()
        self:ResetHighlighting()
        checkSelection()
    end 
end

function syntaxBox:DoSelectAll()
    self:ResetSelection()
    self:StartSelection(0,1)
    local lastLine = self.lines[#self.lines]
    self:EndSelection(#lastLine, #self.lines)
    self:SetCaret(self.selection.dest.char, self.selection.dest.line)
    self:ResetHighlighting()
end

function syntaxBox:DoSelectCaretUp()
    self:ResetSelection()
    self.arrowSelecting = false 
    self.mouseSelecting = false 
    self:ResetHighlighting()
    self:SetCaret(self.caret.char, self.caret.line - 4)
    self:FixCaret()
    self:Goto(self.caret.char, self.caret.line)
end

function syntaxBox:DoSelectCaretDown()
    self:ResetSelection()
    self.arrowSelecting = false 
    self.mouseSelecting = false 
    self:ResetHighlighting()
    self:SetCaret(self.caret.char, self.caret.line + 4)
    self:FixCaret()
    self:Goto(self.caret.char, self.caret.line)
end

function syntaxBox:DoSelectCaretRight()
    self:ResetSelection()
    self.arrowSelecting = false 
    self.mouseSelecting = false 
    self:ResetHighlighting()
    self:SetCaret(self.caret.char + 4)
    self:FixCaret()
    self:Goto(self.caret.char, self.caret.line)
end

function syntaxBox:DoCaretLeft()
    self:ResetSelection()
    self.arrowSelecting = false 
    self.mouseSelecting = false 
    self:ResetHighlighting()
    self:SetCaret(self.caret.char - 4)
    self:FixCaret()
    self:Goto(self.caret.char, self.caret.line)
end

function syntaxBox:DoTab()
    self:SaveState()

    self:FlipSelection()

    local selLines = self:GetLines(self.selection.start.line, self.selection.dest.line)
    local newLines = {}

    for k, line in pairs(selLines) do 
        local _, _, tabs = string_find(line, "^(%s*)")

        if #tabs < self.tabSize then 
            newLines[k] = line 
            continue 
        end

        newLines[k] = string_sub(line, math.Clamp(self.tabSize, 1, #line) + 1, #line) or line  
    end

    self:OverrideLines(self.selection.start.line, self.selection.dest.line, newLines)
    self:StartSelection(0, self.selection.start.line)
    self:EndSelection(#(self.lines[self.selection.dest.line] or ""), self.selection.dest.line)

    self:SetCaret(self.selection.dest)
    self:FixCaret()

    self.hasChanges = true 
    self:CompState()
end

function syntaxBox:_KeyCodePressed(code)
    self:OnKeyCodePressed(code)

    if code == KEY_TAB then self.tabfocus = true end 

    local function intendCaret()
        return self:IndentCaret()
    end

    local function tabs()
        return string.rep(" ", self.tabSize, "")
    end

    local function checkOutside()
        self:FixCaret()
        self:Goto(self.caret.char, self.caret.line)
    end 

    local function checkSelection()
        if self.arrowSelecting then 
            self:EndSelection(self.caret.char, self.caret.line)
        elseif self:HasSelection() then  
            self:ResetSelection()
            self.mouseSelecting = false
            self.arrowSelecting = false        
        end
    end
--https://wiki.facepunch.com/gmod/Enums/KEY
    local shift   = input.IsKeyDown(KEY_LSHIFT)   or input.IsKeyDown(KEY_RSHIFT)
	local control = input.IsKeyDown(KEY_LCONTROL) or input.IsKeyDown(KEY_RCONTROL)

    if shift then 
        if self.arrowSelecting == false then 
            if self.mouseSelecting == false then 
                self:ResetSelection()
            end 

            self.arrowSelecting = true 
        end 

        self:ResetHighlighting()
    elseif control then 
        if code == KEY_C then
            self:DoCopy()
        elseif code == KEY_Z then 
            self:DoUndo()
        elseif code == KEY_Y then 
            self:DoRedo()
        elseif code == KEY_A then 
            self:DoSelectAll()
        elseif code == KEY_X then 
            self:DoCut()
        elseif code == KEY_TAB then 
            if self:HasSelection() then 
                self:DoTab()
            end 
        elseif code == KEY_UP then 
            self:DoSelectCaretUp()
        elseif code == KEY_DOWN then 
            self:DoSelectCaretDown()
        elseif code == KEY_RIGHT then 
            self:DoSelectCaretRight()
        elseif code == KEY_LEFT then 
            self:DoSelectCaretLeft()
        end

        if code then 
            self:OnKeyCombo(control, code)
            self:ReTimeCaret()
            return 
        end 
    end

    if code == KEY_DOWN then
        self:SetCaret(self.caret.char, self.caret.line + 1)

        -- Auto Indenting
        local cL = self.lines[self.caret.line]
        local left = getLeft(cL)
        if whitespace(cL) == true then 
            intendCaret()
        elseif (self.caret.char <= #left and self.caret.char > #left - self.tabSize) 
        or ((self.caret.char % self.tabSize) == 0 and self.caret.char == #left - self.tabSize) then 
            self:SetCaret(#left)
        end

        checkOutside()
        checkSelection()
        self:ResetHighlighting()
        self:RetimeRematch()
    elseif code == KEY_UP then
        self:ResetHighlighting()
        self:SetCaret(self.caret.char, self.caret.line - 1)

        -- Auto Indenting
        local cL = self.lines[self.caret.line]
        local left = getLeft(cL)
        if whitespace(cL) == true then 
            intendCaret()
        elseif (self.caret.char <= #left and self.caret.char > #left - self.tabSize) 
         or ((self.caret.char % self.tabSize) == 0 and self.caret.char == #left - self.tabSize) then 
            self:SetCaret(#left)
        end

        checkOutside()
        checkSelection()

        self:ResetHighlighting()
        self:RetimeRematch()
    elseif code == KEY_RIGHT then
        local line = self.lines[self.caret.line]

        self:SetCaret(self.caret.char + 1)

        if self.caret.char > #self.lines[self.caret.line] then
            self:SetCaret(0, self.caret.line + 1)
        end

        checkOutside()
        checkSelection()

        self:ResetHighlighting()
        self:RetimeRematch()
    elseif code == KEY_LEFT then
        local line = self.lines[self.caret.line]

        self:SetCaret(self.caret.char - 1)

        if self.caret.char < 0 then
            self:SetCaret(self.caret.char, self.caret.line - 1)
            local line = self.lines[self.caret.line]
            if line then
                self:SetCaret(#line)
            end
        end

        checkOutside()
        checkSelection()

        self:ResetHighlighting()
        self:RetimeRematch()
    elseif code == KEY_BACKSPACE then 
        self:SaveState()
        if self:HasSelection() == true then 
            self:FlipSelection()
            self:RemoveSelectedText()
            self:ResetSelection()
            self.arrowSelecting = false 
            self.mouseSelecting = false 
        else 
            local line = self.lines[self.caret.line]
            local l = string_sub(line, 1, self.caret.char)
            local r = string_sub(line, self.caret.char + 1, #line)
         
            -- Intend tab spaces 
            if string_sub(l, #l - self.tabSize + 1, #l) == tabs() then 
                self.lines[self.caret.line] = string_sub(line, 1, self.caret.char - self.tabSize) .. string_sub(line, self.caret.char + 1, #line)
                self:SetCaret(self.caret.char - self.tabSize)
            else 
                local function rem(i, len)
                    local li = self.lines[self.caret.line]
                    self.lines[self.caret.line] = string_sub(li, 1, i) .. string_sub(li, i + len + 1, #line)
                end

                local char = line[self.caret.char] or "" 

                for _, v in pairs(self.lexer.config.autoPairing or {}) do 
                    if char == v.word[#v.word] and v.validation(line, self.caret.char or 0, self.caret.line or 1) == true then 
                        if string_sub(line, self.caret.char + 1, self.caret.char + #v.pair) == v.pair then 
                            rem(self.caret.char, #v.pair)
                            break 
                        end 
                    end
                end

                self:SetCaret(self.caret.char - 1)
                rem(self.caret.char, 1)
            end 

            if self.caret.char < 0 and self.caret.line > 1 then 
                table_remove(self.lines, self.caret.line)
                local r = string_sub(line, self.caret.char + 1, #line)
                self:SetCaret(self.caret.char, self.caret.line - 1)
                local save = self.lines[self.caret.line]
                self.lines[self.caret.line] = self.lines[self.caret.line] .. r 
                self:SetCaret(#save)
            elseif self.caret.line == 1 and self.caret.char < 0 then 
                self.lines[self.caret.line] = line
            end
        end 
        
        self:CompState()
        self.hasChanges = true 
        checkOutside() 
    elseif code == KEY_ENTER then 
        self:SaveState()

        if self:HasSelection() then 
            self:RemoveSelectedText()
        else        
            local line = self.lines[self.caret.line]

            if not line then self:FixCaret() end 

            local l = string_sub(line, 1, self.caret.char)
            local r = string_sub(line, self.caret.char + 1, #line)

            local Len = getLeft(line)

            self.lines[self.caret.line] = Len .. string.gsub(l, "^(%s*)", "") 
 
            self:LexLine(self.caret.line)

            table_insert(self.lines, self.caret.line + 1, string.TrimLeft(r, " "))

            self:SetCaret(0, self.caret.line + 1)

            local tks = self.tokens[self.caret.line - 1]
            if self:LineInsideCapture(self.caret.line - 1) == false or tks[#tks].type == "newline" then 
                local len = self:IntendLine(self.caret.line)
                if #len == 0 then 
                    self.lines[self.caret.line] = Len .. string.gsub(self.lines[self.caret.line], "^(%s*)", "") 
                    self:SetCaret(#Len)
                else 
                    self:SetCaret(#len)
                end
            end 

            self:LexLine(self.caret.line)

            self.lines[self.caret.line - 1] = string.TrimLeft(self.lines[self.caret.line - 1] or "", " ")
            self:IntendLine(self.caret.line - 1)
            self:LexLine(self.caret.line - 1)
        end

        self:CompState()
        self.hasChanges = true 
        checkOutside()    
    elseif code == KEY_TAB then 
        self:SaveState()
        if self:HasSelection() == false then 
            local line = self.lines[self.caret.line]

            local l = string_sub(line, 1, self.caret.char)
            local r = string_sub(line, self.caret.char + 1, #line)

            local retabbed = false 
            ::ReTab::
            if #l == 0 and retabbed == false then 
                local len = intendCaret()
                if len == 0 then 
                    retabbed = true 
                    goto ReTab 
                end

                self.lines[self.caret.line] = string.rep(" ", len) .. r
                self:SetCaret(len)
            else 
                self.lines[self.caret.line] = l .. tabs() .. r
                self:SetCaret(self.caret.char + self.tabSize)
            end 
        else 
            if math.abs(self.selection.start.line - self.selection.dest.line) > 1 then 
                self:FlipSelection()
                local selLines = self:GetLines(self.selection.start.line, self.selection.dest.line)
                local newLines = {}
                for k, v in pairs(selLines) do 
                    newLines[k] = tabs() .. v 
                end

                self:OverrideLines(self.selection.start.line, self.selection.dest.line, newLines)
                self:StartSelection(0, self.selection.start.line)
                self:EndSelection(#(self.lines[self.selection.dest.line] or ""), self.selection.dest.line)

                self:SetCaret(self.selection.dest)
            else 
                self:OverrideSelection(tabs())
                intendCaret()
            end
        end

        self:CompState()
        checkOutside()

        self.hasChanges = true 
    end

    self.codePressed = code 
    self:ReTimeCaret()
end

function syntaxBox:_KeyCodeReleased(code)
    self.codePressed = nil 

    self:OnKeyCodeReleased(code)

    if code == KEY_LSHIFT or code == KEY_RSHIFT then 
        self.arrowSelecting = false 
    elseif code == KEY_LCONTROL or code == KEY_RCONTROL then 
        
    end
end

function syntaxBox:OnMousePressed(code)
    self:OnMouseClick(code)
    local mx, my = self:LocalCursorPos()
    self:CaretFromLocal(mx, my)

    self.clickCounter = (self.clickCounter or 0) + 1
    if self.clickCounter > 2 then self.clickCounter = 0 end 

    if code == MOUSE_RIGHT then
    elseif code == MOUSE_LEFT then 
        self:RematchPairs()
    end

    if self:HasSelection() then 
        self:ResetSelection()
        self.mouseSelecting = false
        self.arrowSelecting = false 
    end 

    local function resDef()
        if  self:HasSelection() == false then 
            self:ResetHighlighting()
            local word = self:GetWordAtPoint(self.caret.char, self.caret.line)
            if word then 
                self:HighlightWords(word)
            end 
        end  
        self.clickCounter = 0
    end

    if self.lastClickPos and self.caret.char == self.lastClickPos.char and self.caret.line == self.lastClickPos.line then 
        self:ResetHighlighting()
        if self.clickCounter == 1 then 
            self:ResetHighlighting()
            local word, start = self:GetWordAtPoint(self.caret.char, self.caret.line)
            if word and start then 
                self:StartSelection(start - 1, self.caret.line)
                self:EndSelection(start + #word - 1, self.caret.line)
            end
        elseif self.clickCounter == 2 then 
            local line = self.lines[self.caret.line]
            self:StartSelection(0, self.caret.line)
            self:EndSelection(#line, self.caret.line)
        else 
            resDef()
        end
    else 
        resDef()
    end

    self.lastClickPos = table.Copy(self.caret)
    self:Goto(self.caret.char, self.caret.line)

    self.textBox:RequestFocus()
end

function syntaxBox:_FocusLost()
    if self.tabfocus then 
        self.textBox:RequestFocus()
        self.tabfocus = false 
    else     
        self:OnFocusLost()
    end 
end

function syntaxBox:CheckAreaSelection(w, h, vLines, vChars)
    if self:IsHovered() and self.scrollBar.Dragging == false and self.arrowSelecting == false then 
        if input.IsMouseDown(MOUSE_LEFT) then
            local mx, my = self:LocalCursorPos()  
            local px, py = self:PosInText(mx, my)
            local px, _ = self:FixPoint(px, py)

            if self.mouseSelecting == false then 
                if (px ~= self.caret.char or py ~= self.caret.line) and self.lines[py] then 
                    self:ResetSelection()
                    self:StartSelection(self.caret)
                    self.mouseSelecting = true 
                elseif self.lines[py] == nil then
                    self:ResetSelection()
                    self.caret.char = #self.lines[#self.lines]
                end
            else 
                if self.lines[py] then 
                    self:ReTimeCaret()
                    self:EndSelection(px, py)
                    self:SetCaret(px, py)
                    self:FixCaret()

                    if my < (self.font.h * 4) then 
                        local minus = 1 - math.Clamp((1 / (self.font.h * 4)) * my,0.1,1)
                        local scroll = math.max(self.scrollBar:GetScroll() - minus * 4, 0)
                        self.textPos.line = math.ceil(scroll + 1)
                        self.scrollBar:SetScroll(scroll)
                    elseif my > (h - self.font.h * 4) then  
                        my = h - my 
                        local minus = 1 - math.Clamp((1 / (self.font.h * 4)) * my,0.1,1)
                        local scroll = self.scrollBar:GetScroll() + minus * 4
                        self.textPos.line = math.min(math.ceil(scroll + 1), #self.lines - vLines + 2)
                        self.scrollBar:SetScroll(scroll)
                    end 
                end
            end 
        end
    end
end

function syntaxBox:CountVisibleLines()
    return math.ceil(self:GetTall() / self.font.h) - 1
end

function syntaxBox:CountVisibleChars()
    return math.ceil(self:GetWide() / self.font.w)
end

function syntaxBox:Think()
    local w, h = self:GetSize()
    local vLines = math.ceil(h / self.font.h) - 1
    local vChars = math.ceil(w / self.font.w)

    self.scrollBar:SetUp(vLines, #self.lines + 1)

    -- Scrollbar out of bounds check
    do 
		local scroll = self.scrollBar:GetScroll()
		self.textPos.line = math.ceil(scroll + 1)
        self.scrollBar:SetScroll(scroll)
        if self.lastTextPos.line ~= self.textPos.line then 
            if self:HasSelection() then 
                self:HighlightWords(self:GetSelectedText())
            end 
            self:UpdateTabIndicators()
            self:RematchPairs()
            self:ParseVisibleLines()
            self.caretTimer  = RealTime() + 0.5
        end
    end
    
    if self.parseTimer <= RealTime() then
        self:ParseVisibleLines()
        self.parseTimer = RealTime() + 0.025
    end

    -- Caret Blink
    if RealTime() > self.caretTimer then
        self.caretTimer  = RealTime() + 0.5
        self.caretToggle = not self.caretToggle 
    end

    -- Pair matching trigger
    if self.caret.char ~= self.lastCaret.char or self.caret.line ~= self.lastCaret.line then 
        if (self.lastTextPos.char ~= self.textPos.char) and self.hasChanges == false then 
            if self.lexerDiffCheck then 
                self:RetimeDiffCheck()
            end 
        end

     --   self:RematchPairs()
     --   self.lastCaret = table_Copy(self.caret)
    end 

    if self.pairMatchTimer and RealTime() > self.pairMatchTimer then 
        self:RematchPairs()
        self.pairMatchTimer = nil 
    end
    
    -- Area Selection
    self:CheckAreaSelection(w, h, vLines, vChars)

    self.lastTextPos = table_Copy(self.textPos) 
 --   self.lastCaret   = table_Copy(self.caret)

    if self.lexAll and not self.runLexCoroutine then 
        local lineCounter = 0
        self.lexProg      = 0

        local diff = compareLines(self.lastLines or {}, self.lines)

        self.lexer:SetLines(self.lines)

        if diff[1] ~= 0 and diff[2] ~= 0 then 
            local ml = math.ceil(self:GetTall() / self.font.h)

            self.runLexCoroutine = coroutine_create(function()
                for i = diff[1], diff[2], 1 do 
                    self:LexLine(i, false)
                    self:TrimRightLine(i)

                    lineCounter = lineCounter + 1
                    
                    self.lexProg = lineCounter

                    if lineCounter > 75 then 
                        lineCounter = 0
                        coroutine_wait(0.05)
                    end
                end

                self.hasChanges = false 
                self.lexAll     = nil 

                if coroutine_status(self.runLexCoroutine) == "running" then 
                    coroutine_yield(self.runLexCoroutine) 
                end
            end)
        end 
    elseif self.runLexCoroutine then 
        coroutine_resume(self.runLexCoroutine)
    end
end

function syntaxBox:PaintCaret(i)
    local line = self.lines[i] 

    if not line then return end 

    local offset = self.lastOffset or 0 
    local w = self:GetWide() or 0 
    local c = i - self.textPos.line  
    local lpos = c * self.font.h

    if i == self.caret.line and self.caret.line ~= -1 then
        local caretX = offset + ((self.caret.char - self.textPos.char + 1) * self.font.w)

        draw.RoundedBox(0, offset, lpos, w - offset, self.font.h, self.colors.caretLine)

        if self.caretToggle then 
            draw.RoundedBox(0, caretX, lpos, 2, self.font.h, self.colors.caret)
        end
        
        if self.caret.char < #line then 
            -- Caret Block 
            draw.RoundedBox(0, caretX, lpos, self.font.w, self.font.h, self.colors.caretBlock)
        end 
    else
        -- Trim right whitespaces
        self:TrimRightLine(i)
    end
end

function syntaxBox:PaintBackground()
    local w, h = self:GetSize()
    local vLines = math.ceil(h / self.font.h) - 1
    local lnm = self.lineNumMargin * self.font.w * 1.5
    local offset = self.lastOffset
    local lineNumWidth = #tostring(self.textPos.line + vLines - 1) * self.font.w

    -- Background
    draw.RoundedBox(0,lineNumWidth + lnm + self.font.w,0,w,h, self.colors.editorBG)

    -- Line Numbers Background
    draw.RoundedBox(0,0,0,lineNumWidth + lnm + self.font.w,h, self.colors.lineNumbersBG) 

    -- Editor & Line Numbers Seperator
 --   surface.SetDrawColor(self.colors.lineNumbersOutline)
 --   surface.DrawLine(lineNumWidth + self.font.w, 0, lineNumWidth + self.font.w, h) 
    surface.SetDrawColor(self.colors.lineNumbersOutline)
    surface.DrawLine(lineNumWidth + lnm + self.font.w, 0, lineNumWidth + lnm + self.font.w, h) 
end

function syntaxBox:Paint(w, h)
    if self:IsVisible() == false then return end 

    local vLines = math.ceil(h / self.font.h) - 1
    local vChars = math.ceil(w / self.font.w)

    local lineNumTxtW = #tostring(self.textPos.line + vLines - 1)
    local lineNumWidth = lineNumTxtW * self.font.w

    local lnm = self.lineNumMargin * self.font.w * 1.5

    local offset = (lineNumWidth + (lnm) + self.font.w + self.textOffset) 

    self:PaintBackground()

   -- lnm = lnm + self.font.w 

    local errorIndicators = {}
    local rightTrimmed = false 
    local c = 0
    for i = self.textPos.line, self.textPos.line + vLines, 1 do 
        local line = self.lines[i]
        if not line then break end 

        local lpos = c * self.font.h

        -- Line Numbers
        do 
            local tO =  (lineNumTxtW - #tostring(i))
            draw.SimpleText(i, self.font.n, 2.5 + lineNumWidth * (tO / lineNumTxtW) , c * self.font.h, self.colors.lineNumbersColor) 
        end

        -- Caret 
        self:PaintCaret(i)
        
        -- Syntax Coloring 
        if self.tokens[i] and self.lines[i] and self.lexer.config.language ~= "Plain" then 
            local hasError = false 
            local lastY = 0
            for tokenIndex, token in pairs(self.tokens[i] or {}) do 
                if token.type == "endoftext" then break end 

                local txt = token.text

                if token.ending < self.textPos.char or token.start > self.textPos.char + vChars then 
                    continue
                elseif token.start < self.textPos.char and token.ending >= self.textPos.char then  
                    txt = string_sub(txt, self.textPos.char - token.start + 1, #txt)
                end
    
                if token.type == "newline" then 
                    draw.SimpleText("⮯", self.font.n, offset + lastY, c * self.font.h, self.colors.tabIndicators)
                    break        
                elseif token.type == "error" then 
                    hasError = true 
                end

                local textY, _ = draw.SimpleText(txt, self.font.n, offset + lastY, c * self.font.h, (not token.color and self.lexer.config.colors[token.type] or self.lexer.config.colors[token.color]) or Color(255,255,255))
    
                lastY = lastY + textY
            end
    
            if hasError == true and not errorIndicators[i] then -- Error indicator
                draw.RoundedBox(0, lineNumWidth + self.font.w - 1, lpos, lnm - 1, self.font.h, self.lexer.config.colors.error or Color(255,0,0))
                errorIndicators[i] = 1      
            end
        elseif (not self.tokens[i] and self.lines[i]) or self.lexer.config.language == "Plain" then 
            local txt = string_sub(line, self.textPos.char, self.textPos.char + vChars) 
            draw.SimpleText(txt, self.font.n, offset , c * self.font.h, self.colors.editorFG)
        end

        -- Pair highlighting
        if self.pairMatches and not self.pairMatchTimer and self.lexer.config.language ~= "Plain" then 
            local open  = self.pairMatches.start  
            local close = self.pairMatches.ending  
            local pcol  = self.colors.pairs 
            local hasError = false 
            if not open or not close then 
                pcol = self.lexer.config.colors.error or Color(255,100,100,50)
                hasError = true 
            end

            if open and i == open.line and open.char >= self.textPos.char then 
                draw.RoundedBox(0, offset + (open.char - self.textPos.char) * self.font.w, lpos, self.font.w, self.font.h, pcol)
                if hasError and not errorIndicators[i] then 
                    draw.RoundedBox(0, lineNumWidth + self.font.w - 1, lpos, lnm - 1, self.font.h, self.lexer.config.colors.error or Color(255,0,0))
                    errorIndicators[i] = 1    
                end
            end 

            if close and i == close.line and close.char >= self.textPos.char then 
                draw.RoundedBox(0, offset + (close.char - self.textPos.char) * self.font.w, lpos, self.font.w, self.font.h, pcol)
                if hasError and not errorIndicators[i] then 
                    draw.RoundedBox(0, lineNumWidth + self.font.w - 1, lpos, lnm - 1, self.font.h, self.lexer.config.colors.error or Color(255,0,0))
                    errorIndicators[i] = 1    
                end
            end 

            if open and close then 
                local picol = table_Copy(pcol)  
                picol.a = 255
                if math.abs(open.line - close.line) > 1 and not errorIndicators[i] then 
                    if ((i >= open.line and i <= close.line) or (i <= open.line and i >= close.line)) then 
                        draw.RoundedBox(0, lineNumWidth + self.font.w - 1, lpos, lnm - 1, self.font.h, picol)
                    end
                elseif math.abs(open.char - close.char) > 1 and i == open.line then  
                    surface.SetDrawColor(picol)
                    local max = offset + w 
                    local z = lpos + self.font.h
                    local startChar = math.Clamp((open.char - self.textPos.char + 1) * self.font.w + offset, offset, max)
                    local endChar   = math.Clamp((close.char - self.textPos.char) * self.font.w + offset, offset, max)
                    surface.DrawLine(startChar, z, endChar, z)
                end
            end
        end 

        -- Tab Indicators
        if self.lexer.config.language ~= "Plain" then 
            for tabC, tab in pairs(self.allTabs) do     
                if c == tabC then 
                    for t = 2, #tab, 1 do 
                        if ((t - 1) % self.tabSize) == 0 and t >= self.textPos.char then 
                            local pos = t * self.font.w - self.textPos.char * self.font.w
                            draw.RoundedBox(0, offset + pos, tabC * self.font.h, 1.25, self.font.h, self.colors.tabIndicators)
                        end
                    end 
                end 
            end
        end 

        if self:HasSelection() then
             self:Highlight(self.selection.start, self.selection.dest, i, self.colors.selection) 
             if #self.highlights > 0 then 
                for _, highlight in pairs(self.highlights) do 
                    if ((self.selection.start.char == highlight.start.char or self.selection.dest.char == highlight.ending.char) 
                    or (self.selection.dest.char == highlight.start.char or self.selection.start.char == highlight.ending.char))
                    and highlight.start.line ~= i then 
                        continue 
                    end 
                    self:Highlight(highlight.start, highlight.ending, i)
                end
            end 
        else 
            if #self.highlights > 0 then 
                for _, highlight in pairs(self.highlights) do 
                    self:Highlight(highlight.start, highlight.ending, i)
                end
            end 
        end

        c = c + 1
    end

    self.lastOffset = offset 

    if self:HasSelection() == true and self.clickCounter ~= 1 then
        if not self.lastSelectionDest then 
            self.lastSelectionDest = table_Copy(self.selection.dest) 
        end

        if (math.abs(self.selection.start.line - self.selection.dest.line) == 0 
        and (self.lastSelectionDest.char ~= self.selection.dest.char or self.lastSelectionDest.line ~= self.selection.dest.line))
        or self.lastTextPos.line ~= self.textPos.line 
        then 
            self:HighlightWords(self:GetSelectedText())
            self:RematchPairs()
        elseif math.abs(self.selection.start.line - self.selection.dest.line) ~= 0 then  
            self:ResetHighlighting()

            if self.lastSelectionDest.char ~= self.selection.dest.char or self.lastSelectionDest.line ~= self.selection.dest.line then 
                self:RematchPairs()
            end 
        end

        self.lastSelectionDest = table_Copy(self.selection.dest)
    end

    if self.hasChanges == true then 
        if self.lexAll then 
            self:RunLexer()
        else 
            self:RetimeDiffCheck()
        end
        
        self:UpdateTabIndicators()
        self:RetimeRematch()
        self.hasChanges = false 
        self:ResetHighlighting()

        self:OnTextChanged()
    elseif self.lexerDiffCheck and self.lexerDiffCheck <= RealTime() then
        self.lexerDiffCheck = nil

        if not self.lexAll then  
            self:RunLexer()
        end 

        self:RematchPairs()
    end

    self:ParseVisibleLines()
end

function syntaxBox:OnMouseWheeled(delta)
    self:OnScrolled(delta)

    if input.IsKeyDown( KEY_LCONTROL ) == true then
        delta = delta * self.rescaleMult 
        self:SetFont(self.font.an, self.font.s + delta)
        self:UpdateTabIndicators()
    else
        delta = delta * self.scrollMult 
        self.scrollBar:SetScroll(self.scrollBar:GetScroll() - delta)
    end

    if self.lexerDiffCheck then 
        self:RetimeDiffCheck()
    end 
end

function syntaxBox:CanScroll()
    local scroll = self.scrollBar:GetScroll()
    if scroll == 0 then return false end  
    if scroll == (#(self.lines or {}) - self:CountVisibleLines() + 1) then return false end 
    return true 
end

function syntaxBox:_LinesChanged(a, b)
   -- print(a .. " " ..b )
end

vgui.Register("DSyntaxBox", syntaxBox, "DSleekPanel")




