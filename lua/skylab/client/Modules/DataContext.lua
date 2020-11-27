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

        - Add a Queue for Parsing lines 
]]

function DataContext:LineConstructed() end 
function DataContext:LineConstructionStarted() end 

function DataContext:FoldingAvailbilityCheckStarted() end 
function DataContext:FoldingAvailbilityCheckCompleted() end 

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

    repeat 
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
                    builder = builder .. string.sub(match, 2, #match) -- To Do: Get rid of this sub() for better performance 

                    addToken(builder, t)

                    builder = ""

                    capturization.type = "" 

                    self.profile.onCaptureEnd(match, lineNumber, t, buffer, result)

                    continue 
                end 
            end

            addToBuilder(readNext())
        end
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

--[[
    Available Rules:
        - noCarriage -> Will replace every carriage return with "    "
]]

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

        for tokenIndex, token in pairs(contextLine.tokens) do 
            if not token then break end 

            if openers[token.text] then
                local match, ti, li = self:FindMatchDown(tokenIndex, lineIndex)

                if not match then continue end 

                local diff = li - lineIndex - 1

                if li ~= lineIndex and diff ~= 0 then 
                    self.context[lineIndex].folding = 
                    {
                        folded = false, 
                        availableFolds = diff
                    }
                    
                    self.context[li].folding = 
                    {
                        folded = false, 
                        availableFolds = -diff
                    }
                end
            end
        end
    end

    self:FoldingAvailbilityCheckCompleted()
end

function DataContext:FoldLine(i)
    if i == nil then return end 
    if i < 1 or i > #self.context then return end 
    if not self.context[i].folding then return end

    self.context[i].folding.folded = true 

    local c = self.context[i].folding 

    local match = i + c.availableFolds + (c.availableFolds > 0 and 1 or -1)
    self.context[match].folding.folded = true 

    self:LineFolded(i)
    self:LineFolded(match)
end

function DataContext:UnfoldLine(i)
    if i == nil then return end 
    if i < 1 or i > #self.context then return end 
    if not self.context[i].folding then return end

    self.context[i].folding.folded = false 

    local c = self.context[i].folding 

    local match = i + c.availableFolds + (c.availableFolds > 0 and 1 or -1)
    self.context[match].folding.folded = true 

    self:LineUnfolded(i)
    self:LineUnfolded(match)
end

function DataContext:ConstructContextLine(i)
    if not i then return {} end 

    self:LineConstructionStarted(i)

    self.defaultLines[i] = string.gsub(self.defaultLines[i], "\r", "    ") -- Fuck this shit i legit cannot be asked...

    local lastContextLine = self.context[i - 1] or {}

    local temp = {}

    temp.index  = i 
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

    self:GetGlobalFoldingAvailability()

    return self.context 
end

function DataContext:InsertLine(text, i)
    i = i or #self.defaultLines
    i = math.Clamp(i, 1, #self.defaultLines)

    table.insert(self.defaultLines, text, i)
    table.insert(self.context, self:ConstructContextLine(i), i)

    self:GetGlobalFoldingAvailability()
end

function DataContext:RemoveLine(i)
    i = i or #self.defaultLines
    i = math.Clamp(i, 1, #self.defaultLines)

    table.remove(self.defaultLines, i)
    table.remove(self.context, i)

    self:GetGlobalFoldingAvailability()
end
