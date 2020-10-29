--[[
    Universal Syntax Lexer

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

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


--[[
                                                        _                        
                                                        | |                       
                                                        | |     _____  _____ _ __ 
                                                        | |    / _ \ \/ / _ \ '__|
                                                        | |___|  __/>  <  __/ |   
                                                        \_____/\___/_/\_\___|_|   
]]

local SixLexer = {
    config = {}
}

if not SixLexer.meta then SixLexer.meta = {} end

SixLexer.meta.matchesdefault = {
    whitespace = {
        pattern = "%s+"
    }
}

SixLexer.meta.colorsdefault = {
    error = Color(255,0,0),
    whitespace = Color(255,255,255)
}

SixLexer.meta.indentingdefault = {
    open = {},
    close = {},
    openValidation = function() return true end,
    closeValidation = function() return true end,
    offsets = {}
}

SixLexer.meta.configdefault = {
    language = "Plain",

    filetype = ".txt",

    reserved = {},
    unreserved = {},
    closingPairs = {},

    indentation = table.Copy(SixLexer.meta.indentingdefault),

    autoPairing = {},

    matches = table.Copy(SixLexer.meta.matchesdefault),
    captures = {},

    colors = table.Copy(SixLexer.meta.colorsdefault),

    onLineParsed = function() end,
    onLineParseStarted = function() end,
    onMatched = function() end,
    onCaptureStart = function() end,
    onTokenSaved = function() end 
}

SixLexer.config = table.Copy(SixLexer.meta.configdefault)

function SixLexer:Validate()
    if not self.config then 
        self.config = table.Copy(self.meta.configdefault) 
    end 

    setmetatable(self.config, {__index = self.meta.configdefault})

    -- Auto pairing Default config uration setting 
    for k, v in pairs(self.config.autoPairing) do 
        local ap = self.config.autoPairing[k]

        -- Check if nil 
        if not ap.word or not ap.pair then ap = nil end 

        -- Check Type 
        if type(ap.word) ~= "string" or type(ap.pair) ~= "string" then ap = nil end 

        -- Set Default Validation 
        if not ap.validation then ap.validation = function() return true end end  
    end

    -- Matching default configurations setting 
    for k, v in pairs(self.config.matches) do 
        local match = self.config.matches[k]

        if not match then 
            continue 
        end 

        -- Unallowed pattern settings 
        if not match.pattern then 
            continue
        end

        if type(match.pattern) ~= "string" then 
            self.config.matches[k] = nil 
            continue
        end 

        if string.gsub(match.pattern, "%s", "") == "" then 
            self.config.matches[k] = nil 
            continue 
        end 

        -- Set Default Validation
        if not match.validation then 
            self.config.matches[k].validation = function() 
                return true 
            end 
        end 

        -- Set Default Match Color
        if not self.config.colors[k] then self.config.colors[k] = Color(255,255,255) end 
    end

    -- Capture default configurations setting
    for k, v in pairs(self.config.captures) do 
        local capture = self.config.captures[k]

        if not capture then continue end 

        local begin = capture.begin 
        local close = capture.close 
        
        -- Invalid stuff 
        if not begin or not close then 
            self.config.captures[k] = nil 
            continue 
        end 

        if not begin.pattern or not close.pattern then 
            self.config.captures[k] = nil 
            continue
        end
        
        -- Set Default Validation
        if not begin.validation then 
            begin.validation = function() 
                return true 
            end 
        end 

        if not close.validation then 
            close.validation = function() 
                return true 
            end 
        end 

        -- Set Default Multiline 
        if not capture.multiline then 
            capture.multiline = true 
        end 

        -- Set Default Colors 
        if not self.config.colors[k] then 
            self.config.colors[k] = Color(255,255,255) 
        end 
    end

    if not self.config.matches.whitespace then 
        self.config.matches.whitespace = {pattern = "%s+", validation = function() return true end}
    end

    if not self.config.colors.error then 
        self.config.colors.error = Color(255,0,0)
    end

    if not self.config.colors.whitespace then 
        self.config.colors.whitespace = Color(255,255,255)
    end
end

--- Sets the Lexer's text.
function SixLexer:SetText(text)
    self.lines = string.Split(text, "\n")
    self.hasChanges = true 
end

function SixLexer:SetLines(lines)
    self.lines = lines 
end

--- Returns the Lexer's text.
function SixLexer:GetText()
    return table.concat(self.lines, "\n") 
end

--- Sets the configurations for the Lexer
function SixLexer:SetConfig(config)
    self.config = config 
    self:Validate()
end

-- Parse a line using the Lexer according to the set profile
function SixLexer:ParseLine(i, prevLineTokens, unclosedPairs)
    self.config.onLineParseStarted(i)

    unclosedPairs = unclosedPairs or {}

    if not self.lines then 
        self.config.onLineParsed({}, i)
        return {}, unclosedPairs 
    end 

    local result  = {}
    local line    = self.lines[i] or ""
    local buffer  = 0
    local builder = ""
    local capture = {type = "", group = ""}

    local function block(t, g) 
        capture.type, capture.group = t,  g  
    end

    local function unblock()   
        capture.type, capture.group = "", "" 
    end     

    local function addToken(text, typ, startPos, endPos, extra, color)
        if not text or text == "\n" then return end 

        if startPos and type(startPos) == "string" then 
            color = startPos 
            startPos = nil 
        end 

        extra = extra or {}
        typ  = typ  or "error"

        local newToken = {
            type   = typ,
            text   = text,
            color  = color,
            start  = (startPos or buffer),
            ending = (endPos or (buffer + #text -1)),
            extra = extra}

        table_insert(result, newToken)

        self.config.onTokenSaved(newToken, i, typ, buffer, result)

        return newToken
    end

    local function addRest(fallback)
            if builder == "" then return end 
            fallback = fallback or "error"
            addToken(builder, fallback, buffer - #builder, buffer - 1)
            builder = ""
    end  

    local function addToBuilder(str, fallback)
        if not str or str == "\n" or str == "" then return end 

        fallback = fallback or "error"

        if #str > 1 then 
            builder = builder .. str
            return 
        end  

        local function isReserved(someChar)
            for key, chars in pairs(self.config.reserved) do 
                for _, char in pairs(chars) do 
                    if char == someChar then
                        return key
                    end 
                end
            end

            return nil   
        end

        local resr = isReserved(str)
        if resr then
            addRest(fallback) 

            if self.config.reserved[(result[#(result or {})] or {}).type] then 
                result[#result].text = result[#result].text .. str 
            else
                addToken(str, resr)
            end

            return 
        end

        for key, pairs in pairs(self.config.closingPairs) do 
            if str == pairs[1] or str == pairs[2] then 
                local extra = {}
                --[[ 
                    DONT REMOVE YET, MIGHT BE USEFUL LATER ON !!!

                if str == pairs[1] then
                    if not unclosedPairs[pairs[1] ] then unclosedPairs[pairs[1] ] = {} end 
                    table_insert(unclosedPairs[pairs[1] ], {
                        type = key,
                        line = i,
                        tkIndex = #result, 
                        char = buffer 
                    })
                else
                    if unclosedPairs[pairs[1] ] then 
                        local ucs = unclosedPairs[pairs[1] ]
                        local last = ucs[#ucs]
                        if last then 
                            table_remove(unclosedPairs[pairs[1] ])
                            extra = {
                                closes = {
                                    line = last.line,
                                    char = last.char,
                                    tkIndex = last.tkIndex
                                }
                            }
                        end 
                    end
                end]]
                addRest(fallback)
                addToken(str, key, buffer, buffer, extra)
                return 
            end
        end

        builder = builder .. str 
    end

    local function readNext()
        buffer = buffer + 1
        if buffer > #line then return "\n" end 
        return line[buffer]
    end

    local function prevChar()
        return line[buffer - 1] or "\n"
    end

    local function nextChar()
        return line[buffer + 1] or "\n"
    end

    local function nextPattern(pattern)
        if not pattern then return false end 
        local s, e = string_find(line, pattern, buffer)
        if not s or not e then return false end 
        return s == buffer  
    end

    local function readPattern(pattern)
        if not pattern then return false end 
        local s, e = string_find(line, pattern, buffer)
        if not e or not s or s ~= buffer then return "" end 
        return string_sub(line, s, e) 
    end

    if prevLineTokens then --- Check if previous line starts a capture or is inside a capture.
        local lastTokenIndex = 1
        if prevLineTokens[#prevLineTokens].type ~= "newline" then lastTokenIndex = 0 end

        local lastRealToken = prevLineTokens[#prevLineTokens - lastTokenIndex]
        if lastRealToken and lastRealToken.extra.inCapture == true then 
            local capType = lastRealToken.extra.captureType
            block(capType, self.config.captures[capType])
        end
    end

    if line == "" then 
        if capture.type ~= "" then 
            addToken("", capture.type, 1, 1, {inCapture=true, captureType=capture.type}, capture.color or nil)
        else 
            addToken("", "newline", 1, 1)   
        end

        self.config.onLineParsed(result, i)

        return result, unclosedPairs
    end
 
    local function isBinary(char)
     --   print(#string.gsub(self.lines[i], string.char(0), ""))
     --   return #string.gsub(self.lines[i], string.char(0), "") < #self.lines[i] / 4
       -- return string.byte(char) > 126 
        return false --SSLE.modules.ascii:IsControlChar(char) 
    end

    do 
        local interrupt = 0
        local ECC = 0 -- ECC = Extra Character Counter 
        while true do 
            if interrupt > #(self.lines[i] or {}) * 10 then break end -- Just to make sure 

            if capture.type == "" then
                local char = readNext()

                if char == "\n" then 
                    addRest()
                    addToken("", "newline")            
                    break
                elseif char == "\t" then 
                    addRest()
                    addToken("    ", "whitespace")  -- bruh moment     
                    continue 
                elseif isBinary(char) then -- Binary shit 
                    addRest()
                    addToken("0x" .. bit.tohex(type(char) == "number" and char or string.byte(char), 2))
                    continue 
                end

                local patternFound = false 
                --- Match handling
                for k, v in pairs(self.config.matches) do 
                    if nextPattern(v.pattern) == true then
                        local finding = readPattern(v.pattern)

                        local function triggerOther(otherTrigger)
                            if not otherTrigger then return end
                            local xd = self.config.matches[otherTrigger]
                            if type(otherTrigger) == "string" and xd then 
                                k = otherTrigger 
                                v = xd 
                            end
                        end

                        patternFound = v.validation(line, buffer, finding, table_Count(result or {}), result or {}, i, triggerOther)

                        if patternFound == true then 
                            self.config.onMatched(finding, i, k, buffer, result)
                            addRest()  
                            addToken(finding, k, (v.color and v.color or nil))
                            buffer = buffer + #finding - 1
                            break 
                        end 
                    end
                end

                if patternFound == true then continue end 

                --- Capture Start handling
                for k, v in pairs(self.config.captures) do
                    local start = v.begin 
                    if nextPattern(start.pattern) == true then 
                        local finding = readPattern(start.pattern)

                        local function triggerOther(otherTrigger)
                            if not otherTrigger then return end
                            local xd = self.config.captures[otherTrigger]
                            if type(otherTrigger) == "string" and xd then 
                                k = otherTrigger 
                                v = xd 
                            end
                        end

                        patternFound = start.validation(line, buffer, finding, table_Count(result or {}), result or {}, i, triggerOther)

                        if patternFound == true then          
                            self.config.onCaptureStart(start.pattern, i, k, buffer, result)
                            block(k, v)
                            builder = builder .. finding 
                            buffer = buffer + #finding - 1
                            break                  
                        end
                    end
                end

                if patternFound == true then continue end 

                addToBuilder(char)
            else
                local char = readNext()

                local bt = false 

                if char == "\n" then 
                    if builder ~= "" then 
                        if capture.group.multiline ~= nil and capture.group.multiline == false then  

                            addToken(builder, 
                                capture.type, 
                                buffer - #builder + ECC, 
                                buffer + ECC)

                        else     

                            addToken(builder, 
                                capture.type, 
                                buffer - #builder + ECC, 
                                buffer + ECC, 
                                {
                                    inCapture = true, 
                                    captureType = capture.type
                                })

                        end 
                        builder = ""
                    end

                    ECC = 0

                    break 
                elseif char == "\t" then -- Im too lazy to handle this in the editor, so here is a replacer
                    builder = builder .. "    "
                    ECC = ECC + 4
                    bt = true 
                elseif isBinary(char) == true then
                    builder = builder .. "0x" .. bit.tohex(type(char) == "number" and char or string.byte(char), 2) 
                end

                local closeFound = false 
                local close = capture.group.close 
                if nextPattern(close.pattern) == true then 
                    local finding = readPattern(close.pattern)

                    closeFound = close.validation(line, buffer, finding, table_Count(result or {}), result or {}, i)

                    if closeFound == true then 
                        self.config.onCaptureEnd(close.pattern, i, capture.type, buffer, result)

                        builder = builder .. finding 

                        addToken(builder, 
                            capture.type, 
                            buffer - #builder + #finding + ECC, 
                            buffer + 1 + ECC, 
                            {endsCapture=1}, 
                            capture.group.color or nil)

                        builder = ""
                        buffer  = buffer + #finding - 1
                    end
                end

                if closeFound == true then 
                    unblock()
                    continue 
                end         

                if bt == true then continue end 

                builder = builder .. char
            end
        end
    end

    self.config.onLineParsed(result, i)

    if i == #self.lines then 
        addToken("", "endoftext")
    end

    return result, unclosedPairs
end

SSLE.modules = SSLE.modules or {}
SSLE.modules.lexer = SixLexer 
