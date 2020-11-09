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
        if not capture.multiline then 
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


function Lexer:ParseText(text, prevTokens)
    if not self.profile then return end 
    if not text then return end
    
    prevTokens = prevTokens or {}

    local result = {}
    local buffer = 0
    local capture = {type = "",group = {}}
    local builder = ""

    local function capture(type, group)
        capture.type  = type 
        capture.group = group 
    end

    local function inCapture()
        return capture.type ~= ""
    end

    local function stopCapture()
        capture.type = ""
    end

    do 
        local lastRealToken = prevTokens[#prevTokens - 1]
        if lastRealToken and lastRealToken.inCapture == true and profile.captures[lastRealToken.type] then 
            capture(lastRealToken.type,  profile.captures[lastRealToken.type])
        end
    end

    local lastToken = {}
    local function addToken(text, type, inCapture)
        if not text then return end 
        if string.gsub(text, "%s", "") == "" and type ~= "endofline" then return end  

        local tokenStart = 1 

        if lastToken.ending then 
            tokenStart = lastToken.ending + 1 
        end

        local token = {
            text   = text,
            type   = type or "error",
            start  = tokenStart,
            ending = tokenStart + #text,
            inCapture = inCapture
        }

        result[#result + 1] = token 

        lastToken = token 

        return token 
    end

    local function addRest(fallback)
        if builder == "" then return end 
        addToken(builder, fallback or "error")
        builder = ""
    end

    local function addToBuilder(text, fallback)
        if not text or text == "\n" or string.gsub(text, "%s", "") == "" then return end 

        if #text > 1 then 
            builder = builder .. text
            return 
        end  

        fallback = fallback or "error"

        for key, chars in pairs(self.profile.reserved) do 
            for _, char in pairs(chars) do 
                if char == text then
                    addRest(fallback)
                    addToken(text, key)
                    return
                end 
            end
        end

        for key, pairs in pairs(self.config.closingPairs) do 
            if str == pairs[1] or str == pairs[2] then 
                addRest(fallbach)
                addToken(text, key)
                return 
            end
        end
        
        builder = builder .. text
    end 

    -- Dont use this 
    local function readSinglePattern(pattern)
        if not pattern then return end 
        
        local a,b,c = string.find(text, pattern, buffer)

        if not a or not b then return end 

        return c or string.sub(text, a, b) 
    end 

    local function readMultiPattern(pattern)
        if not pattern then return end 
        
        local matches = {string.match(text, pattern, buffer)}

        if #matches == 0 then 
            matches[1] = matches[1] or readSinglePattern(pattern)
        end

        return matches
     end

    local function isNextPattern(pattern)
        if not pattern then return end 

        local a,b,c = string.find(text, pattern, buffer)

        if a and b or (c or "") ~= "" then return true end 

        return false 
    end

    local function readNext()
        buffer = buffer + 1
        return text[#buffer] or "\n"
    end

    local char = readNext()
    while buffer < #text then    
        if char == "\n" then 
            if inCapture() == true then 
                
            end
            break 
        end
        
        if inCapture() == false then 
            if function()


                return false 
            end == true then continue end 

            local function handleCapture()

            end
            if handleCapture() == true then continue end 
        
            char = readNext()
            addToBuilder(char)
        else

        end
    end     

    if result[#result].type ~= "endofline" then
        addToken("", "endofline")
    end 

    return result
end

function Lexer:ParseLine(t, pt)
    return self:ParseText(t, pt)
end