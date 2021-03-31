include("slabtest/client/utils.lua")

local keywords = {
    ["break"]       = 1,
    ["do"]     = 1,
    ["else"]   = 1,
    ["elseif"]    = 1,
    ["end"]      = 1,
    ["for"] = 1,
    ["function"]   = 1,
    ["if"]    = 1,
    ["in"] = 1,
    ["local"] = 1,
    ["repeat"] = 1,
    ["return"] = 1,
    ["then"] = 1,
    ["until"] = 1,
    ["while"] = 1,
}    

local lg = {
    ["_G"] = 1,
    ["_VERSION"] = 1
}

local metamethods = {
    ["__add"] = 1,
    ["__sub"] = 1,
    ["__mod"] = 1,
    ["__unm"] = 1,
    ["__concat"] = 1,
    ["__lt"] = 1,
    ["__index"] = 1,
    ["__call"] = 1,
    ["__gc"] = 1,
    ["__mul"] = 1,
    ["__div"] = 1,
    ["__pow"] = 1,
    ["__len"] = 1,
    ["__eq"] = 1,
    ["__le"] = 1,
    ["__newindex"] = 1,
    ["__tostring"] = 1,
    ["__mode"] = 1,
    ["__tonumber"] = 1
}

local builtinlibs = {
    ["string"] = 1,
    ["table"] = 1,
    ["coroutine"] = 1,
    ["os"] = 1,
    ["io"] = 1,
    ["math"] = 1,
    ["debug"] = 1
}

local stdfuncs = {

    ["coroutine"] = {
      ["yield"] = 1,
      ["resume"] = 1,
      ["running"] = 1,
      ["status"] = 1,
      ["wait"] = 1,
      ["wrap"] = 1,
      ["create"] = 1
    },
    ["math"] = {
        ["sqrt"] = 1,
        ["min"] = 1,
        ["abs"] = 1,
        ["acos"] = 1,
        ["asin"] = 1,
        ["atan"] = 1,
        ["atan2"] = 1,
        ["ceil"] = 1,
        ["cos"] = 1,
        ["cosh"] = 1,
        ["deg"] = 1,
        ["exp"] = 1,
        ["floor"] = 1,
        ["frmod"] = 1,
        ["frexp"] = 1,
        ["IntToBin"] = 1,
        ["Idexp"] = 1,
        ["log"] = 1,
        ["log10"] = 1,
        ["max"] = 1,
        ["min"] = 1,
        ["mod"] = 1,
        ["modf"] = 1,
        ["pow"] = 1,
        ["rad"] = 1,
        [ "Rand"] = 1,
      ["random"] = 1,
      ["randomseed"] = 1,
      ["sin"] = 1,
      ["sinh"] = 1,
      ["sqrt"] = 1,
      ["tan"] = 1,
      ["huge"] = 1,
      ["pi"] = 1,
    },
    ["string"] = {
      ["byte"] = 1,
      ["char"] = 1,
      ["dump"] = 1,
      ["find"] = 1,
      ["gfind"] = 1,
      ["format"] = 1,
      ["gsub"] = 1,
      ["sub"] = 1,
      ["len"] = 1,
      ["lower"] = 1,
      ["match"] = 1,
      ["gmatch"] = 1,
      ["rep"] = 1,
      ["reverse"] = 1,
      ["upper"] = 1,
    },
    ["debug"] = {
        ["debug"] = 1,
        ["getfenv"] = 1,
        ["gethook"] = 1,
        ["getinfo"] = 1,
        ["getlocal"] = 1,
        ["getmetatable"] = 1,
        ["getregistry"] = 1,
        ["getupvalue"] = 1,
        ["setfenv"] = 1,
        ["sethook"] = 1,
        ["setlocal"] = 1,
        ["setmetatable"] = 1,
        ["setupvalue"] = 1,
        ["traceback"] = 1,
        ["upvalueid"] = 1,
        ["upvaluejoin"] = 1,
    },
    ["os"] = {
        ["clock"] = 1,
        ["date"] = 1,
        ["difftime"] = 1,
        ["exit"] = 1,
        ["setlocale"] = 1,
        ["time"] = 1,
    },
    ["table"] = {
        ["concat"] = 1,
        ["insert"] = 1,
        ["move"] = 1,
        ["pack"] = 1,
        ["remove"] = 1,
        ["sort"] = 1,
        ["unpack"] = 1,
    },
    ["utf8"] = {
        ["char"] = 1,
        ["charpattern"] = 1,
        ["codepoint"] = 1,
        ["codes"] = 1,
        ["len"] = 1,
        ["offset"] = 1,
    },
}

