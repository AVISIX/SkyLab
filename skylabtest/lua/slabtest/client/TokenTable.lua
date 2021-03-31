include("slabtest/client/utils.lua")

local TokenTable = {}
TokenTable.__index = TokenTable

TokenTable.undo = {}
TokenTable.redo = {}

TokenTable.context = {}

TokenTable.matchesdefault = {whitespace = {pattern = "%s+"}, default = {}}

TokenTable.colorsdefault = {
    error = Color(255,0,0),
    default = Color(255,255,255),
    whitespace = Color(255,255,255)
}

TokenTable.indentingdefault = {
    open = {},
    close = {},
    openValidation = function() return true end,
    closeValidation = function() return true end,
    offsets = {}
}

TokenTable.configdefault = {
    language = "Plain",

    filetype = ".txt",

    reserved = {},
    unreserved = {},
    closingPairs = {},
    folding = {
        open = {},
        close = {}
    },
    indentation = table.Copy(TokenTable.indentingdefault),

    autoPairing = {},

    matches = table.Copy(TokenTable.matchesdefault),
    captures = {},

    colors = table.Copy(TokenTable.colorsdefault),

    onLineParsed = function() end,
    onLineParseStarted = function() end,
    onMatched = function() end,
    onCaptureStart = function() end,
    onTokenSaved = function() end 
}

function TokenTable:LineConstructed() end 
function TokenTable:LineConstructionStarted() end 

function TokenTable:FoldingAvailbilityCheckStarted() end 
function TokenTable:FoldingAvailbilityCheckCompleted() end 
function TokenTable:FoldingAvailbilityFound(a, b) end 

function TokenTable:LineFolded() end 
function TokenTable:LineUnfolded() end 

function TokenTable:SetRulesProfile(profile)
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

function TokenTable:ResetProfile()
    self:SetRulesProfile(table.Copy(self.configdefault))
end

