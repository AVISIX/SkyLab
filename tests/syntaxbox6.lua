local DataContext = {}
DataContext.__index = DataContext

DataContext.defaultLines = {}
DataContext.context = {}
DataContext.defaultText = ""

DataContext.matchesdefault = {
    whitespace = {
        pattern = "%s+"
    }
}

DataContext.colorsdefault = {
    error = Color(255,0,0),
    whitespace = Color(255,255,255)
}

DataContext.indentingdefault = {
    open = {},
    close = {},
    openValidation = function() return true end,
    closeValidation = function() return true end,
    offsets = {}
}

DataContext.configdefault = {
    language = "Plain",

    filetype = ".txt",

    reserved = {},
    unreserved = {},
    closingPairs = {},
    folding = {
        open = {},
        close = {}
    },
    indentation = table.Copy(DataContext.indentingdefault),

    autoPairing = {},

    matches = table.Copy(DataContext.matchesdefault),
    captures = {},

    colors = table.Copy(DataContext.colorsdefault),

    onLineParsed = function() end,
    onLineParseStarted = function() end,
    onMatched = function() end,
    onCaptureStart = function() end,
    onTokenSaved = function() end 
}

--[[
    To Do:
        - Make 2 seperate queues for parsing lines and for getting the folding status 



    Notes:
        - When closing the editor, save the folds in the sqlite db and save the timestamp. if the file was edited after that specific timestamp, reset the folds to unfolded 
]]

function DataContext:LineConstructed() end 
function DataContext:LineConstructionStarted() end 

function DataContext:FoldingAvailbilityCheckStarted() end 
function DataContext:FoldingAvailbilityCheckCompleted() end 
function DataContext:FoldingAvailbilityFound(a, b) end

function DataContext:LineFolded() end 
function DataContext:LineUnfolded() end 

function DataContext:SetRulesProfile(profile)
    if not profile then return end 

    setmetatable(profile, {__index = profile.configdefault})

    -- Auto pairing Default config uration setting 
    for k, v in pairs(profile.autoPairing) do 
        local ap = profile.autoPairing[k]

        -- Check if nil 
        if not ap.word or not ap.pair then ap = nil end 

        -- Check Type 
        if type(ap.word) ~= "string" or type(ap.pair) ~= "string" then ap = nil end 

        -- Set Default Validation 
        if not ap.validation then ap.validation = function() return true end end  
    end

    if not profile.colors then profile.colors = {} end 

    -- Matching default configurations setting 
    for k, v in pairs(profile.matches) do 
        local match = profile.matches[k]

        if not match then 
            continue 
        end 

        -- Unallowed pattern settings 
        if not match.pattern then 
            continue
        end

        if type(match.pattern) ~= "string" then 
            profile.matches[k] = nil 
            continue
        end 

        if string.gsub(match.pattern, "%s", "") == "" then 
            profile.matches[k] = nil 
            continue 
        end 

        -- Set Default Validation
        if not match.validation then 
            profile.matches[k].validation = function() 
                return true 
            end 
        end 

        -- Set Default Match Color
        if not profile.colors[k] then profile.colors[k] = Color(255,255,255) end 
    end

    -- Capture default configurations setting
    for k, v in pairs(profile.captures) do 
        local capture = profile.captures[k]

        if not capture then continue end 

        local begin = capture.begin 
        local close = capture.close 
        
        -- Invalid stuff 
        if not begin or not close then 
            profile.captures[k] = nil 
            continue 
        end 

        if not begin.pattern or not close.pattern then 
            profile.captures[k] = nil 
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
        if capture.multiline == nil then 
            capture.multiline = true 
        end 

        -- Set Default Colors 
        if not profile.colors[k] then 
            profile.colors[k] = Color(255,255,255) 
        end 
    end

    if not profile.matches.whitespace then 
        profile.matches.whitespace = {pattern = "%s+", validation = function() return true end}
    end

    if not profile.colors.error then 
        profile.colors.error = Color(255,0,0)
    end

    if not profile.colors.whitespace then 
        profile.colors.whitespace = Color(255,255,255)
    end

    -- Since its more efficient to do {["myValue"] = 1} than {"myValue"} we use this Function to swap the key and value, since its nicer to write but more efficent 
    local function swapNumericKeysWithStringValues(t) 
        local result = {}
        for k, v in pairs(t) do 
            if type(v) == "table" then 
                result[k] = swapNumericKeysWithStringValues(v)
            elseif type(k) == "number" and type(v) == "string" then 
                result[v] = 1
            else 
                result[k] = v 
            end
        end
        return result 
    end

    self.profile = swapNumericKeysWithStringValues(profile) 
end

function DataContext:ResetProfile()
    self:SetRulesProfile(table.Copy(self.configdefault))
end