local builtinfuncs = {
    ["getfenv"] = 1,
    ["getmetatable"] = 1,
    ["ipairs"] = 1,
    ["load"] = 1,
    ["loadfile"] = 1,
    ["loadstring"] = 1,
    ["next"] = 1,
    ["pairs"] = 1,
    ["print"] = 1,
    ["rawequal"] = 1,
    ["rawget"] = 1,
    ["rawset"] = 1,
    ["select"] = 1,
    ["setfenv"] = 1,
    ["setmetatable"] = 1,
    ["tonumber"] = 1,
    ["tostring"] = 1,
    ["type"] = 1,
    ["unpack"] = 1
}

local E2Cache = {}

return {
    language = "Lua",
    filetype = "lua",
    reserved = {
        operators = {"+","-","*","/","%","^","=","~","<",">"},
        dot = {"."},
        hash = {"#"},
        props = {":"},
        others = {","}
    },
    unreserved = 
    {
        ["_"] = 0
    },
    indentation = {
        open = {
            "function",
            "if",
            "do",
            "repeat",
            "elseif",
            "else",
            "{"
        },
        close = {
            "end",
            "until",
            "elseif",
            "else",
            "}"
        },
        openValidation = function(result, charIndex, lineIndex, line) 
            local prevChar = line[charIndex - 1] or ""
            local nextChar = line[charIndex + #result] or ""
            if isSpecial(prevChar) == true and isSpecial(nextChar) == true then return true end 
            return false  
        end, 
        
        closeValidation = function(result, charIndex, lineIndex, line) 
            local prevChar = line[charIndex - 1] or ""
            local nextChar = line[charIndex + #result] or "" 
            if isSpecial(prevChar) == true and isSpecial(nextChar) == true then return true end 
            return false  
        end,

        offsets = { -- -8
            ["then"] = -1, 
            --["else"] = -1,
            ["elseif"] = -1
        }
    },
    closingPairs = 
    {
        scopes     = {open = "{", close = "}"},
        parenthesis      = {open = "(", close = ")"},
        brackets    = {open = "[", close = "]"}
    },
    autoPairing =
    {
        {
            word = "{",
            pair = "}",
            validation = function(line, charIndex, lineIndex) 
                return line[charIndex + 1] ~= "}" 
            end     
        },
        {
            word = "(",
            pair = ")",
            validation = function(line, charIndex, lineIndex) 
                return true --line[charIndex + 1] ~= ")"  
            end 
        },
        {
            word = "[",
            pair = "]",
            validation = function(line, charIndex, lineIndex) 
                return true --line[charIndex + 1] ~= "]"  
            end 
        },
        {
            word = '"',
            pair = '"',
            validation = function(line, charIndex, lineIndex)  
                local pchar = (line[charIndex - 1] or "")
                local nchar = (line[charIndex + 1] or "")
                if pchar == "'" and nchar == "'" then return false end 
                return pchar ~= '"' 
            end 
        },
        {
            word = "'",
            pair = "'",
            validation = function(line, charIndex, lineIndex)  
                local pchar = (line[charIndex - 1] or "")
                local nchar = (line[charIndex + 1] or "")
                if pchar == '"' and nchar == '"' then return false end 
                return pchar ~= '"' 
            end 
        },
        {
            word = "repeat",
            pair = " until",
            validation = function(line, charIndex, lineIndex) 
                return isSpecial(line[charIndex - #"repeat"] or "") and string.sub(line, charIndex + 1, charIndex + #"until") ~= "until"
            end 
        },
        {
            word = "do",
            pair = " end",
            validation = function(line, charIndex, lineIndex) 
                return isSpecial(line[charIndex - 2] or "") and string.sub(line, charIndex + 1, charIndex + #"end") ~= "end"
            end 
        },
        {
            word = "if",
            pair = " then",
            validation = function(line, charIndex, lineIndex) 
                return isSpecial(line[charIndex - 2] or "") and string.sub(line, charIndex + 1, charIndex + #"then") ~= "then"
            end 
        },
        {
            word = "elseif",
            pair = " then",
            validation = function(line, charIndex, lineIndex) 
                return isSpecial(line[charIndex - #"elseif"] or "") and string.sub(line, charIndex + 1, charIndex + #"then") ~= "then"
            end 
        },
        {
            word = "function",
            pair = " end",
            validation = function(line, charIndex, lineIndex) 
                return isSpecial(line[charIndex - #"function"] or "") and string.sub(line, charIndex + 1, charIndex + #"end") ~= "end"
            end 
        },
    }, 

    colors = {
        scopes            = Color(200,100,0),
        brackets          = Color(200,100,0),
        parenthesis       = Color(200,100,0),

        hash              = Color(186,37,153), -- #

        operators        = Color(255,255, 0), -- Arithmetic characters +-/*%
        strings           = Color(150,150,150), -- Double string ""

        comments = Color(128,128,128), -- Multiline Comments --[[]]

        keywords          = Color(138, 210, 252), -- Keywords 

        constants         = Color(186,37,153),

        builtinlibs       = Color(110,110,110), -- All standard lua libraries
        stdfuncs          = Color(110,110,110), -- All standard lua functions that ARE part of a library
        builtinfuncs      = Color(110,110,110), -- All standard lua functions that arent part of a library

        func              = Color(126, 191, 145), -- function <myFunc>()
        funcself          = Color(242, 195, 164),  -- self 
        funcparam         = Color(105,120,160), -- function <a.b.c.d.e>:myFunc()

        numbers          = Color(193, 143, 115), -- Numbers

        customfuncs       = Color(90, 158, 110), -- Functions that arent standard in Lua 
        customlibs        = Color(190,190,190), -- Libraries that arent standard in Lua
        variables         = Color(230,230,230), -- Any other word
        varprops          = Color(132,165,110), -- myTable.<some property>

        metamethods       = Color(180,250,125),
        garbagecollector  = Color(165, 125, 250),

        error             = Color(241,96,96) -- Anything unhandled
    },

    matches = {
        numbers = 
        {
            pattern = "[0-9][0-9.e]*",
            validation = function(line, buffer, result, tokenIndex) 
                local function nextChar(char)
                    return line[buffer + #result] == char  
                end
                if nextChar("x") or nextChar("b") then return false end 
                return true 
            end
        },
        lineComment = 
        {
            pattern = "%-%-[^\n]*",
            validation = function(line, buffer, result, tokenIndex, tokens, lineIndex) 
                local nextChar = line[buffer + 2] or ""
                local nextChar2 = line[buffer + 3] or ""
                return nextChar ~= "[" and nextChar2 ~= "["
            end,
            color = "comments"
        },
        doubleDot = 
        {
            pattern = "%.%.",
            color = "wordops"
        },
        tripleDot = 
        {
            pattern = "%.%.%.",
            color = "keywords"
        },
        hexadecimals = 
        {
            pattern = "0[xb][0-9A-F]+",
            color = "numbers"
        },
        
        variables = {
            pattern = "[a-zA-Z_][a-zA-Z0-9_]*",
            validation = function(line, buffer, result, tokenIndex, tokens, lineIndex) 
                local prevChar = line[buffer - 1] or ""
                local nextChar = line[buffer + #result] or ""

                if isSpecial(prevChar) == false or isSpecial(nextChar) == false then return false end 

                local r        = string.sub(line, buffer + #result, #line) or ""
                local l        = string.sub(line, 1, buffer - 1) or ""
                local right    = string.gsub(r, "%s*", "") or ""
                local left     = string.gsub(l, "%s*", "") or ""   

                -- Booleans detection
                if result == "false" or result == "true" then 
                    return "bools"  
                end

                -- Constants detection
                if result == "_G" or result == "_VERSION" then 
                    return "globals"
                end

                -- nil detection
                if result == "nil" then 
                    return "null" 
                end

                -- Character operator detection
                if result == "and" or result == "or" or result == "not" then 
                    return "wordops"
                end

                -- Keywords detection
                if keywords[result] then 
                    return "keywords" 
                end

                -- self detection 
                if result == "self" then 
                    return "funcself" 
                end

                if result == "collectgarbage" and right[1] == "(" then 
                    return "garbagecollector"  
                end

                -- STD-Lib detection
                if nextChar == "." or prevChar == "=" then 
                    if builtinlibs[result] then 
                        return "builtinlibs"
                    end
                end

                if metamethods[result] then 
                    return "metamethods" 
                end

                -- Function names and Function parameters
                do 
                    local isParam = false 
                    local tkI = tokenIndex
                    local token = tokens[tokenIndex]
                    if token then 
                        while token and token.type ~= "keywords" and tkI > 1 and token.text ~= ")" do 
                            if token.text == "(" then 
                                isParam = true 
                            end
                            tkI = tkI - 1
                            token = tokens[tkI]
                        end
                        if token and token.text == "function" then 
                            if isParam == true then 
                                return "funcparam" 
                            end
                            return "func" 
                        end 
                    end
                end


                -- STD-Funcs from STD-Libs detection
                if prevChar == "." then 
                    local prevToken = tokens[tokenIndex - 1] or {}
                    if prevToken.type == "builtinlibs" and (stdfuncs[prevToken.text] or {})[result] then 
                        return "stdfuncs" 
                    else 
                        return "varprops" 
                    end
                end

                -- STD-Funcs without Lib
                if builtinfuncs[result] and ((right[1] == "(" or right[1] == '"') or left[#left] == "=") then 
                    return "builtinfuncs" 
                end

                if right[1] == "(" then
                    return "customfuncs" 
                end

                return true 
            end
        },
        metamethods = {},
        funcself = {},
        null = {color = "constants"},
        bools = {color = "constants"},
        constants = {},
        globals = {color = "constants"},
        keywords = {},
        wordops = {color = "operators"},
        builtinlibs = {},
        builtinfuncs = {},
        stdfuncs = {},
        func = {},
        funcparam = {},
        customlibs = {},
        varprops = {},
        customfuncs = {},
        garbagecollector = {}
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
            multiline = false 
        },
        strings2 = 
        {
            begin = {
                pattern = "'"
            },
            close = {
                pattern = "'",
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
            multiline = false,
            color = "strings"
        },
        multilinesStrings = 
        {
            begin = {
                pattern = '%[%[',
                validation = function(line, buffer, result, tokenIndex, tokens) 
                    local prevChar = line[buffer - 1] or ""
                    local prevChar2 = line[buffer - 2] or ""
                    if prevChar ~= "-" and prevChar2 ~= "-" then return true end 
                    return false 
                end
            },
            close = {
                pattern = '%]%]',
            },
            color = "strings"
        },
        comments = 
        {
            begin = {
                pattern = '%-%-%[%['
            },
            close = {
                pattern = '%]%]'
            }
        },
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
}

