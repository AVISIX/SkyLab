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

    local function addToBuilder(text)
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

        addToken(text, "error")
    end 

    local function readPattern(pattern)
        if not pattern then return nil end 
        local a,b,c = string.find(text, pattern, buffer)
        if not a or not b or a ~= buffer then return nil end 
        return c or string.sub(text, a, b)
    end 

    local function readNext()
        buffer = buffer + 1
        return text[buffer] or ""
    end

    local char = ""
    addToBuilder(text[1])

    while buffer < #text do  
        if capturization.type == "" then 
            if (function() -- Handle Matches (Inside function cause of 'return' being convenient )
                for k, v in pairs(self.profile.matches) do 
                    local match = readPattern(v.pattern)
                    
                    if not match then continue end

                    local val = v.validation(text, buffer, match, #result, result, lineNumber) or false 

                    if type(val) == "string" then 
                        k = val
                        val = true 
                    end 

                    if val == true then
                        if #result == 1 and match[1] == text[1] then result[1] = nil end

                        addToken(match, k)

                        buffer = buffer + #match 
                        builder = ""

                        self.profile.onMatched(match, lineNumber, k, buffer, result)

                        return true 
                    end 
                end

                return false 
            end)() == true then 
                addToBuilder(text[buffer] or "")
                continue 
            end 

            if (function() -- Handle Captures 
                for k, v in pairs(self.profile.captures) do 
                    local match = readPattern(v.begin.pattern)

                    if not match then continue end 

                    local val = v.begin.validation(text, buffer, match, #result, result, lineNumber)

                    if type(val) == "string" then 
                        k = val
                        val = true 
                    end 

                    if val == true then  
                        local ml = #match 

                        builder = match .. text[buffer + ml]
                        buffer = buffer + ml 

                        capturization.type  = k 
                        capturization.group = v 

                        self.profile.onCaptureStart(match, lineNumber, k, buffer, result)
                        return true 
                    end
                end

                return false 
            end)() == true 
            then continue end 

            addToBuilder(readNext())
        else
            local t, g = capturization.type, capturization.group 

            local match = readPattern(g.close.pattern)

            if match then 
                local val = g.close.validation(text, buffer, match, #result, result, lineNumber)

                if val == true then 
                    buffer = buffer + #match 
                    builder = builder .. string.sub(match, 2, #match) 

                    addToken(builder, t)

                    builder = ""

                    capturization.type = "" 

                    self.profile.onCaptureEnd(match, lineNumber, t, buffer, result)

                    continue 
                end 
            end

            addToBuilder(readNext())
        end
    end     

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

--[[
    Available Rules:
        - noCarriage -> Will replace every carriage return with "    "
]]

function DataContext:CountIndentation(tokens, tokenCallback)
    if not tokens or #tokens == 0 then return end 

    tokenCallback = tokenCallback or function() end 

    local level = 0

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
                temp.offset = offsets 
            end
        end 
    end

    return level  
end

function DataContext:GetInitialFoldingAvailability()
    local openers = self.profile.folding.open 
    local closers = self.profile.folding.close 

    if not openers or not closers then return end 

    local function findMatchDown(tokenIndex, lineIndex)
        if not self.context[lineIndex] then return end 
        if not self.context[lineIndex].tokens then return end 
        if not self.context[lineIndex].tokens[tokenIndex] then return end 

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

    for lineIndex, contextLine in pairs(self.context) do 
        if contextLine.folding then continue end -- Skip the ones that have already been parsed 

        for tokenIndex, token in pairs(contextLine.tokens or {}) do 
            if not token then break end 

            if openers[token.text] then
                local match, ti, li = findMatchDown(tokenIndex, lineIndex)

                if not match then continue end 

                local diff = li - lineIndex - 1

                if li ~= lineIndex and diff ~= 0 then 
                    self.context[lineIndex].folding = 
                    {
                        folded = false, 
                        availableFolds = diff,
                        lastFold = lineIndex + diff 
                    }
                end
            end
        end
    end 
end

function DataContext:ConstructContextLine(i)
    if not i then return {} end 

    self.defaultLines[i] = string.gsub(self.defaultLines[i], "\r", "    ")

    local lastContextLine = self.context[i - 1] or {}

    local temp = {}

    temp.index  = i 
    temp.text   = self.defaultLines[i] 
    temp.tokens = self:ParseRow(i, (lastContextLine.tokens or {}))
    temp.offset = 0 

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

    local countedLevel = self:CountIndentation(temp.tokens)

    temp.nextLineIndentationOffsetModifier = countedLevel + (lastContextLine.nextLineIndentationOffsetModifier or 0)
    temp.level = math.max((lastContextLine.nextLineIndentationOffsetModifier or 0) + math.min(countedLevel, 0), 0)

    return temp 
end

function DataContext:SetContext(text, rules)
    if not text then return end 

    rules = rules or ""

    if type(text) == "table" then 
        self.defaultLines = text 
    elseif type(text) == "string" then     
        self.defaultLines = string.Split(text, "\n")
    else return end 

    self.context = {}

    local level = 0

    for i, line in pairs(self.defaultLines) do 
        if not line then break end 
        table.insert(self.context, self:ConstructContextLine(i))
    end

    self:GetInitialFoldingAvailability()

    return self.context 
end

function DataContext:InsertLine(text, i)
    i = i or #self.defaultLines
    i = math.Clamp(i, 1, #self.defaultLines)
    table.insert(self.lines, text, i)
    table.insert(self.context, self:ConstructContextLine(i), i)
end

function DataContext:RemoveLine(i)
    i = i or #self.defaultLines
    i = math.Clamp(i, 1, #self.defaultLines)
    table.remove(self.lines, i)
    table.remove(self.context, i)
end

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
    
    DataContext:SetRulesProfile({
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
        }})
end 

local r = DataContext:SetContext([[for(I=1,12){
    {
        xd 
        {{{{
            a 
        }}}}
    }}
}
    ]])

PrintTable(r)

--[[
local test 

do 
    local myTab = {a = "yourMom", b = "fat"} 
    test = myTab 
    test.b = nil 

    PrintTable(myTab)
end ]] 