-- This Function does the whole Lexing Process (Only 1 line at a time)
function DataContext:ParseRow(lineNumber, prevTokens, extendExistingTokens)
    if not self.profile then return {} end 
    if not lineNumber then return {} end

    local text = self.defaultLines[lineNumber] 

    if not text then return {} end  

    if extendExistingTokens == nil then extendExistingTokens = false end 

    self.profile.onLineParseStarted(lineNumber, text)

    prevTokens = prevTokens or {}

    local result = {}
    local buffer = 1
    local builder = ""

    local capturization = {type = "",group = {}}

    do -- Check if the last line was in a capture, to continue the capture of the last line
        local lastRealToken = prevTokens[#prevTokens - 1]
        if lastRealToken and lastRealToken.inCapture == true and self.profile.captures[lastRealToken.type] then 
            capturization.type  = lastRealToken.type 
            capturization.group = self.profile.captures[lastRealToken.type] 
        end
    end

    -- Save a token to the current token context
    local function addToken(t, type, inCapture)
        if not t then return end 

        local tokenStart = ((result[#result] or {}).ending or 0) + 1  

        table.insert(result, {
            text = t,
            line = lineNumber, 
            type = type or "error",
            start = tokenStart,
            ending = tokenStart + #t - 1,
            inCapture = inCapture
        })

        local lt = result[#result] 

        lt.index = #result 

        self.profile.onTokenSaved(lt, lineNumber, lt.type, buffer, result)

        return lt
    end

    -- Add the leftovers as error to the token context
    local function addRest()
        if builder == "" then return end 
        addToken(builder, "error")
        builder = ""
    end

    local function extendLastToken(type, text)
        if extendExistingTokens == false then return false end 

        if builder == "" and (result[#result] or {}).type == type then 
            result[#result].text = result[#result].text .. text 
            result[#result].ending = result[#result].ending + #text 

            return true 
        end

        return false 
    end

    local function evaluateChar(text)
        if not text or text == "" then return end 

        if #text > 1 or capturization.type ~= "" then 
            builder = builder .. text
            return 
        end  

        for k, v in pairs(self.profile.reserved) do
            if v[text] then 
                if extendLastToken(k, text) == true then return end -- We do this to not add useless new Tokens. Just add the data to the old token, if its the same type 
                addRest()
                addToken(text, k)
                return 
            end
        end

        for k, v in pairs(self.profile.closingPairs) do 
            if v.open == text or v.close == text then 
                if extendLastToken(k, text) == true then return end 
                addRest()
                addToken(text, k)
                return 
            end
        end

        if self.profile.unreserved[text] then 
            if extendLastToken("unreserved", text) == true then return end 
            addRest()
            addToken(text, "unreserved")
            return 
        end

        builder = builder .. text 
    end 

    local function readPattern(pattern)
        if not pattern then return nil end 

        local a,b,c = string.find(text, pattern, buffer)

        if not a or not b or a ~= buffer then return nil end 

        return c or string.sub(text, a, b)
    end 

    repeat 
        if capturization.type == "" then -- Not in capture  
            if (function() -- Handle Matches (Inside function cause of 'return' being convenient )
                for k, v in pairs(self.profile.matches) do 
                    local match = readPattern(v.pattern)
                    
                    if not match then continue end

                    local val = v.validation(text, buffer, match, #result, result, lineNumber) or false 

                    if type(val) == "string" then 
                        k   = val
                        val = true 
                    end 

                    if val == true then
                        addRest()
                        addToken(match, k)

                        buffer = buffer + #match 

                        self.profile.onMatched(match, lineNumber, k, buffer, result)

                        return true 
                    end 
                end
                return false 
            end)() == true or
            (function() -- Handle Captures 
                for k, v in pairs(self.profile.captures) do 
                    local match = readPattern(v.begin.pattern)

                    if not match then continue end 

                    local val = v.begin.validation(text, buffer, match, #result, result, lineNumber)

                    if type(val) == "string" then 
                        k   = val
                        val = true 
                    end 

                    if val == true then  
                        addRest()

                        builder = match
                        buffer = buffer + #match 

                        capturization.type  = k 
                        capturization.group = v 

                        self.profile.onCaptureStart(match, lineNumber, k, buffer, result)

                        return true 
                    end
                end
                return false 
            end)() == true then continue end 
        else   
            local t, g = capturization.type, capturization.group 
            local match = readPattern(g.close.pattern)

            if match then 
                local val = g.close.validation(text, buffer, match, #result, result, lineNumber)

                if val == true then 
                    buffer = buffer + #match 
                    builder = builder .. match 

                    addToken(builder, t)

                    builder = ""

                    capturization.type = "" 
                    
                    self.profile.onCaptureEnd(match, lineNumber, t, buffer, result)
                    
                    continue 
                end 
            end
        end    

        evaluateChar(text[buffer])

        buffer = buffer + 1

    until buffer > #text 

    if builder ~= "" then 
        if capturization.type ~= "" then 
            addToken(builder, capturization.type, capturization.group.multiline)
        else 
            addRest()  
        end
    end 

    if ((result[#result] or {}).type or "") ~= "endofline" then
        addToken("", "endofline")
    end 

    self.profile.onLineParsed(result, text)

    return result
end

function DataContext:CountIndentation(tokens, tokenCallback)
    if not tokens or #tokens == 0 then return end 

    tokenCallback = tokenCallback or function() end 

    local level = 0
    local offset = 0

    local openFound   = false 
    local closeFound  = false 
    local offsetFound = false 

    for _, token in pairs(tokens) do 
        if not token then break end 

        tokenCallback(token)

        -- Indenting 
        if openFound == false then 
            local open = self.profile.indentation.open[token.text]
            if open ~= nil then 
                openFound = true 

                if type(open) == "boolean" then 
                    level = 0 
                    continue 
                end

                level = level + open
            end 
        end 
        
        if closeFound == false then 
            local close = self.profile.indentation.close[token.text]            
            if close ~= nil then 
                closeFound = true 

                if type(close) == "boolean" then 
                    level = 0 
                    continue 
                end
                
                level = level - close
            end 
        end 
        
        -- Offsets
        if offsetFound == false then 
            local offsets = self.profile.indentation.offsets[token.text]
            if offsets ~= nil then 
                offsetFound = true 
                offset = offsets 
            end
        end 
    end

    return level, offset  
end

function DataContext:FindMatchDown(tokenIndex, lineIndex)
    local openers = self.profile.folding.open 
    local closers = self.profile.folding.close 

    if not openers or not closers then return end 

    if not self.context[lineIndex] then return end 

    local function prog()
        tokenIndex = tokenIndex + 1

        if tokenIndex > #self.context[lineIndex].tokens then 

            tokenIndex = 1
            lineIndex = lineIndex + 1

            if lineIndex > #self.context then return nil end 
        end

        return self.context[lineIndex].tokens[tokenIndex] 
    end

    local curToken = prog()
    local counter = 1 

    while true do    
        if openers[curToken.text] then 
            counter = counter + 1
        elseif closers[curToken.text] then  
            counter = counter - 1
        end

        if counter == 0 then break end
        
        curToken = prog()
    end

    return curToken, tokenIndex, lineIndex
end

function DataContext:FindMatchUp(tokenIndex, lineIndex)
    local openers = self.profile.folding.open 
    local closers = self.profile.folding.close 

    if not openers or not closers then return end 

    if not self.context[lineIndex] then return end 
    if not self.context[lineIndex].tokens then return end 
    if not self.context[lineIndex].tokens[tokenIndex] then return end 

    local function prog()
        tokenIndex = tokenIndex - 1

        if tokenIndex < 1 then 
            lineIndex = lineIndex - 1

            if lineIndex < 1 then return nil end 

            tokenIndex = #self.context[lineIndex].tokens
        end

        return self.context[lineIndex].tokens[tokenIndex] 
    end

    local curToken = prog()
    local counter = 1 

    while curToken do    
        if openers[curToken.text] then 
            counter = counter + 1
        elseif closers[curToken.text] then  
            counter = counter - 1
        end

        if counter == 0 then break end
        
        curToken = prog()
    end

    return curToken, tokenIndex, lineIndex
end 

function DataContext:GetGlobalFoldingAvailability()
    local openers = self.profile.folding.open 
    local closers = self.profile.folding.close 

    if not openers or not closers then return end 

    self:FoldingAvailbilityCheckStarted()

    for lineIndex, contextLine in pairs(self.context) do 
        if not contextLine.tokens then continue end -- Skip the ones that have already been parsed 

        if contextLine.folding and contextLine.folding.folded == true then continue end 

        local canFold = false 

        for tokenIndex, token in pairs(contextLine.tokens) do 
            if not token then break end 

            if openers[token.text] then
                local match, ti, li = self:FindMatchDown(tokenIndex, lineIndex)

                if not match then continue end 
            
                local diff = li - lineIndex - 1

                if li ~= lineIndex and diff ~= 0 then 
                    self.context[lineIndex].folding = {
                        available = diff,
                        folds = {}
                    }

                    self:FoldingAvailbilityFound(lineIndex, diff)

                    canFold = true 
                end 
            end
        end

        if contextLine.folding and canFold == false then 
            self.context[lineIndex].folding = nil -- Remove it when the line is no longer fold-able 
        end
    end

    self:FoldingAvailbilityCheckCompleted()
end

function DataContext:FoldLine(i)
    if i == nil then return end 

    if i < 1 or i > #self.context then return end 
    local t = self.context[i]

    if not t.folding then return end
    
    local n = i + 1

    while n < i + t.folding.available + 1 do 
        local line = self.context[i + 1]

        table.insert(t.folding.folds, line)

        if line.folding and #line.folding.folds > 0 then 
            n = n + #line.folding.folds + 1 -- We need to skip the lines that have already been folded so we dont go out of the folding bounds 
        else 
            n = n + 1
        end 

        table.remove(self.context, i + 1)
    end

    self:LineFolded(i)
    self:LineFolded(match)
end

function DataContext:UnfoldLine(i)
    if i == nil then return end 

    if i < 1 or i > #self.context then return end 
    local t = self.context[i]
    if not t.folding then return end

    for l, v in pairs(t.folding.folds) do 
        table.insert(self.context, i + l, v)
    end

    t.folding.folds = {}

    self:LineUnfolded(i)
    self:LineUnfolded(match)
end

local function constructTextFromTokens(t) 
    if not t then return {} end 
    local r = ""
    for _, v in pairs(t) do 
        if not v.text then break end 
        r = r .. v.text 
    end
    return r 
end

function DataContext:TrimRight(i)
    if i == nil then return end     

    local line = self.context[i]
    if not line then return end 

    local tokens = line.tokens 
    if not tokens then return end 

    if  (tokens[#tokens - 1] or {}).type == "whitespace" then 
        table.remove(self.context[i].tokens, #tokens - 1)
        self.context[i].text = constructTextFromTokens(self.context[i].tokens)
    end 
end

function DataContext:ConstructContextLine(i)
    if not i then return {} end 

    self:LineConstructionStarted(i)

    self.defaultLines[i] = string.gsub(self.defaultLines[i], "\r", "    ") -- Fuck this shit i legit cannot be asked...

    local lastContextLine = self.context[i - 1] or {}

    local temp = {}

    temp.index = i --(self.context[i] or {}).index or i  
    temp.text   = self.defaultLines[i] 
    temp.tokens = self:ParseRow(i, (lastContextLine.tokens or {}))

    local level = lastContextLine.level 

    if level == nil then level = 0 end 

    if type(level) ~= "number" then 
        if type(level) == "boolean" then 
            level = 0
        else 
            local c = 2
            local lc = getPrevContext(c)

            while (lc.level or true) == false do  
                lc = getPrevContext(c)
                c = c + 1
            end

            level = lc.level or 0 
        end 
    end

    local countedLevel, offset = self:CountIndentation(temp.tokens)

    temp.offset = offset 
    temp.nextLineIndentationOffsetModifier = countedLevel + (lastContextLine.nextLineIndentationOffsetModifier or 0)
    temp.level = math.max((lastContextLine.nextLineIndentationOffsetModifier or 0) + math.min(countedLevel, 0), 0)

    self:LineConstructionStarted(i, temp)

    return temp 
end

function DataContext:SetContext(text)
    if not text then return end 

    rules = rules or ""

    if type(text) == "table" then 
        self.defaultLines = text 
    elseif type(text) == "string" then     
        self.defaultLines = string.Split(text, "\n")
    else return end 

    self.context = {}

    for i, line in pairs(self.defaultLines) do 
        if not line then break end 
        table.insert(self.context, self:ConstructContextLine(i))
        self:TrimRight(i)
    end

    self:GetGlobalFoldingAvailability()

    return self.context 
end

function DataContext:InsertLine(text, i)
    i = i or #self.defaultLines
    i = math.Clamp(i, 1, #self.defaultLines)

    table.insert(self.defaultLines, text, i)
    table.insert(self.context, self:ConstructContextLine(i))

    for n = i + 1, #self.context, 1 do 
        self.context[n].index = self.context[n].index + 1 -- shift up 
    end

    self:GetGlobalFoldingAvailability()
end

function DataContext:RemoveLine(i)
    i = i or #self.defaultLines
    i = math.Clamp(i, 1, #self.defaultLines)

    self:CheckPrevLine(i)

    table.remove(self.defaultLines, i)
    table.remove(self.context, i)

    for n = i, #self.context, 1 do 
        self.context[n].index = self.context[n].index - 1 -- shift down
    end

    self:GetGlobalFoldingAvailability()
end

function DataContext:CheckPrevLine(i)
    if self.context[i - 1] and self.context[i - 1].folding and #self.context[i - 1].folding.folds > 0 then 
        self:UnfoldLine(i - 1)
    end
end

function DataContext:OverrideLine(i, text)
    if i <= 0 or i > #self.defaultLines then return end 
    if not text then return end 
    
    self:CheckPrevLine(i)

    self.defaultLines[i] = text 
    self.context[i] = self:ConstructContextLine(i)

    self:GetGlobalFoldingAvailability()
end

function DataContext:ParseDifferences()
    for k, v in pairs(self.defaultLines) do 
        local match = self.context[k]

        if not match or match.text ~= v then 
            self.context[k] = self:ConstructContextLine(k)
        end 
    end

    self:GetGlobalFoldingAvailability()
end

local prof = {}

do 

    local keywords = {
        ["if"]       = 1,
        ["else"]     = 1,
        ["elseif"]   = 1,
        ["while"]    = 1,
        ["for"]      = 1,
        ["foreach"]  = 1,
        ["switch"]   = 1,
        ["case"]     = 1,
        ["break"]    = 1,
        ["default"]  = 1,
        ["continue"] = 1,
        ["return"]   = 1,
        ["local"]    = 1,
        ["function"] = 1
    }
    
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
    
    local function isSpecial(char)
        return isNumber(char) == false and isLower(char) == false and isUpper(char) == false 
    end 
    
    local E2Cache = {}
    
    prof = {
        language = "Expression 2",
        filetype = "txt",
        commonDirectories = 
        {
            {
                root = "DATA",
                directory = "e2files"
            },
            {
                root = "DATA",
                directory = "expression2"
            }
        },
        reserved = 
        {
            operators = {
                ["+"]=1,
                ["-"]=1,
                ["/"]=1,
                ["|"]=1,
                ["<"]=1,
                [">"]=1,
                ["="]=1,
                ["*"]=1,
                ["?"]=1,
                ["$"]=1,
                ["!"]=1,
                [":"]=1,
                ["&"]=1,
                ["%"]=1,
                ["~"]=1,
                ",",
                ["^"]=1
            },
            others =
            {
                ["."]=1, 
                [";"]=1
            }
        },
        indentation = 
        {
            open = {
                ["{"]=1, 
                ["%("]=1, 
                ["%["]=1
            },

            close = {
                ["}"]=1, 
                ["%)"]=1, 
                ["%]"]=1
            },

            offsets = {
                ["#ifdef"] = false, 
                ["#else"] = false,    
                ["#endif"] = false 
            }
        },
        folding = 
        {
            open =
            {
                "(",
                "{",
                "[",
                "#ifdef"
            },
            close = 
            {
                ")",
                "}",
                "]",
                "#endif"
            }
        },
        autoPairing =
        {
            {
                word = "{",
                pair = "}",
                validation = function() return true end     
            },
            {
                word = "(",
                pair = ")",
                validation = function() return true end 
            },
            {
                word = "[",
                pair = "]",
                validation = function(line, charIndex, lineIndex)  
                    return (line[charIndex - 1] or "") ~= "#"
                end 
            },
            {
                word = '"',
                pair = '"',
                validation = function(line, charIndex, lineIndex)  
                    return (line[charIndex - 1] or "") ~= '"'
                end 
            },
            {
                word = "#[", 
                pair = "]#",
                validation = function() return true end 
            },
        },
        unreserved = 
        {
            ["_"] = 1,
            ["@"] = 1
        },
        closingPairs = 
        {
            scopes = {
                open = "{",
                close = "}"
            },
            parenthesis = 
            {
                open = "(",
                close = ")"
            },
            propertyAccessors = 
            {
                open = "[",
                close = "]"
            }
        },
        matches = 
        {
            preprocDirective = 
            {
                pattern = "^@[^ ]*",
                validation = function(line, buffer, result, tokenIndex, tokens, lineIndex, triggerOther)
                    if result == "@persist" 
                    or result == "@inputs" 
                    or result == "@outputs"
                    or result == "@autoupdate" then 
                        return true 
                    end
                    return false 
                end
            },
            preprocLine =
            {
                pattern = "^@[^\n]*",
                validation = function(line, buffer, result, tokenIndex, tokens)  
                    local _, _, txt = string.find(line, "^(@[^ ]*)")
                    if txt == "@name" 
                    or txt == "@trigger" 
                    or txt == "@model" then 
                        return true 
                    end
                    return false 
                end
            },
            variables = 
            {
                pattern     = "[A-Z][a-zA-Z0-9_]*",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    return isSpecial(line[buffer - 1]) == true 
                end,
            },
            keywords = 
            {
                pattern = "[a-z][a-zA-Z0-9_]*",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    if not line then return false end 
                    if result == "function" then 
                        local _,_,str = string.find(line, "^%s*([^ ]*)", 1)
                        if str ~= "function" then return false end 
                    end
                    return keywords[result] and isSpecial(line[buffer - 1]) == true
                end
            },
            userfunctions = 
            {
                pattern = "[a-z][a-zA-Z0-9_]*",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    if keywords[result] then 
                        return false 
                    end

                    local function getPrevToken(index)
                        return tokens[tokenIndex - index] or {}
                    end
                    --[[
                                            function someFunction()     
                                    function someType:someFunction()
                                    function someType someFunction()
                        function someType someType:someFunction()
                           5    4    3   2    1   0
                    ]]

                    local res = false 
                    if getPrevToken(1).text == "function" or getPrevToken(3).text == "function" or getPrevToken(5).text == "function" then 
                        res = true 
                    end

                    return res == true and line[buffer + #result] == "(" and isSpecial(line[buffer - 1]) == true 
                end,
                reparseOnChange = true 
            },
            builtinFunctions = 
            {
                pattern = "[a-z][a-zA-Z0-9_]*",
                validation = function(line, buffer, result, tokenIndex, tokens, lineIndex, tot) 
                    if keywords[result] then 
                        return false 
                    end

                    for i, lineCache in pairs(E2Cache) do -- Need cache for every line so if something cached gets removed it can be updated
                        if i > lineIndex then continue end 
                        if lineCache.userfunctions and lineCache.userfunctions[result] then 
                            return "userfunctions" 
                        end
                    end 

                    local extraCheck = true 
                    if E2Lib then 
                        if not wire_expression2_funclist[result] then 
                            extraCheck = false 
                        end
                    end

                    local function nextChar(char)
                        return line[buffer + #result] == char  
                    end

                    return nextChar("(") and extraCheck and isSpecial(line[buffer - 1]) == true 
                end
            },
            types = 
            {
                pattern = "[a-z][a-zA-Z0-9_]*",
                validation = function(line, buffer, result, tokenIndex, tokens, lineIndex, tOther) 
                    if keywords[result] then 
                        return false 
                    end

                    local function nextChar(char)
                        return line[buffer + #result] == char  
                    end
                    
                    local extraCheck = true  

                    if E2Lib then 
                        local function istype(tp)
                            return wire_expression_types[tp:upper()] or tp == "number" or tp == "void"
                        end
                        extraCheck = istype(result)
                        if extraCheck == false then 
                            if wire_expression2_funclist[result] and isSpecial(line[buffer - 1]) == true then 
                                return "builtinFunctions" 
                            end
                        end
                    end

                    return (nextChar("]") or nextChar(" ") or nextChar(":") or nextChar("=") or nextChar(",") or nextChar("") or nextChar(")")) and extraCheck and isSpecial(line[buffer - 1]) == true 
                end
            },
            includeDirective = 
            {
                pattern = "#include",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    return line[buffer + #result] == " "
                end
            },
            ppcommands = 
            {
                pattern = "#[a-z]+",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    local res = result == "#ifdef" 
                                or result == "#else" 
                                or result == "#endif" 

                    return res 
                end
            },
            constants = 
            {
                pattern = "_[A-Z][A-Z_0-9]*",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    if E2Lib then 
                        return wire_expression2_constants[result] ~= nil 
                    end
                    return true  
                end
            },
            lineComment = 
            {
                pattern = "#[^\n]*",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    local _, _, txt = string.find(result, "(#[^ ]*)")
                    if txt == "#ifdef" 
                    or txt == "#include"
                    or txt == "#else" 
                    or txt == "#endif"
                    or string.sub(txt, 1, 2) == "#[" then return false end 
                    return true 
                end
            },
            decimals = 
            {
                pattern = "[0-9][0-9.e]*",
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    local function nextChar(char)
                        return line[buffer + #result] == char  
                    end

                    if nextChar("x") or nextChar("b") then return false end 

                    return true 
                end
            },
            hexadecimals = 
            {
                pattern = "0[xb][0-9A-F]+"
            }
        },
        captures = 
        {
            strings = 
            {
                begin = {
                    pattern = '"'
                },
                close = {
                    pattern = '"',
                    validation = function(line, buffer, result, tokenIndex, tokens) 
                        local stepper = 0
                        local prevChar = line[buffer - 1 - stepper] or ""

                        while prevChar == "\\" do 
                            stepper = stepper + 1
                            prevChar = line[buffer - 1 - stepper]
                        end

                        return stepper == 0 or stepper % 2 == 0   
                    end
                }
            },
            comments = 
            {
                begin = {
                    pattern = '#%['
                },
                close = {
                    pattern = '%]#'
                }
            }
        },

        onLineParseStarted = function(i)
            E2Cache[i] = {}
        end,

        onLineParsed = function(result, i)  

        end,

        onMatched = function(result, i, type, buffer, prevTokens) 
            if type == "userfunctions" then 
                if not E2Cache[i] then E2Cache[i] = {} end 
                if not E2Cache[i][type] then E2Cache[i][type] = {} end 
                if not E2Cache[i][type][result] then E2Cache[i][type][result] = 0 end 
                E2Cache[i][type][result] = E2Cache[i][type][result] + 1
            end
        end,

        onCaptureStart = function(result, i, type, buffer, prevTokens) 
        end,

        onCaptureEnd = function(result, i, type, buffer, prevTokens) 
        end,
        
        onTokenSaved = function(result, i, type, buffer, prevTokens) 
        end,

        colors = 
        {
            preprocDirective = Color(240,240,160),
            preprocLine      = Color(240,240,160),
            operators        = Color(255,255,255),
            scopes           = Color(255,255,255),
            parenthesis      = Color(255,255,255),
            strings          = Color(150,150,150),
            comments         = Color(128,128,128),
            lineComment      = Color(128,128,128),
            variables        = Color(160,240,160),
            decimals         = Color(247,167,167),
            hexadecimals     = Color(247,167,167),
            keywords         = Color(160,240,240),
            includeDirective = Color(160,240,240),
            builtinFunctions = Color(160,160,240),  
            userfunctions    = Color(102,122,102),
            types            = Color(240,160,96),
            constants        = Color(240,160,240),
            ppcommands       = Color(240,96,240),
            error            = Color(241,96,96),
            others           = Color(241,96,96)
        }}

        DataContext:SetRulesProfile(prof)
end 



--[[
    local r = DataContext:SetContext([[@name Codeviewer - V2

    # [ --- Config --- ] #
    @persist CVConfig:table Name:string

    # [ --- Globals --- ] #
    @persist PrevLine PrevX LastLineNumbersWidth LastLineIndex LastToggle
    @persist [Mode PrevMode CurrentFile FileContents]:string
    @persist EGP:wirelink
    @persist [E User]:entity
    @persist [E2Events E2Data]:table
    @persist [Cursor PrevTextPos]:vector2

    # [ --- File Loader --- ] #
    @persist FileLoading 

    # [ --- Parser & Combiner --- ] #
    @persist E2Parsed E2Combined 

    # [ --- Visualizer --- ] #
    @persist VLoading VLineCounter VDone TextStartingIndex
    @persist [PreprocText CommentsText StringsText KeywordsText VariablesText TypesText NumbersText UserFunctionsText FunctionsText EnumsText PPCommandsText DefaultText TabSpaceText ErrorText]:string

    # [ --- File Browser --- ] #
    @persist FileListing Files:array BrowserActive SavedCursor:vector2 Page Up2Date BrowserItemsStartIndex FilePath:string

    #@model models/hunter/blocks/cube05x05x05.mdl

    interval(60)

    AimEnt = User:aimEntity()

    if(first())
    { 
        Name = "Codeviewer - V2.5"
        
        E = entity()
        
        setName(Name)
        
        runOnChat(1)
        runOnLast(1)
        runOnFile(1)
    }] ])

                DataContext:FoldLine(5)

        PrintTable(r)

]]

local fontBank = {}

local function dark(n,a)
    if a == nil then a = 255 end 
    return Color(n,n,n,a)
end

local self = {}

local offset = 25 
local textoffset = 3

local function mSub(x, strength) return x - (math.floor(x) % strength) end

function self:Init()
    self.colors = {}
    self.colors.background = dark(45)
    self.colors.lineNumbersBackground = dark(55)
    self.colors.linesEditorDivider = Color(240,130,0, 100)
    self.colors.lineNumbers = Color(240,130,0)
    self.colors.highlights = Color(0,60,220,50)
    self.colors.caret = Color(25,175,25)
    self.colors.endOfText = dark(150,5)
    self.colors.tabIndicators = Color(175,175,175,35)
    self.colors.currentLine = dark(200,10)
    self.colors.foldingIndicator = dark(175,35)

    self.tabSize = 5


    self.caret = {
        x = 0,
        y = 0, 
        char = 1,
        line = 1
    }

    self.selection = {
        start = {
            char = 0,
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
    self.lastTextPos = {char=1,line=1}

    self.font = {
        w = 0,
        h = 0,
        s = 0,
        n = "",
        an = ""
    }

    self.foldIcon   = Material("icon16/connect.png")
    self.unfoldIcon = Material("icon16/disconnect.png")
    self.foldButtons = {}

    self.highlights = {}

    self.allTabs = {}

    self.undo = {}
    self.redo = {}

    self.data = table.Copy(DataContext)

    self.data.FoldingAvailbilityCheckStarted = function() 
        for k, v in pairs(self.foldButtons) do
            if IsValid(v) == false then continue end
            v:Remove()
        end

        self.foldButtons = {}
    end
    self.data.FoldingAvailbilityFound = function(_, i, len, t)
        local b = self:MakeFoldButton()
        b:SetVisible(false)
        b.super = self.data.context[i]
        b.DoClick = function(_)
            local super = b.super 

            if not super then 
                self:CollectBadButtons()
                return 
            end
        
            local line 

            for k, v in pairs(self.data.context) do 
                if v.index == super.index then
                    line = k 
                    break 
                end 
            end

            if not line then return end 

            if #super.folding.folds == 0 then  
                _:SetIcon("icon16/connect.png")
                self.data:FoldLine(line)
            else 
                _:SetIcon("icon16/disconnect.png")
                self.data:UnfoldLine(line)
            end

            self:CollectBadButtons()
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

    self:SetCursor("beam")
end

function self:CollectBadButtons()
    for k, v in pairs(self.foldButtons) do 
        if IsValid(v) == false then 
            if v.super then 
                v.super.button = nil 
            end
            self.foldButtons[k] = nil 
            continue 
        elseif IsValid(v) == true and not v.super then 
            v:Remove()
            self.foldButtons[k] = nil 
            continue 
        end
        v:SetVisible(false) 
    end
end

function self:Fold(n)
    self.data:FoldLine(n)
end

function self:Unfold(n)
    self.data:UnfoldLine(n)
end

function self:GetLine(i)
    for k, v in pairs(self.data.context) do 
        if v.index == i then 
            return v 
        end
    end
    return nil 
end

function self:TextChanged() end 
function self:_TextChanged() 
    local new = self.entry:GetText()

    local function foo()
        local line = self:GetLine(self.caret.line)
        if not line then return end  

        line = line.text 
        

    end

    foo()

    self.entry:SetText("")

    self:TextChanged()
end

function self:_KeyCodeReleased(code)

end

function self:_KeyCodePressed(code)
    if code == KEY_DOWN then
        self:SetCaret(self.caret.char, self.caret.line + 1)
    elseif code == KEY_UP then
        self:SetCaret(self.caret.char, self.caret.line - 1)
    elseif code == KEY_RIGHT then 
        self:SetCaret(self.caret.char + 1, self.caret.line)
    elseif code == KEY_LEFT then 
        self:SetCaret(self.caret.char - 1, self.caret.line)
    end
end

function self:_FocusLost()
    if self:HasFocus() == true then 
        self.entry:RequestFocus()
    end
end

function self:OnFocusChanged(gained)
    if gained == false then return end
    self.entry:RequestFocus()
end

function self:ProfileSet() end 
function self:SetProfile(profile)
    self.data:SetRulesProfile(profile)
    self:ProfileSet(self.data.profile)
    self:UpdateTabIndicators()
end

function self:ProfileReset() end 
function self:ClearProfile()
    self.data:ResetProfile()
    self:ProfileReset()
end

function self:SetText(text)
    if not text then return end
    self.data:SetContext(text)
    self:TextChanged()
    self:UpdateTabIndicators()
end

function self:FontChanged(newFont, oldFont) end 
function self:SetFont(name, size)
    if not name then return end 

    size = size or 16 
    size = math.Clamp(size, 8, 48)

    local newFont = "SSLEF" .. name  .. size

    if not fontBank[newfont] then
        local data = 
        {
            font      = name,
            size      = size,
            weight    = 500 
        }

        surface.CreateFont(newFont, data)

        fontBank[newFont] = data 
    end 

    surface.SetFont(newFont)

    local w, h = surface.GetTextSize(" ")

    local oldFont = table.Copy(self.font)

    self.font = {
        w = w,
        h = h,
        n = newFont,
        an = name,
        s = size 
    }

    self:FontChanged(self.font, oldFont)
end 

function self:PosInText(...) return self:pit(...) end 
function self:pit(...) -- short for pos in text. Converts local x, y coordinates to a position in the text 
    if #{...} ~= 2 then return end 

    local x, y = select(1, ...), select(2, ...)

    local panelW, panelH = self:GetSize()

    if x == nil then x = 1 else x = math.Clamp(x, 0, panelW) end
    if y == nil then y = 1 else y = math.Clamp(y, 0, panelH) end 

    x = x - (offset * 2 + self:GetLineNumberWidth() - textoffset)
    x = x - self.textPos.char * self.font.w 

    x = math.Round(mSub(x, self.font.w) / self.font.w + self.textPos.char)
    y = math.Round(mSub(y, self.font.h) / self.font.h + self.textPos.line)

    y = math.Clamp(y, 1, #self.data.context)
    x = math.Clamp(x, 0, #(self.data.context[y].text or "") - self.textPos.char + 1)

    y = self.data.context[y].index 

    return x, y
end

function self:UpdateTabIndicators()
    self.allTabs = {}
    
    if not self.data.context then return end

    local function saveTab(cc, tab) self.allTabs[cc] = tab end
    local lastTabs = ""
    local visualTabs = {}
    local m = (self.textPos.line - 1) ~= 0 and -1 or 0
    local c = m
    for i = self.textPos.line + m, self.textPos.line + math.ceil(self:GetTall() / self.font.h) + 1, 1 do 
        local line = self.data.context[i]
        if not line then break end 
        line = line.text 
        if string.gsub(line, "%s", "") == "" then  
            table.insert(visualTabs, c)
        else 
            local _, _, left = string.find(line, "^(%s*)")
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

function self:PosOnPanel(...) return self:pop(...) end 
function self:pop(...) -- short for pos on panel. Converts a position in the text to a position on the panel
    if #{...} ~= 2 then return end 

    local char, line = select(1, ...), select(2, ...)

    local x = char * self.font.w 
    local y = line * self.font.h 

    x = x + offset * 2 + self:GetLineNumberWidth() + textoffset 

    return x, y 
end

function self:KeyForIndex(index)
    for k, v in pairs(self.data.context) do 
        if not v.index then break end 
        if v.index ~= index then continue end 
        return k 
    end 
end

function self:IndexForKey(key)
    return self.data.context[key].index 
end

function self:CaretSet(char, line) end 
function self:SetCaret(...)
    if #{...} ~= 2 then return end 

    local char, line = select(1, ...), select(2, ...)

    local lineDiff = line - self.caret.line 

    local actualLine  = self:KeyForIndex(line)
    print(line .. " " .. (actualLine or "bruh"))
    if not actualLine then 
        if line <= 1 or line > #self.data.context then return end
        if lineDiff < 0 then 
            line = self.data.context[self:KeyForIndex(self.caret.line) - 1]
        else 
            line = self.data.context[self:KeyForIndex(self.caret.line) + 1]
        end
        actualLine = self.data.context[line].index 
        print(line)
    end 

    if not line then return end 

    self.caret.line = line 
    self.caret.char = math.Clamp(char, 0, #self.data.context[actualLine].text) 

    self:CaretSet(char, line)

    return self.caret.line, self.caret.char 
end

function self:OnMouseClick(code) end 
function self:OnMousePressed(code)
    self:OnMouseClick(code)

    if code == MOUSE_LEFT then 
        self:SetCaret(self:pit(self:LocalCursorPos()))
    elseif code == MOUSE_RIGHT then 

    end

    if self.entry:HasFocus() == false then self.entry:RequestFocus() end 
end

function self:GetLineNumberCharCount()
    return #tostring(self.textPos.line + self:VisibleLines() - 1)
end

function self:GetLineNumberWidth()
    return self:GetLineNumberCharCount() * self.font.w 
end

function self:VisibleLines()
    return math.ceil(self:GetTall() / self.font.h)
end

function self:VisibleChars()
    return math.ceil(self:GetWide() / self.font.w)
end

function self:PaintBefore(w, h) end 
function self:PaintAfter(w, h) end 

function self:Paint(w, h)
    self:PaintBefore(w, h)

    local i = self.textPos.line 

    local mx, my = self:LocalCursorPos()

    -- Background 
    draw.RoundedBox(0,0,0,w,h,self.colors.background)

    local i = self.textPos.line 
    local c = 0

    local lineNumCharCount = self:GetLineNumberCharCount()
    local lineNumWidth = self:GetLineNumberWidth()

    local visLines = self:VisibleLines() 
    local visChars = self:VisibleChars()

    local x = offset * 2 + lineNumWidth 

    -- Backgrounds 
    draw.RoundedBox(0, 0, 0, x, h, self.colors.lineNumbersBackground)
    draw.RoundedBox(0, x, 0, 1, h, self.colors.linesEditorDivider)

    local bruh = 1
    while i < self.textPos.line + visLines
    do 
        if bruh > #self.data.context * 2 then print("COCK") break end bruh = bruh + 1 

        local cLine = self.data.context[i]
        if not cLine then break end 

        if cLine.button then 
            cLine.button:SetSize(offset * 0.75, cLine.button:GetWide())
            cLine.button:SetVisible((mx > 0 and mx <= textoffset + x) or #cLine.folding.folds > 0)
            cLine.button:SetPos(x - offset + offset * 0.15, c * self.font.h + (self.font.h / 2 - cLine.button:GetTall() / 2))
        end 

        -- Line Numbers 
        draw.SimpleText(cLine.index, self.font.n, offset + lineNumWidth * ((lineNumCharCount - #tostring(cLine.index)) / lineNumCharCount), c * self.font.h, self.colors.lineNumbers)
        
        local hasError = false 

        -- Tab Indicators
        if self.data.profile.language ~= "Plain" then 

        end 

        -- Syntax Coloring 
        do 
            local lastY = 0

            for tokenIndex, token in pairs(cLine.tokens or {}) do 
                local txt = token.text

                if token.type == "endofline" then
                    draw.SimpleText("⮯", self.font.n, x + lastY, c * self.font.h, self.colors.tabIndicators)
                    break        
                elseif token.type == "error" then 
                    hasError = true 
                end

                if token.ending < self.textPos.char or token.start > self.textPos.char + visChars then 
                    continue
                elseif token.start < self.textPos.char and token.ending >= self.textPos.char then  
                    txt = string.sub(txt, self.textPos.char - token.start + 1, #txt)
                end

                local textY, _ = draw.SimpleText(txt, self.font.n, textoffset + x + lastY, c * self.font.h, (not token.color and self.data.profile.colors[token.type] or self.data.profile.colors[token.color]) or Color(255,255,255))

                lastY = lastY + textY
            end
        end 

        -- Caret 
        if cLine.index == self.caret.line then
            draw.RoundedBox(0, 0, c * self.font.h, self:GetWide(), self.font.h, self.colors.currentLine)

            if self.caret.char + self.textPos.char >= self.textPos.char then 
                draw.RoundedBox(0, textoffset + x + self.font.w * self.caret.char,c * self.font.h, 2, self.font.h, self.colors.caret)
            end 
        end 

        if cLine.folding and cLine.folding.folds and #cLine.folding.folds > 0 then 
            draw.RoundedBox(0, 0, (c + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)
        end

        i = i + 1
        c = c + 1
    
        if i > #self.data.context then break end 
    end

    self.scroller:SetUp(visLines + 1, #self.data.context + visLines / 2)

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
    self:CollectBadButtons()
    self:OnScrolled(diff)
end

function self:OnMouseWheeled(delta)
    if self:IsCtrl() == false then 
        self.scroller:SetScroll(self.scroller:GetScroll() - delta * 2)
    else 
        self:SetFont(self.font.an, self.font.s - delta * 2)
    end
end

function self:Think()
    local scroll = self.scroller:GetScroll() 
    self.textPos.line = math.ceil(scroll + 1)
    self.scroller:SetScroll(scroll)

    if self.textPos.line ~= self.lastTextPos.line then 
        self:_OnScrolled(self.textPos.line - self.lastTextPos.line)
    end

    self.lastTextPos = self.textPos
end

function self:MakeFoldButton()
    local button = vgui.Create("DButton", self)
    button:SetIcon("icon16/disconnect.png")
    button.m_Image:Dock(FILL)
    button:SetText("")
    button:SetVisible(false)
    button.Paint = function() end
    return button 
end

vgui.Register("DSyntaxBox", self, "DPanel")

local function open()
	local window = vgui.Create("DFrame")
	window:SetPos( ScrW() / 2 - 900 , ScrH() / 2 - 1000 / 2 )
	window:SetSize( 900, 1000 )
	window:SetTitle( "Derma SyntaxBox V6" )
	window:SetDraggable( true )
	window:MakePopup()
	window:SetSizable(true)
	window:SetMinWidth(200)
	window:SetMinHeight(100)
    local sb = vgui.Create("DSyntaxBox", window)
    sb:SetProfile(prof)
	sb:Dock(FILL)
    sb:SetFont("Consolas", 26)
sb:SetText([[@name Dont look at me 
@persist Viewers:table 

if( first() )
{
    runOnTick(1)    
}

foreach(I, Ply:entity = players())
{
    local Name = Ply:name()
    
    # Remove Players that have left the server 
    if(!Ply:isValid() & Viewers[Name, number])
    {
        holoDelete(Viewers[Name, number])
        Viewers:removeNumber(Name)   
        continue 
    }
    
    if(Ply:aimEntity() != owner())
    { 
        if(Viewers[Name, number]) # If he was looking at you, remove the holo 
        {
            holoDelete(Viewers[Name, number])
            Viewers:removeNumber(Name)           
        }
        continue 
    } # If hes not looking at you, go next 
    
    if(Viewers[Name, number]){ continue } # If hes already blinded, go next 
    
    holoCreate(I, Ply:shootPos(), vec(-5), ang(), vec(255,0,0))
    holoParentAttachment(I, Ply, "eyes")
    
    Viewers[Name, number] = I # Save the holo id so it can later be removed 
}



]])

 -- PrintTable(sb.data.context)
end

concommand.Add("sopen", function( ply, cmd, args )
    open()
end)

open()