function TokenTable:ParseRow(index, text, prevTokens, extendExistingTokens)
    if not self.profile then return {} end 
    if not text then return {} end  

    if extendExistingTokens == nil then extendExistingTokens = false end 

    self.profile.onLineParseStarted(index, text)

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

    local default = (self.profile.language ~= "Plain" and "error" or "default")

    -- Save a token to the current token context
    local function addToken(t, typ, inCapture, color)
        if not t then return end 

        if inCapture ~= nil and type(inCapture) == "string" then 
            color = inCapture  
            inCapture = nil 
        end

        local tokenStart = ((result[#result] or {}).ending or 0) + 1  

        table.insert(result, {
            text = t,
            type = typ or default,
            start = tokenStart,
            ending = tokenStart + #t - 1,
            inCapture = inCapture,
            color = color
        })

        local lt = result[#result] 

        lt.index = #result 

        self.profile.onTokenSaved(lt, index, lt.type, buffer, result)

        return lt
    end

    -- Add the leftovers as error to the token context
    local function addRest()
        if builder == "" then return end 
        addToken(builder, default)
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

                    local val = v.validation(text, buffer, match, #result, result, index) or false 

                    if type(val) == "string" then 
                        k   = val
                        val = true 
                    end 

                    if val == true then
                        addRest()
                        addToken(match, k, (self.profile.matches[k] or {}).color or nil)

                        buffer = buffer + #match 

                        self.profile.onMatched(match, index, k, buffer, result)

                        return true 
                    end 
                end
                return false 
            end)() == true  or
            (function() -- Handle Captures 
                for k, v in pairs(self.profile.captures) do 
                    local match = readPattern(v.begin.pattern)

                    if not match then continue end 

                    local val = v.begin.validation(text, buffer, match, #result, result, index)

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

                        self.profile.onCaptureStart(match, index, k, buffer, result)

                        return true 
                    end
                end
                return false 
            end)() == true then continue end 
        else   
            local t, g = capturization.type, capturization.group 
            local match = readPattern(g.close.pattern)

            if match then 
                local val = g.close.validation(text, buffer, match, #result, result, index)

                if val == true then 
                    buffer = buffer + #match 
                    builder = builder .. match 

                    addToken(builder, t, (self.profile.captures[t] or {}).color or nil)

                    builder = ""

                    capturization.type = "" 
                    
                    self.profile.onCaptureEnd(match, index, t, buffer, result)
                    
                    continue 
                end 
            end
        end    

        evaluateChar(text[buffer])

        buffer = buffer + 1

    until buffer > #text 

    if capturization.type ~= "" then 
        addToken(builder, capturization.type, capturization.group.multiline, (self.profile.captures[capturization.type] or {}).color or nil)
    else 
        addRest()  
    end

    if ((result[#result] or {}).type or "") ~= "endofline" then
        addToken("", "endofline")
    end 

    self.profile.onLineParsed(result, index, text)

    return result
end

local IDCounter = 1
function TokenTable:NewLine(index, text, lastTokens)
    if index == nil or text == nil then return end 

    lastTokens = lastTokens or {}

    local temp = {}

    temp.id = IDCounter -- We need an ID so we have something to distinguish lines and find specific ones 
    temp.index = index 
    temp.tokens = self:ParseRow(index, text, lastTokens)
    
    function temp:GetText()
        local temp = ""
        for k, v in ipairs(self.tokens) do
            if not v then continue end  
            temp = temp .. v.text 
        end
        return temp 
    end

    IDCounter = IDCounter + 1

    return temp 
end

function TokenTable:ParseAll()
    local last 
    for k, v in ipairs(self.context) do 
        if not v then continue end 
        self.context[k].tokens = self:ParseRow(v.index, v:GetText(), last or {})
        last = v 
    end
end

function TokenTable:SetText(text)
    if not text then return end 
    
    self:ResetText()

    local lines = string.Split(text, "\n")
    
    local last
    for k, v in ipairs(lines) do 
        local line = self:NewLine(k, v, last)
        self.context[k] = line 
        last = line.tokens 
    end

    self:GlobalFoldingCheck()

    return self.context 
end

function TokenTable:SmartFolding(startLine) -- Uses Whitespace differences to detect folding
    if not self.context[startLine] then return end 

    if string.gsub(self.context[startLine].text, "%s", "") == "" then return end 

    local startLeft = getLeftLen(self.context[startLine].text)               
    local nextLeft  = getLeftLen((self.context[startLine + 1] or {}).text)     

    local function peekNextFilledLine(start, minLen)
        start = start + 1

        while self.context[start] and (string.gsub((self.context[start] or {}).text or "", "%s", "") == "") do  
            if minLen and getLeftLen(self.context[start].text) < minLen then break end 
            start = start + 1
        end

        return self.context[start], start
    end

    if nextLeft <= startLeft then -- If its smaller, then check if its a whitespace line, if yes, skip all of them until the first filled comes up, then check again.
        local nextFilled, lookup = peekNextFilledLine(startLine, nextLeft)

        if not nextFilled or lookup - 1 == startLine then return end 

        startLine = lookup
        nextLeft = getLeftLen(nextFilled.text)     
    
        if nextLeft <= startLeft then return end 
    end 

    startLine = startLine + 2 

    -- uwu so many while luwps howpfuwwy it doewsnt fwuck up x3 (may god have mercy with my soul)

    while true do
        if not self.context[startLine] then return startLine - 2 end 
        
        local currentLeft = getLeftLen(self.context[startLine].text) 

        if currentLeft < nextLeft then 
            local nextReal = peekNextFilledLine(startLine - 1)

            if not nextReal or (nextReal.text ~= "" and getLeftLen(nextReal.text) < nextLeft) then 
                return startLine - 2
            end  
        end

        startLine = startLine + 1
    end

    return startLine
end

function TokenTable:ValidateFoldingAvailability(i, trigger)
    if not self.context[i] then return false end 

    if trigger == nil then trigger = true end 
    
    local endline = self:SmartFolding(i)  

    if self.context[i].folding then -- If already has been detected as a foldable line, check if its REALLY foldable. if yes, check if the new foldable data is same or not 

        local function wipe()
            self:UnfoldLine(i)

            if self.context[i].button then 
                self.context[i].button:Remove()
            end 

            self.context[i].folding = nil    
        end

        if #self.context[i].folding.folds > 0 then 
            if endline and endline ~= i and (endline - i + 1) > 0 then 
                wipe() -- when folded the available folds should be 0, if they arent 0 then something has changed that could affect the folding.
            end 
            return false 
        end 

        if not endline then 
            wipe()
            return false 
        end 

        local avFolds = endline - i + 1 

        if avFolds <= 0 then 
            wipe()
            return false 
        elseif avFolds ~= self.context[i].folding.available then 
            self:UnfoldLine(i)
            self.context[i].folding.available = avFolds
            return false 
        end

        return true  
    end
    
    if endline then -- It has not yet been detected as foldable but is foldable, make it one!
        local avFolds = endline - i + 1 

        self.context[i].folding = {
            available = avFolds,
            folds = {}
        }

        if trigger == true then 
            self:FoldingAvailbilityFound(i, avFolds)
        end 

        return true 
    end 

    return false  
end

function TokenTable:GlobalFoldingCheck()
    self:FoldingAvailbilityCheckStarted()
    for lineIndex, contextLine in ipairs(self.context) do 
        self:ValidateFoldingAvailability(lineIndex)
    end
    self:FoldingAvailbilityCheckCompleted()
end 

function TokenTable:ResetText()
    self.context = {}
end

return TokenTable