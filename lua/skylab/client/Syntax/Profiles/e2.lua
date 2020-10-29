--[[
    Expression2 Syntax Profile

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

SSLE.RegisterProfile("Expression 2", function()
    local E2Cache = {}
    return {
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
            operators = {"+","-","/","|","<",">","=","*","?","$","!",":","&","%","~",",", "^"},
            others    = {".", ";"}
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
            ["_"] = 0,
            ["@"] = 0
        },
        closingPairs = 
        {
            scopes            = {"{", "}"},
            parenthesis       = {"(", ")"},
            propertyAccessors = {"[", "]"}
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
                            tot("userfunctions")
                            return true 
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
                                tOther("builtinFunctions")
                                return true 
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
        }
    }
end)