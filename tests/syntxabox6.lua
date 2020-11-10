local Lexer = {}
Lexer.__index = Lexer

Lexer.matchesdefault = {
    whitespace = {
        pattern = "%s+"
    }
}

Lexer.colorsdefault = {
    error = Color(255,0,0),
    whitespace = Color(255,255,255)
}

Lexer.indentingdefault = {
    open = {},
    close = {},
    openValidation = function() return true end,
    closeValidation = function() return true end,
    offsets = {}
}

Lexer.configdefault = {
    language = "Plain",

    filetype = ".txt",

    reserved = {},
    unreserved = {},
    closingPairs = {},

    indentation = table.Copy(Lexer.indentingdefault),

    autoPairing = {},

    matches = table.Copy(Lexer.matchesdefault),
    captures = {},

    colors = table.Copy(Lexer.colorsdefault),

    onLineParsed = function() end,
    onLineParseStarted = function() end,
    onMatched = function() end,
    onCaptureStart = function() end,
    onTokenSaved = function() end 
}

function Lexer:SetProfile(profile)
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

    self.profile = profile 
end

function Lexer:ParseRow(text, prevTokens)
    if not self.profile then return end 
    if not text then return end

    self.profile.onLineParseStarted(text)

    text = string.gsub(text, "\n.*", "") -- \n will break this function, so dont allow it

    prevTokens = prevTokens or {}

    local result = {}
    local buffer = 1
    local builder = ""

    local capturization = {type = "",group = {}}

    do 
        local lastRealToken = prevTokens[#prevTokens - 1]
        if lastRealToken and lastRealToken.inCapture == true and self.profile.captures[lastRealToken.type] then 
            capturization.type  = lastRealToken.type 
            capturization.group = self.profile.captures[lastRealToken.type] 
        end
    end

    local function addToken(t, type, inCapture)
        if not t then return end 
 
        local tokenStart = ((result[#result] or {}).ending or 0) + 1  

        table.insert(result, {
            text = t,
            type = type or "error",
            start = tokenStart,
            ending = tokenStart + #t - 1,
            inCapture = inCapture
        })

        local lt = result[#result] 

        self.profile.onTokenSaved(lt, text, lt.type, buffer, result)

        return lt
    end

    local function addRest()
        if builder == "" then return end 
        addToken(builder, "error")
        builder = ""
    end

    local function extendLastToken(type, text)
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
            if v[text] then 
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

    -- Dont use this 
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

                    local val = v.validation(text, buffer, match, #result, result) or false 

                    if type(val) == "string" then 
                        k = val
                        val = true 
                    end 

                    if val == true then
                        if #result == 1 and match[1] == text[1] then result[1] = nil end

                        addToken(match, k)

                        buffer = buffer + #match 
                        builder = ""

                        self.profile.onMatched(match, text, k, buffer, result)

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

                    local val = v.begin.validation(text, buffer, match, #result, result)

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

                        self.profile.onCaptureStart(match, text, k, buffer, result)
                        return true 
                    end
                end

                return false 
            end)() == true 
            then 
                continue 
            end 

            addToBuilder(readNext())
        else
            local t = capturization.type 
            local g = capturization.group 

            local match = readPattern(g.close.pattern)

            if match then 
                local val = g.close.validation(text, buffer, match, #result, result)

                if val == true then 
                    buffer = buffer + #match 
                    builder = builder .. string.sub(match, 2, #match) 

                    addToken(builder, t)

                    builder = ""

                    capturization.type = "" 

                    self.profile.onCaptureEnd(match, text, t, buffer, result)

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

function Lexer:ParseText(t)
    t = t or ""
    
    local result = {}

    for k, v in pairs(string.Split(t, "\n")) do 
        if not v then break end 
        table.insert(result, self:ParseRow(v, result[#result]))
    end

    return result 
end

function Lexer:ParseLine(t, pt)
    return self:ParseRow(t, pt)
end

do 
    --[[
        Lua Syntax Profile

        Author: Sixmax
        Contact: sixmax@gmx.de

        Copyright, all rights reserved

        License: CC BY-NC-ND 3.0
        Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
    ]]

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
    
    Lexer:SetProfile({
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
            operators = 
            {
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
                [","]=1, 
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
            open = {"{", "%(", "%["},
            close = {"}", "%)", "%]"},
            offsets = {
                ["#ifdef"] = false, 
                ["#else"] = false,    
                ["#endif"] = false 
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
            scopes = 
            {
                ["{"]=1, 
                ["}"]=1
            },
            parenthesis = 
            {
                ["("]=1, 
                [")"]=1
            },
            propertyAccessors = 
            {
                ["["]=1, 
                ["]"]=1
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
                },
                multiline = true
            },
            comments = 
            {
                begin = {
                    pattern = '#%[%+%+'
                },
                close = {
                    pattern = '%+%+%]#'
                }
            }
        },
        colors =
        {

        },
        onLineParseStarted = function(i)
        end,

        onLineParsed = function(result, i)  
        end,

        onMatched = function(result, i, type, buffer, prevTokens) 
        end,

        onCaptureStart = function(result, i, type, buffer, prevTokens) 
        end,

        onCaptureEnd = function(result, i, type, buffer, prevTokens) 
        end,
        
        onTokenSaved = function(result, i, type, buffer, prevTokens) 
        end
    })
end 

local r = Lexer:ParseText([[#[++addToken
bb 
cc 
dd++]#
#[++++++]#
"aa
bb
cc"]], {})

PrintTable(r)