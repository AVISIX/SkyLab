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
local function lastRecursiveEntry(collection)
    if not collection then return {}, 0 end 

    local skips = #collection 
    local result = collection[#collection]

    while result.folding and #result.folding.folds > 0 do
        local len = #result.folding.folds 
        skips = skips + len 
        result = result.folding.folds[len]
    end

    return result, skips  
end

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

    local text = type(extendExistingTokens) ~= "string" and self.defaultLines[lineNumber] or extendExistingTokens

    if not text then return {} end  

    if extendExistingTokens == nil or type(extendExistingTokens) ~= "boolean" then extendExistingTokens = false end 

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

    if capturization.type ~= "" then 
        addToken(builder, capturization.type, capturization.group.multiline)
    else 
        addRest()  
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

    for _, token in ipairs(tokens) do 
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
        if not curToken then break end 

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

local function getLeftLen(str)
    if not str then return 0 end 
    local _,_,r = string.find(str, "^(%s*)")
    return #r or 0
end

function DataContext:SmartFolding(startLine) -- Uses Whitespace differences to detect folding
    if not self.context[startLine] then return end 

    local function peekNextFilledLine(start, minLen)
        start = start + 1
        while self.context[start] and (string.gsub((self.context[start] or {}).text or "", "%s", "") == "") do  
            if minLen and getLeftLen(self.context[start].text) < minLen then break end 
            start = start + 1
        end
        return self.context[start], start
    end

    if string.gsub(self.context[startLine].text, "%s", "") == "" then return end 

    local startLeft = getLeftLen(self.context[startLine].text)               
    local nextLeft  = getLeftLen((self.context[startLine + 1] or {}).text)     

    if nextLeft <= startLeft then -- If its smaller, then check if its a whitespace line, if yes, skip all of them until the first filled comes up, then check again.
        local nextFilled, lookup = peekNextFilledLine(startLine, nextLeft)

        if lookup - 1 == startLine then return end 

        startLine = lookup
        nextLeft = getLeftLen((self.context[startLine] or {}).text)     
    
        if nextLeft <= startLeft then return end 
    end 
    
    do
        local c = startLine - 1
        local prev = self.context[c]
        while prev and string.gsub(prev.text, "%s", "") == "" do  
            c = c - 1
            prev = self.context[c]
        end
        if getLeftLen((prev or {}).text or "") > nextLeft then return end 
    end

    startLine = startLine + 2 

    -- uwu so many while luwps howpfuwwy it doewsnt fwuck up x3 (may god have mercy with my soul)

    while true do
        if not self.context[startLine] then return startLine - 2 end 
        
        local currentLeft = getLeftLen(self.context[startLine].text) 

        if currentLeft < nextLeft then 
            local nextReal = peekNextFilledLine(startLine)
            if not nextReal or (nextReal.text ~= "" and getLeftLen(nextReal.text) < nextLeft) then 
                return startLine - 2
            end  
        end 

        startLine = startLine + 1
    end

    return startLine
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
        if not curToken then break end 

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

function DataContext:RefreshFoldingForLine(lineIndex, trigger)
    if not lineIndex then return false end 
    local line = self.context[lineIndex]
    if not line then return false end 
    if line.folding and #line.folding.folds > 0 then return false end 

    if trigger == nil then trigger = true end 

    local endline = self:SmartFolding(lineIndex)

    if endline then 
        diff = endline - lineIndex + 1

        if diff ~= 0 then 
            self.context[lineIndex].folding = {
                available = diff,
                folds = {}
            }

            if trigger == true then 
                self:FoldingAvailbilityFound(lineIndex, diff)
            end 

            return true 
        end 
    end

    return false 
end

function DataContext:GetGlobalFoldingAvailability()
    self:FoldingAvailbilityCheckStarted()

    for lineIndex, contextLine in pairs(self.context) do 
        self:RefreshFoldingForLine(lineIndex)
    end

    self:FoldingAvailbilityCheckCompleted()
end

function DataContext:CountFolds(line)
    if not line or not line.folding or not line.folding.folds or #line.folding.folds == 0 then return 0 end 
    local r = #line.folding.folds 

    for k, v in ipairs(line.folding.folds) do 
        if not v.folding or not v.folding.folds then continue end 
        r = r + #v.folding.folds 
    end

    return r 
end

function DataContext:FoldLine(i)
    if i == nil then return end 

    if i < 1 or i > #self.context then return end 
    local t = self.context[i]

    if not t.folding or self:IsFolding(t) == true then return end 

    self:RefreshFoldingForLine(i, false)

    for n = i + 1, i + t.folding.available, 1 do 
        local v = self.context[n]
        if v.button then v.button:SetVisible(false) end 
        table.insert(t.folding.folds, v)
    end

    for n = 1, t.folding.available, 1 do 
        table.remove(self.context, i + 1)
    end

    self:FixIndeces()

    self:LineFolded(i, t.folding.available)
end

function DataContext:FixIndeces() -- Extremely important function to keep the line indeces in line 
    local c = 1

    local function recursiveFix(entry)
        for k, v in pairs(entry) do 
            entry[k].index = c 
            c = c + 1
            if v.folding and v.folding.folds then 
                recursiveFix(v.folding.folds)
            end
        end
    end

    recursiveFix(self.context)
end

function DataContext:UnfoldLine(i)
    if i == nil then return 0 end 

    if i < 1 or i > #self.context then return 0 end 
    local t = self.context[i]
    if not t or not t.folding or self:IsFolding(t) == false then return 0 end 

    local fc = self:GetFoldCount(i)

    for l, v in pairs(t.folding.folds) do 
        if v.button then v.button:SetVisible(false) end 
        table.insert(self.context, i + l, v)
    end

    local len = #t.folding.folds 

    t.folding.folds = {}

    self:FixIndeces()

    self:RefreshFoldingForLine(i, false)

    self:LineUnfolded(i, len)

    return fc
end

local function constructTextFromTokens(t) 
    if not t then return {} end 
    local r = ""
    for _, v in ipairs(t) do 
        if not v.text then break end 
        r = r .. v.text 
    end
    return r 
end

function DataContext:TrimRight(i)
    if i == nil then return end     

    local line = type(i) == "table" and i or self.context[i]
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

    local prev = self.context[i - 1]

    local lastContextLine = prev or {}

    if prev and prev.folding and #prev.folding.folds > 0 then 
        lastContextLine = lastRecursiveEntry(prev.folding.folds) or self.context[i - 1]
    end

    local temp = {}

    do 
        local index = i 

        if lastContextLine.index then 
            index = (lastContextLine.index or 1) + (self:GetFoldCount(i - 1) or 0) + 1
        end

        temp.index = index 
    end 
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

    for i, line in ipairs(self.defaultLines) do 
        if not line then break end 
        table.insert(self.context, self:ConstructContextLine(i))
        self:TrimRight(i)
    end

    self:GetGlobalFoldingAvailability()

    return self.context 
end

function DataContext:GetFoldCount(i)
    if not i then return 0 end 
    if not self.context[i] then return 0 end 
    if not self.context[i].folding or (self.context[i].folding and self.context[i].folding.folds == 0) then return 0 end  
    return self.context[i].folding.available
end

function DataContext:IsFolding(i)
    line = (type(i) == "table" and i or self.context[i])
    if not line then return false end 
    return line and line.folding and line.folding.folds and #line.folding.folds > 0 
end

function DataContext:ValidateFoldingAvailability(i, trigger)
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

        if not endline then 
            wipe()
            return false 
        end 

        local avFolds = endline - i + 1 

        if avFolds == 0 then 
            wipe()
            return false 
        elseif avFolds ~= self.context[i].folding.available then 
            self:UnfoldLine(i)
            self.context[i].folding.available = avFolds
            return false 
        end

        return true  
    elseif endline then -- It has not yet been detected as foldable but is foldable, make it one!
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

function DataContext:FixFolding(i)
    self:FoldingAvailbilityCheckStarted()

    while self.context[i] do  
        if self.context[i].folding then  
            self:RefreshFoldingForLine(i)
            break 
        end 
        i = i - 1
    end
end

function DataContext:InsertLine(i, text)
    i = i or #self.defaultLines
    i = math.max(i, 1)

    table.insert(self.defaultLines, i, text)
    table.insert(self.context, math.min(i, #self.defaultLines), self:ConstructContextLine(i))

    self:FixIndeces()

    self:FixFolding(i)
end

function DataContext:RemoveLine(i)
    i = i or #self.defaultLines
    i = math.Clamp(i, 1, #self.defaultLines)

    table.remove(self.defaultLines, i)
    table.remove(self.context, i)

    self:FixIndeces()

    self:FixFolding(i)

    return i 
end

function DataContext:OverrideLine(i, text)
    if i <= 0 or i > #self.defaultLines then return end 
    if not text then return end 

    self.defaultLines[i] = text 
    self.context[i] = self:ConstructContextLine(i)

    self:FixIndeces()

    self:FixFolding(i)
end

function DataContext:EntryForReal(line)
    local function recursiveSearch(collection)
        for k, v in pairs(collection) do 
            if k == line then return v end 
            if not v.folding then continue end
    
            local possibleResult = recursiveSearch(v.folding.folds)
            if possibleResult then return possibleResult end 
        end
    end 

    return recursiveSearch(self.context)
end

function DataContext:ParseArea(s, e)
    local last = (self.context[s - 1] or {}).tokens or {}
    local index = s 

    local function recursiveParse(collection, start, ending, inFolds)
        for i = start, ending, 1 do 
            local entry = collection[i]

            if not entry then break end 
        
            local newTokens = self:ParseRow(index, last or {}, collection[i].text or "")

            if inFolds == true and i == 1 and #newTokens == #entry.tokens then 
                break -- We do this to determine wether a full parse is requiered, if the first folded line changes, then all the others are certainly gonna change too.
            end

            collection[i].tokens = newTokens 
            
            index = index + 1

            last = collection[i].tokens 

            if entry.folding and #entry.folding.folds > 0 then
                recursiveParse(entry.folding.folds, 1, #entry.folding.folds, true)
            end
        end
    end

    recursiveParse(self.context, s, e, false)

    return last 
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

local fontBank = {}

local function dark(n,a)
    if a == nil then a = 255 end 
    return Color(n,n,n,a)
end

local function isFolding(line)
    return line and line.folding and line.folding.folds and #line.folding.folds > 0 
end

local self = {}

local offset = 25 
local textoffset = 3

local function mSub(x, strength) return x - (math.floor(x) % strength) end

AccessorFunc(self, "tabSize", "TabSize", FORCE_NUMBER)
AccessorFunc(self, "colors", "Colors")

function self:Init()
    local super = self 

    self.colors = {}
    self.colors.background = dark(45)
    self.colors.lineNumbersBackground = dark(55)
    self.colors.linesEditorDivider = Color(240,130,0, 100)
    self.colors.lineNumbers = Color(240,130,0)
    self.colors.highlights = Color(0,60,220,50)
    self.colors.caret = Color(25,175,25)
    self.colors.endOfText = dark(150,5)
    self.colors.tabIndicators = Color(175,175,175,35)
    self.colors.caretAreaTabIndicator = Color(175,175,175,125)
    self.colors.currentLine = dark(200,10)

    self.colors.foldingIndicator = dark(175,35)
    self.colors.foldingAreaIndicator = Color(100,150,180, 15)
    self.colors.foldsPreviewBackground = dark(35)
    self.colors.amountOfFoldedLines = Color(10,255,10,75)

    self.tabSize = 4

    self.caret = {
        x = 0,
        y = 0, 
        char = 1,
        line = 1,
        actualLine = 1
    }

    self.caretRegion = {-1,-1,-1}

    self.highlights = {}
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
        char = 0,
        line = 1
    } 
    
    function self.textPos:Set(add)
        add = add or 0 
        local scroll = super.scroller:GetScroll() + add  
        self.line = math.ceil(scroll + 1)
        super.scroller:SetScroll(scroll)
    end

    self.lastTextPos = {char=-1,line=-1}

    self.font = {
        w = 0,
        h = 0,
        s = 0,
        n = "",
        an = ""
    }

    self.refresh = 0

    self.foldButtons = {}

    self.highlights = {}

    self.allTabs = {}

    self.undo = {}
    self.redo = {}

    self.lastCode = 0x0

    self.data = table.Copy(DataContext)

    self.data.LineFolded = function(_, line, len)
        self:GetTabLevels()

        if self.caret.actualLine <= line + len then return end
        self.caret.actualLine = self.caret.actualLine - len 
    end

    self.data.LineUnfolded = function(_, line, len)
        self:GetTabLevels()

        if self.caret.actualLine <= line then return end 
        self.caret.actualLine = self.caret.actualLine + len 
    end

    self.data.FoldingAvailbilityCheckStarted = function() 
        self:HideButtons()
    end
    self.data.FoldingAvailbilityFound = function(_, i, len, t)
        local b = self:MakeFoldButton()
        b.super = self.data.context[i]
        b.isHovered = false 
        b.Think = function(self)
            if ( self:GetAutoStretchVertical() ) then
                self:SizeToContentsY()
            end

            if self:IsHovered() == true and self.isHovered == false then 
                super.data:RefreshFoldingForLine(i, false)
                self.isHovered = true
            elseif self:IsHovered() == false then self.isHovered = false end  
        end
        b.DoClick = function(_)
            local super = b.super 

            self:ResetSelection()

            if not super then 
                self:HideButtons()
                return 
            end
        
            local line = self:KeyForIndex(super.index)

            if not line then return end 

            if #super.folding.folds == 0 then  
                b:SetFolded(true)

                local l = self.data.context[line]

                if not l or not l.folding then
                    self:HideButtons()
                    return 
                end 

                local limit = l.index + l.folding.available

                self.data:FoldLine(line)

                if self.caret.line > l.index and self.caret.line <= limit then 
                    self:SetCaret(self.caret.char, limit + 1) -- if the caret is inside an area that is being folded, push it the fuck out of there xoxoxo
                end
            else 
                self.data:UnfoldLine(line)
                self:HideButtons()
                b:SetFolded(false)
            end
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

function self:GetTab()
    return string.rep(" ", self.tabSize)
end

function self:HandleBadButton(v)
    if IsValid(v) == false then 
        if v.super then v.super.button = nil end 
        return 
    elseif IsValid(v) == true and not v.super then 
        v:Remove()
    end 

    v:SetVisible(false) 
end

-- Bad Function, scrap and replace with hidebuttons
function self:CollectBadButtons()
    for k, v in pairs(self.foldButtons) do 
        if IsValid(v) == false then 
            if v.super then 
                v.super.button = nil 
                if v.super.folding and #v.super.folding.folds > 0 then 
                    self.data:UnfoldLine(self:KeyForIndex(v.super.index))
                end
            end

            self.foldButtons[k] = nil 

            continue 
        elseif IsValid(v) == true and not v.super then 

            v:Remove()
            self.foldButtons[k] = nil 

            continue 
        end 

        if v.folding and #v.folding.folds > 0 then 
            v:SetFolded(true) 
        else 
            v:SetFolded(false)
        end

        v:SetVisible(false) 
    end
end

function self:SetSelection(...)
    local startChar, startLine, endingChar, endingLine = select(1, ...), select(2, ...), select(3, ...), select(4, ...)

    if not startChar then return end 

    if type(startChar) == "table" and not startLine then 
        self.selection.start = table.Copy(startChar)
        self.selection.ending = table.Copy(startChar)
        return 
    elseif type(startChar) == "table" and type(startLine) == "table" then 
        self.selection.start = table.Copy(startChar)
        self.selection.ending = table.Copy(startLine) 
        return 
    elseif type(startChar) == "number" and type(startLine) == "number" and not endingChar then 
        endingChar = startChar 
        endingLine = startLine  
    end

    self.selection = {
        start = {
            char = startChar, 
            line = startLine
        },
        ending = 
        {
            char = endingChar,
            line = endingLine 
        }
    }
end 

function self:SetSelectionEnd(t)
    self.selection.ending = table.Copy(t) 
end

function self:IsSelecting()
    return self.selection.start.char ~= self.selection.ending.char or self.selection.start.line ~= self.selection.ending.line 
end

function self:ResetSelection()
    self:SetSelection(self.caret)
end

function self:HideButtons()
    for k, v in pairs(self.foldButtons) do 
        if IsValid(v) == false then 
            self:HandleBadButton(v)
            self.foldButtons[k] = nil 
            continue 
        end
        v:SetVisible(false)
    end
end

function self:GetLine(i)
    for k, v in pairs(self.data.context) do 
        if v.index == i then 
            return v 
        end
    end
    return nil 
end

local function insertChar(text, char, index)
    if not text or not char then return end 
    index = index or #text 
    return string.sub(text, 1, index) .. char .. string.sub(text, index + 1, #text) 
end

local function removeChar(text, index)
    if not text then return end 
    index = index or #text 
    return string.sub(text, 1, index - 1)  .. string.sub(text, index + 1, #text)
end

local function removeArea(text, start, ending)
    if not text or not start or not ending then return end 
    return string.sub(text, 1, start) .. string.sub(text, ending, #text)
end

local function getLR(text, index)
    if not text or not index then return end 
    return string.sub(text, 1, index), string.sub(text, index + 1, #text) 
end

function self:TextChanged() 
    self:ParseVisibleLines()
    self:GetTabLevels()
    self:HideButtons()
end 

function self:_TextChanged() 
    local new = self.entry:GetText()

    self.data:UnfoldLine(self.caret.actualLine)
    self.caret.actualLine = self.caret.actualLine + self.data:UnfoldLine(self.caret.actualLine - 1)

    local function foo()
        if new == "\n" then return end 

        local line = self.data.context[self.caret.actualLine]
        
        if not line then return end  

        if #new == 1 then 
            self.data:OverrideLine(self.caret.actualLine, insertChar(line.text, new, self.caret.char))
            self:SetCaret(self.caret.char + 1, self.caret.line)
        else 

        end
    end

    foo()

    self:GetTabLevels()

    self.data:ValidateFoldingAvailability(self.caret.actualLine - 1)

    self.entry:SetText("")

    self:TextChanged()
end

function self:_KeyCodeReleased(code)

end

function self:_KeyCodePressed(code)
    self.lastCode = code 

    local line = self.data.context[self.caret.actualLine]

    if not line then return end 

    local left, right = getLR(line.text, self.caret.char) 

    local savedCaret = self:IsShift() == true and table.Copy(self.caret) or nil 
    local function handleSelection()
        if self:IsShift() == true then 
            if self:IsSelecting() == false then 
                self:SetSelection(savedCaret, self.caret)
            else 
                self:SetSelectionEnd(self.caret)
            end
        else 
            self:ResetSelection()
        end 
    end

    if code == KEY_DOWN then
        self:SetCaret(self.caret.char, self.caret.line + 1, true)
        handleSelection()
    elseif code == KEY_UP then
        self:SetCaret(self.caret.char, self.caret.line - 1, true)
        handleSelection()
    elseif code == KEY_RIGHT then 
        self:SetCaret(self.caret.char + 1, self.caret.line, true)
        handleSelection()
    elseif code == KEY_LEFT then 
        self:SetCaret(self.caret.char - 1, self.caret.line, true)
        handleSelection()
    elseif code == KEY_ENTER then 
        if self.data:UnfoldLine(self.caret.actualLine) > 0 then 
            self.data:ValidateFoldingAvailability(self.caret.actualLine) 
        end 

        if self.caret.char ~= #line.text and self.data:UnfoldLine(self.caret.actualLine - 1) > 0 then 
            self.data:ValidateFoldingAvailability(self.caret.actualLine - 1) 
        end 

        self.data:OverrideLine(self.caret.actualLine, left)
        self.data:InsertLine(self.caret.actualLine + 1, right)

        self:SetCaret(0, self.caret.line + 1)

        self:TextChanged()
    elseif line then 
        if code == KEY_BACKSPACE then 
            if self.caret.char - 1 < 0 then -- Remove line 
                self.data:UnfoldLine(self.caret.actualLine)
                self.data:UnfoldLine(self.caret.actualLine - 1)

                local newLine = self.data.context[self.caret.actualLine - 1]

                if not newLine then return end 

                self.data:OverrideLine(self.caret.actualLine - 1, newLine.text .. right)

                self:SetCaret(#newLine.text, self.caret.line - 1)

                self.data:RemoveLine(self.caret.actualLine + 1)

                self.data:ValidateFoldingAvailability(self.caret.actualLine)
            else -- Normal character remove
                local save = self.caret.actualLine
                local unfolds = self.data:UnfoldLine(save)

                local left = getLeftLen(line.text)

                if self.caret.char <= left then 
                    local save = self.caret.char

                    if self.caret.char % self.tabSize == 0 then 
                        self.caret.char = self.caret.char - self.tabSize 
                    else 
                        self.caret.char = self.caret.char - self.caret.char  % self.tabSize 
                    end

                    local diff = save - self.caret.char 

                    self.data:OverrideLine(self.caret.actualLine, string.rep(" ", left - diff) .. string.gsub(line.text, "^(%s*)", "")) 
                    self:SetCaret(self.caret.char, self.caret.line, true)
                else 
                    self.data:UnfoldLine(self.caret.actualLine - 1)

                    self.data:OverrideLine(self.caret.actualLine, removeChar(line.text, self.caret.char))
                    self:SetCaret(self.caret.char - 1, self.caret.line, true)

                    self.data:ValidateFoldingAvailability(self.caret.actualLine - 1)
                end

                if unfolds > 0 then 
                    self.data:ValidateFoldingAvailability(save)
                end
            end 

            self:TextChanged()
     elseif code == KEY_TAB then
            local save    = self.caret.actualLine 
            local unfolds = self.data:UnfoldLine(save)

            local left = getLeftLen(line.text)

            if self.caret.char <= left then 
                local save = self.caret.char

                if self.caret.char % self.tabSize == 0 then 
                    self.caret.char = self.caret.char + self.tabSize 
                else 
                    self.caret.char = self.caret.char - self.caret.char  % self.tabSize + self.tabSize 
                end

                local diff = self.caret.char - save        

                self.data:OverrideLine(self.caret.actualLine, string.rep(" ", left + diff) .. string.gsub(line.text, "^(%s*)", ""))
                self:SetCaret(self.caret.char, self.caret.line)
            else
                self.data:UnfoldLine(self.caret.actualLine - 1)
                
                self.data:OverrideLine(self.caret.actualLine, insertChar(line.text, self:GetTab(), self.caret.char))
                self:SetCaret(self.caret.char + self.tabSize, self.caret.line)

                self.data:ValidateFoldingAvailability(self.caret.actualLine - 1)
            end

            self.tabbed = true

            if unfolds > 0 then 
                self.data:ValidateFoldingAvailability(save)
            end

            self:TextChanged()
        end
    end
end

function self:_FocusLost()
    if self:HasFocus() == true or self.tabbed then 
        self.entry:RequestFocus()
        self.tabbed = nil 
    end
end

function self:OnFocusChanged(gained)
    if gained == false then return end
    self.entry:RequestFocus()
end

function self:ProfileSet() end 
function self:SetProfile(profile)
    self:TimeRefresh(10)
    self.data:SetRulesProfile(profile)
    self:ProfileSet(self.data.profile)
end

function self:ProfileReset() end 
function self:ClearProfile()
    self.data:ResetProfile()
    self:ProfileReset()
end

function self:SetText(text)
    if not text then return end
    self:TimeRefresh(10)
    self.data:SetContext(text)
    self:TextChanged()
    self:GetTabLevels()
end

function self:FontChanged(newFont, oldFont) end 
function self:SetFont(name, size)
    if not name then return end 

    size = size or 16 
    size = math.Clamp(size, 14, 48)

    local newFont = "SSLEF" .. name  .. size

    if not fontBank[newfont] then
        local data = 
        {
            font      = name,
            size      = size,
            weight    = 520 
        }

        surface.CreateFont(newFont, data)

        fontBank[newFont] = data 
    end 

    surface.SetFont(newFont)

    local w, h = surface.GetTextSize(" ")

    local oldFont = table.Copy(self.font)

    self.font = 
    {
        w = w,
        h = h,
        n = newFont,
        an = name,
        s = size 
    }

    self:FontChanged(self.font, oldFont)
end 

local function isWhitespace(str)
    return string.gsub(str, "%s", "") == "" 
end

function self:GetCaretTabRegion() 
    self.caretRegion = {-1,-1,-1}

    local history = {}
    local lastTabs = 0

    local lastLine = 0

    for line, tabs in pairs(self.allTabs) do

        if tabs == lastTabs then continue end 

        if tabs > lastTabs then 
            table.insert(history, line)
        elseif tabs < lastTabs then 
            local startLine = history[#history] 

            if startLine then 
                startLine = startLine - 1
                if startLine <= self.caret.actualLine and line >= self.caret.actualLine then 
                    self.caretRegion = {startLine, line, #history - 1}
                    PrintTable(self.caretRegion)

                    return  
                end 
            
                table.remove(history)
            end
        end

        lastTabs = tabs 
        lastLine = line 
    end

    local last = history[#history - 1]

    if not last then return end 

    self.caretRegion = {last - 1, lastLine, #history}
end

function self:GetTabLevels()
    local s = self.textPos.line 
    local e = self.textPos.line + self:VisibleLines()

    self.allTabs = {}

    local temp = {}
    local lastLevel = -1

    for i = s, e, 1 do 
        local item = self.data.context[i] 

        if not item then break end 

        if string.gsub(item.text, "%s", "") == "" then 
            table.insert(temp, item.index)
        else 
            local len = getLeftLen(item.text) 

            if len < lastLevel then 
                for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(len / self.tabSize) + 1 end
            elseif lastLevel == -1 then -- If all of the start was whitespaces
                local lastValidLen = 0

                for i = s, 1, -1 do 
                    local item = self.data.context[i] 

                    if not item then break end 

                    if string.gsub(item.text, "%s", "") ~= "" then 
                        lastValidLen = getLeftLen(item.text)
                        break 
                    end
                end

                if lastValidLen ~= 0 then
                    for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(math.min(lastValidLen, len) / self.tabSize) + 1 end
                end 
            else 
                for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(lastLevel / self.tabSize) + 1 end
            end

            temp = {}

            self.allTabs[item.index] = math.ceil(len / self.tabSize)

            lastLevel = len 
        end
    end

    if #temp then -- If all at the end was whitespaces 
        for _, t in ipairs(temp) do self.allTabs[t] = math.ceil(lastLevel / self.tabSize) + 1 end 
    end
end

function self:TimeRefresh(len)
    self.refresh = RealTime() + (len or 1) 
end

function self:RefreshData() -- As insurance we refresh some of the "bugheavy" stuff sometimes 
    self:GetTabLevels()
    self.data:FixIndeces()
    self:HideButtons()
    self.data:GetGlobalFoldingAvailability()
end

function self:TokenizeArea(start, ending)
    self.data:ParseArea(start, ending)
end

function self:ParseVisibleLines()
    if self:IsVisible() == false then return end  
    self.data:ParseArea(self.textPos.line , (self.textPos.line + self:VisibleLines()))
end

function self:PosInText(...) return self:pit(...) end 
function self:pit(...) -- short for pos in text. Converts local x, y coordinates to a position in the text 
    if #{...} ~= 2 then return end 

    local x, y = select(1, ...), select(2, ...)

    local panelW, panelH = self:GetSize()

    if x == nil then x = 1 else x = math.Clamp(x, 0, panelW) end
    if y == nil then y = 1 else y = math.Clamp(y, 0, panelH) end 

    x = x - (offset * 2 + self:GetLineNumberWidth() - textoffset)
  --  x = x + self.textPos.char * self.font.w 

    x = math.Round(mSub(x, self.font.w) / self.font.w + self.textPos.char - 1)
    y = math.Round(mSub(y, self.font.h) / self.font.h + self.textPos.line)

    y = math.Clamp(y, 1, #self.data.context)
    x = math.Clamp(x, 0, #(self.data.context[y].text or ""))

    y = self.data.context[y].index 

    return x, y
end

function self:PosOnPanel(...) return self:pop(...) end 
function self:pop(...) -- short for pos on panel. Converts a position in the text to a position on the panel
    if #{...} ~= 2 then return end 

    local char, line = select(1, ...), select(2, ...)

    local x = (char - self.textPos.char + (self.textPos.char > 0 and 1 or 0)) * self.font.w 
    local y = line * self.font.h 

    x = x + offset * 2 + self:GetLineNumberWidth() + textoffset 

    return x, y 
end

function self:KeyForIndex(index)
    for k, v in pairs(self.data.context) do 
        if v.index ~= index then continue end 
        return k 
    end 
end

function self:IndexForKey(key)
    return self.data.context[key].index 
end

function self:CaretSet(char, line, actualLine) end 
function self:SetCaret(...)
    if #{...} < 2 then return end 

    local char, line, swapOnReach = select(1, ...), select(2, ...), select(3, ...)

    if swapOnReach == nil then swapOnReach = false end 

    local actualLine = self:KeyForIndex(line)

    if not actualLine then 
        local last = self.caret.actualLine
        
        if self.lastCode == KEY_UP or self.lastCode == KEY_LEFT then 
            actualLine = last - 1
        elseif self.lastCode == KEY_DOWN or self.lastCode == KEY_RIGHT then   
            actualLine = last + 1
        else return end  

        actualLine = math.Clamp(actualLine, 1, #self.data.context)

        line = self.data.context[actualLine].index
    end

    self.caret.line = math.max(line, 1)
    self.caret.actualLine = actualLine -- We save this to avoid shitty loops all over the place 

    if swapOnReach == false then 
        self.caret.char = math.Clamp(char, 0, #self.data.context[actualLine].text) 
    else
        if char > #self.data.context[actualLine].text and self.lastCode == KEY_RIGHT then 
            if not self.data.context[actualLine + 1] then return end  
            self:SetCaret(0, self.caret.line + 1)
        elseif char < 0 and (self.lastCode == KEY_LEFT or self.lastCode == KEY_BACKSPACE) then 
            self:SetCaret(#((self.data.context[actualLine - 1] or {}).text or ""), self.caret.line - 1)
        else
            self.caret.char = math.Clamp(char, 0, #self.data.context[actualLine].text) 
        end
    end

    self:CaretSet(self.caret.char, self.caret.line, self.caret.actualLine)

    self:Goto()

    return self.caret.line, self.caret.char 
end

function self:OnMouseClick(code) end 
function self:OnMousePressed(code)
    self:OnMouseClick(code)

    if code == MOUSE_LEFT then 
        self:SetCaret(self:pit(self:LocalCursorPos()))
        self:SetSelection(self.caret.char, self.caret.actualLine)
    elseif code == MOUSE_RIGHT then 

    end

    if self.entry:HasFocus() == false then self.entry:RequestFocus() end 
end

function self:GetLineNumberCharCount(add)
    add = add or 0 
    local n     = self.textPos.line + self:VisibleLines() - 1 + add 
    local entry = self.data.context[n]
    return #tostring(entry and entry.index or n)
end

function self:GetLineNumberWidth(add)
    return self:GetLineNumberCharCount(add) * self.font.w 
end

function self:VisibleLines()
    return math.ceil(self:GetTall() / self.font.h)
end

function self:VisibleChars()
    return math.ceil((self:GetWide() - self:GetLineNumberWidth() - offset * 2) / self.font.w) 
end

function self:PaintBefore(w, h) end 
function self:PaintAfter(w, h) end 

local function drawLine(startX, startY, endX, endY, color)
    surface.SetDrawColor(color)
    surface.DrawLine(startX, startY, endX, endY)
end

local function swap(a, b)
    local save = (type(a) == "table" and table.Copy(a) or a)
    a = b 
    b = save
    return a, b 
end

function self:Goto(char, line)
    line = line or self.caret.actualLine 
    char = char or self.caret.char 
    
    do 
        local minLine = self.textPos.line  
        local maxLine = minLine + self:VisibleLines()

        local diff = 0

        if line < minLine then 
            diff = line - minLine
        elseif line > maxLine - 1 then 
            diff = line - (maxLine - 1)
        end

        self.textPos:Set(diff)
    end

    do 
        local minChar = self.textPos.char - 1
        local maxChar = minChar + self:VisibleChars() - math.ceil(self.scroller:GetWide() / self.font.w) - 1

        local diff = 0 

        if char < minChar then 
            diff = char - minChar
        elseif char > maxChar then 
            diff = char - maxChar 
        end

        self.textPos.char = math.max(self.textPos.char + diff, 0) 
    end
end

function self:Highlight(start, ending, i, c, col)
    if not start or not ending or not i or not c then return end 

    local line = self.data.context[i] 

    if not line then return end 

    line = line.text 

    col = col or self.colors.highlights

    surface.SetDrawColor(col)

    if start.line == ending.line and i == start.line then -- If selection is in the same Line 
        local sx,sy = self:pop(start.char, c)
        local ex,ey = self:pop(ending.char, c)

        if ending.char > start.char then 
            surface.DrawRect(sx, sy, ex - sx, self.font.h)
        else
            surface.DrawRect(ex, ey, sx - ex, self.font.h)
        end
    elseif i == ending.line then -- if multiline, end of line selection
        if ending.line > start.line then 
            local ex,ey = self:pop(ending.char, c)
            local sx,sy = self:pop(0, c)

            surface.DrawRect(sx, sy, ex - sx, self.font.h)
        else
            local sx,sy = self:pop(ending.char, c)
            local ex,ey = self:pop(#line, c)     

            surface.DrawRect(sx, sy, ex - sx, self.font.h)               
        end
    elseif i == start.line then -- if multiline, start of line selection
        if ending.line > start.line then 
            local sx,sy = self:pop(start.char, c)
            local ex,ey = self:pop(#line, c)

            surface.DrawRect(sx, sy, math.max(ex - sx, self.font.w), self.font.h)
        else
            local ex,ey = self:pop(start.char, c)
            local sx,sy = self:pop(0, c)

            surface.DrawRect(sx, sy, math.max(ex - sx, self.font.w), self.font.h)
        end
    elseif ((i >= start.line and i <= ending.line) or (i <= start.line and i >= ending.line)) then -- All Lines inbetween Start and End of Selection  
        local sx,sy = self:pop(0, c)
        local ex,ey = self:pop(#line, c)

        surface.DrawRect(sx, sy, math.max(ex - sx, self.font.w), self.font.h)
    end
end

function self:PaintTokensAt(tokens, x, y, maxChars)
    if not tokens then return end 

    maxChars = maxChars or self:VisibleChars()

    local lastY = 0

    for tokenIndex, token in ipairs(tokens) do 
        local txt = token.text

        if token.type == "endofline" and self.textPos.char <= token.start then
            draw.SimpleText("⮯", self.font.n, x + lastY, y, self.colors.tabIndicators)
            break        
        elseif token.type == "error" then 
         --   hasError = true 
        end

        if token.ending < self.textPos.char or token.start > self.textPos.char + maxChars then 
            continue
        elseif token.start < self.textPos.char and token.ending >= self.textPos.char then  
            txt = string.sub(txt, self.textPos.char - token.start + 1, #txt)
        end

        local textY, _ = draw.SimpleText(txt, self.font.n, x + lastY, y, (not token.color and self.data.profile.colors[token.type] or self.data.profile.colors[token.color]) or Color(255,255,255))

        lastY = lastY + textY
    end
end

function self:Paint(w, h)
    self:PaintBefore(w, h)

    local i = self.textPos.line 

    local mx, my = self:LocalCursorPos()

    -- Background 
    draw.RoundedBox(0,0,0,w,h,self.colors.background)

    local i = self.textPos.line 
    local c = 0

    local lineNumCharCount = self:GetLineNumberCharCount()
    local lineNumWidth     = self:GetLineNumberWidth()

    local visLines = self:VisibleLines() 
    local visChars = self:VisibleChars()

    local x = offset * 2 + lineNumWidth 

    -- Backgrounds 
    draw.RoundedBox(0, 0, 0, x, h, self.colors.lineNumbersBackground)
    draw.RoundedBox(0, x, 0, 1, h, self.colors.linesEditorDivider)

    local currentHover

    local bruh = 1
    while i < self.textPos.line + visLines do 
        if bruh > #self.data.context * 2 then print("COCK") break end bruh = bruh + 1 

        local cLine = self.data.context[i]
        if not cLine then break end 

        -- Line Numbers 
        draw.SimpleText(cLine.index, self.font.n, offset + lineNumWidth * ((lineNumCharCount - #tostring(cLine.index)) / lineNumCharCount), c * self.font.h, self.colors.lineNumbers)

        -- Caret 
        if cLine.index == self.caret.line then
            draw.RoundedBox(0, 0, c * self.font.h, self:GetWide(), self.font.h, self.colors.currentLine)

            if self.caret.char + self.textPos.char >= self.textPos.char then 
                local cx, cy = self:pop(self.caret.char, self.caret.actualLine - self.textPos.line)
                draw.RoundedBox(0, cx,cy, 2, self.font.h, self.colors.caret)
            end 
        else 
            self.data:TrimRight(i)
        end

        -- This does the Syntax Coloring
        self:PaintTokensAt(cLine.tokens, textoffset + x, c * self.font.h, visChars)  

        if self:IsSelecting() == true then 
            self:Highlight(self.selection.start, self.selection.ending, i, c)
        end

        local skips = 0

        if IsValid(cLine.button) and cLine.folding and cLine.folding.folds then 
            cLine.button:SetSize(offset * 0.75, cLine.button:GetWide())
            cLine.button:SetVisible((mx > 0 and mx <= textoffset + x) or (#cLine.folding.folds > 0))
            cLine.button:SetPos(x - offset + offset * 0.15, c * self.font.h + (self.font.h / 2 - cLine.button:GetTall() / 2) - 4)

            if cLine.button:IsHovered() == true then 
                currentHover = {cLine, i}

                if #cLine.folding.folds == 0 then -- When unfolded, show the area that will be folded 
                    draw.RoundedBox(0, x, (c + 1) * self.font.h, w, self.font.h * cLine.folding.available, self.colors.foldingAreaIndicator)
                else -- If its folded and button is hovered, show the text that could get unfolded 
                    local len = math.min(#cLine.folding.folds, visLines - c - 1)

                    draw.RoundedBox(0, x, (c + 1) * self.font.h, w, len * self.font.h, self.colors.foldsPreviewBackground)

                    for i = 1, len, 1 do 
                        local l = cLine.folding.folds[i]
                        local lf = l.folding

                        if lf and #lf.folds > 0 then 
                            draw.SimpleText(" < " .. #lf.folds .. " Line" .. (#lf.folds > 1 and "s" or "") .. " hidden >", self.font.n, x + (l.tokens[#l.tokens].ending + 1) * self.font.w, (c + i) * self.font.h, self.colors.amountOfFoldedLines)
                            draw.RoundedBox(0, x, (c + i + 1) * self.font.h, self:GetWide() - x, 1, self.colors.foldingIndicator) 
                        end

                        -- Color the folded lines preview 
                        self:PaintTokensAt(cLine.folding.folds[i].tokens, textoffset + x, (c + i) * self.font.h, visChars)  
                    end

                    draw.RoundedBox(0, 0, (c + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)
                    draw.RoundedBox(0, 0, (c + len + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)

                    c = c + len 
                    skips = len 
                end
            elseif isFolding(cLine) == true then -- WHen folded but not hovered, show where the fold is 
                draw.SimpleText(" < " .. #cLine.folding.folds .. " Line" .. (#cLine.folding.folds > 1 and "s" or "") .. " hidden >", self.font.n, x + (cLine.tokens[#cLine.tokens].ending + 1) * self.font.w, c * self.font.h, self.colors.amountOfFoldedLines)

                if not currentHover 
                or IsValid(currentHover[1].button) == false 
                or (IsValid(currentHover[1].button) == true and (i <= currentHover[2] or currentHover[2] + currentHover[1].folding.available <= i)) then  
                    draw.RoundedBox(0, x, c * self.font.h, w, self.font.h, self.colors.foldingAreaIndicator) -- We dont want the indicators to overlap in the case of a fold inside a hovered fold
                end 

                draw.RoundedBox(0, 0, (c + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)
            end
        elseif cLine.button ~= nil then self.data.context[i].button = nil
        elseif IsValid(cLine.button) and cLine.folding and cLine.folding.folds then self:HandleBadButton(cLine.button) end 

        do -- Tab Indicators 
            local tab = self.allTabs[cLine.index + skips]

            if tab then 
                for n = 2, tab, 1 do 
                    local tabLen = (n - 1) * self.tabSize

                    if tabLen < 0 or (tabLen >= getLeftLen(cLine.text) and cLine.text ~= "") then break end 

                    local posX = (tabLen - math.max(self.textPos.char - 1, 0)) * self.font.w

                    if posX < 0 then continue end 

                    draw.RoundedBox(0, x + posX, c * self.font.h, 1, self.font.h, self.colors.tabIndicators)
                end
            end
        end 

        -- Tab Indicators
        if self.data.profile.language ~= "Plain" then 

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
    self:ParseVisibleLines()
    self:GetTabLevels()
    self:HideButtons()
    self:OnScrolled(diff)
end

function self:OnMouseWheeled(delta)
    if self:IsCtrl() == false then 
        self.scroller:SetScroll(self.scroller:GetScroll() - delta * 4)
    else 
        self:SetFont(self.font.an, self.font.s - delta * 2)
    end
end

function self:Think()
    self.textPos:Set()

    if self.textPos.line ~= self.lastTextPos.line then 
        self:_OnScrolled(self.textPos.line - self.lastTextPos.line)
    end

    if RealTime() > self.refresh then 
        self:RefreshData()
        self:TimeRefresh(10)
    end

    if input.IsMouseDown(MOUSE_LEFT) == true and vgui.GetHoveredPanel() == self and self.scroller.Dragging == false then 
        self:SetCaret(self:pit(self:LocalCursorPos()))
        self:SetSelection(self.selection.start.char, self.selection.start.line, self.caret.char, self.caret.actualLine)
    end

    self.lastTextPos = table.Copy(self.textPos)
end

local bFont 
function self:MakeFoldButton()
    local button = vgui.Create("DButton", self)

    if not bFont then 
        bFont = {
            font      = "Consolas",
            size      = 35,
            weight    = 550 
        }
        surface.CreateFont("SSLEFoldButtonFont", bFont)
    end

    button:SetFont("SSLEFoldButtonFont")

    button:SetVisible(false)
    button.Paint = function()
        button:SetTextColor((button:IsHovered() or button.foldStatus == true) and dark(160) or dark(110))
    end

    button.foldStatus = false 
    button.SetFolded = function(self, status)
        if status == true then 
            button:SetText("⯈")
        else
            button:SetText("⯆")
        end
        self.foldStatus = status 
    end

    button:SetTextColor(dark(110))

    button:SetAutoStretchVertical(true)
    button:SizeToContentsY()

    button:SetFolded(false)

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
    sb:SetFont("Consolas", 16)

    sb:SetText([["
while(1)
{


    if(1)
    {
        if(2)
        {
            allTabs

            a
        }
    }
}

        
"


        ]])
    sb:SetText(file.Read("expression2/Projects/Mechs/Spidertank/Spidertank_NewAnim/spiderwalker-v1.txt", "DATA"))
end

concommand.Add("sopen", function( ply, cmd, args )
    open()
end)

open()
