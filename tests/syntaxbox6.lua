--[[
    To Do (Fixes / Improvements):
        - Remove defaultLines value and replace with startText and when you return the text construct it from the tokens.
        - make seperate classes for caret, selection, foldButton and 

    To Do (Tasks):
        - Indenting
        - Auto Pairing

    Notes:
        - When closing the editor, save the folds in the sqlite db and save the timestamp. if the file was edited after that specific timestamp, reset the folds to unfolded 
]]

local function swap(a, b)
    local save = (type(a) == "table" and table.Copy(a) or a)
    return b, save 
end

local DataContext = {}
DataContext.__index = DataContext

DataContext.undo = {}
DataContext.redo = {}

DataContext.defaultLines = {}
DataContext.context = {}
DataContext.defaultText = ""

DataContext.matchesdefault = {
    whitespace = {
        pattern = "%s+"
    }, 
    default = {}
}

DataContext.colorsdefault = {
    error = Color(255,0,0),
    default = Color(255,255,255),
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
function DataContext:ParseRow(text, prevTokens, extendExistingTokens)
    if not self.profile then return {} end 
    if not text then return {} end  

    if extendExistingTokens == nil then extendExistingTokens = false end 

    self.latestParsedLine = self.latestParsedLine or 1 

    self.profile.onLineParseStarted(self.latestParsedLine, text)

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

        self.profile.onTokenSaved(lt, self.latestParsedLine, lt.type, buffer, result)

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

                    local val = v.validation(text, buffer, match, #result, result, self.latestParsedLine) or false 

                    if type(val) == "string" then 
                        k   = val
                        val = true 
                    end 

                    if val == true then
                        addRest()
                        addToken(match, k, (self.profile.matches[k] or {}).color or nil)

                        buffer = buffer + #match 

                        self.profile.onMatched(match, self.latestParsedLine, k, buffer, result)

                        return true 
                    end 
                end
                return false 
            end)() == true  or
            (function() -- Handle Captures 
                for k, v in pairs(self.profile.captures) do 
                    local match = readPattern(v.begin.pattern)

                    if not match then continue end 

                    local val = v.begin.validation(text, buffer, match, #result, result, self.latestParsedLine)

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

                        self.profile.onCaptureStart(match, self.latestParsedLine, k, buffer, result)

                        return true 
                    end
                end
                return false 
            end)() == true then continue end 
        else   
            local t, g = capturization.type, capturization.group 
            local match = readPattern(g.close.pattern)

            if match then 
                local val = g.close.validation(text, buffer, match, #result, result, self.latestParsedLine)

                if val == true then 
                    buffer = buffer + #match 
                    builder = builder .. match 

                    addToken(builder, t, (self.profile.captures[t] or {}).color or nil)

                    builder = ""

                    capturization.type = "" 
                    
                    self.profile.onCaptureEnd(match, self.latestParsedLine, t, buffer, result)
                    
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

    self.profile.onLineParsed(result, self.latestParsedLine, text)

    return result
end

function DataContext:GetTextArea(startChar, startLine, endChar, endLine)
    if not startChar and not startLine then return end 

    if type(startChar) == "table" and type(startLine) == "table" then 
        endChar   = startLine.char 
        endLine   = startLine.line 
        startLine = startChar.line 
        startChar = startChar.char 
    end

    if startLine == endLine then 
        if startChar > endChar then 
            startChar, endChar = swap(startChar, endChar)
        end

        local entry = self.context[startLine]

        if not entry then return "" end 

        return string.sub(entry.text, startChar + 1, endChar)
    elseif startLine > endLine then  
        startLine, endLine = swap(startLine, endLine)
        startChar, endChar = swap(startChar, endChar)
    end

    startLine = math.max(startLine, 1)

    local result = ""

    local function recursiveAdd(collection)
        local r = ""
        for k, v in pairs(collection) do 
            r = r .. v.text .. "\n"
            if v.folding and #v.folding.folds > 0 then 
                r = r .. recursiveAdd(v.folding.folds)
            end
        end
        return r 
    end 

    for i = startLine, endLine, 1 do 
        local entry = self.context[i]

        if not entry then break end 

        local text = entry.text 

        if i == startLine then 
            result = result .. string.sub(text, startChar + 1, #text) .. "\n"
        elseif i == endLine then 
            result = result .. string.sub(text, 1, endChar) 
        else 
            result = result .. text .. "\n"
        end

        if entry.folding and #entry.folding.folds > 0 then 
            result = result .. recursiveAdd(entry.folding.folds)
        end
    end

    return result 
end

-- Remove Text Area
function DataContext:_RemoveTextArea(startChar, startLine, endChar, endLine)
    if not startChar and not startLine then return end 

    if type(startChar) == "table" and type(startLine) == "table" then 
        endChar   = startLine.char 
        endLine   = startLine.line 
        startLine = startChar.line 
        startChar = startChar.char 
    end

    if startLine == endLine then 
        if startChar > endChar then 
            startChar, endChar = swap(startChar, endChar)
        end

        local entry = self.context[startLine]

        if not entry then return "" end 

        self:OverrideLine(startLine, string.sub(entry.text, 1, startChar) .. string.sub(entry.text, endChar + 1, #entry.text))

        return startChar, startLine, endChar, endLine
    elseif startLine > endLine then  
        startLine, endLine = swap(startLine, endLine)
        startChar, endChar = swap(startChar, endChar)
    end

    startLine = math.max(startLine, 1)

    local sl = self.context[startLine]
    local el = self.context[endLine]

    if not sl or not el then return end 

    sl = sl.text 
    el = el.text 

    self:OverrideLine(startLine, string.sub(sl, 1, startChar) ..string.sub(el, endChar + 1, #el))

    for i = startLine, endLine - 1, 1 do 
        self:RemoveLine(startLine + 1)
    end

    return startChar, startLine, endChar, endLine
end

function DataContext:RemoveTextArea(startChar, startLine, endChar, endLine)
    self:_RemoveTextArea(startChar, startLine, endChar, endLine)
end

-- Insert Text
function DataContext:_InsertTextAt(text, char, line)
    if not text or not char or not line then return end 

    local entry = self.context[line]
        
    if not entry then return end 

    local lines = string.Split(text, "\n")

    if #lines == 1 then 
        text = lines[1]
        
        local left = string.sub(entry.text, 1, char) .. text

        self:OverrideLine(line, left .. string.sub(entry.text, char + 1, #entry.text))

        return #left, line
    end

    local left  = string.sub(entry.text, 1, char)
    local right = string.sub(entry.text, char + 1, #entry.text)

    self:OverrideLine(line, left .. lines[1])

    for i = #lines, 2, -1 do 
        if i == #lines then 
            self:InsertLine(line + 1, lines[i] .. right)
        else 
            self:InsertLine(line + 1, lines[i])
        end
    end

    return #lines[#lines], (line + #lines - 1)
end 

function DataContext:InsertTextAt(text, char, line)
    self:_InsertTextAt(text, char, line)
end

-- Insert Line 
function DataContext:_InsertLine(i, text)
    i = i or #self.context 
    i = math.max(i, 1)

    table.insert(self.context, math.min(i, #self.context + 1), self:ConstructContextLine(i, text))

    self:ValidateFoldingAvailability(i)
    self:ValidateFoldingAvailability(i - 1)

    self:FixIndeces()
end

function DataContext:InsertLine(i, text)
    self:_InsertLine(i, text)
end

-- Remove Line 
function DataContext:_RemoveLine(i)
    i = i or #self.context
    i = math.Clamp(i, 1, #self.context)

    table.remove(self.context, i)

    self:FixIndeces()

    self:ValidateFoldingAvailability(i)
    self:ValidateFoldingAvailability(i - 1)

    return i 
end

function DataContext:RemoveLine(i)
    self:_RemoveLine(i)
end

-- Change Line 
function DataContext:_OverrideLine(i, text)
    if i <= 0 or i > #self.context then return end 
    if not text then return end 

    self.context[i] = self:ConstructContextLine(i, text)

    self:ValidateFoldingAvailability(i)
    self:ValidateFoldingAvailability(i - 1)

    self:FixIndeces()
end

function DataContext:OverrideLine(i, text)
    self:_OverrideLine(i, text)
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

function DataContext:Record() 

end 

function DataContext:Undo()

end

function DataContext:Redo()

end

local function getLeftLen(str)
    if not str then return 0 end 
    local _,_,r = string.find(str, "^(%s*)")
    return #r or 0
end

function DataContext:SmartFolding(startLine) -- Uses Whitespace differences to detect folding
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

function DataContext:GetGlobalFoldingAvailability()
    self:FoldingAvailbilityCheckStarted()

    for lineIndex, contextLine in pairs(self.context) do 
        self:ValidateFoldingAvailability(lineIndex)
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

    if self:ValidateFoldingAvailability(i) == false then return end 

    for n = i + 1, i + t.folding.available, 1 do 
        local v = self.context[n]
        if IsValid(v.button) then v.button:SetVisible(false) end 
        table.insert(t.folding.folds, v)
    end

    for n = 1, t.folding.available, 1 do 
        table.remove(self.context, i + 1)
    end

    self:FixIndeces()

    self:LineFolded(i, t.folding.available, t)

    return t.folding.available
end

function DataContext:FixIndeces() -- Extremely important function to keep the line indeces in line 
    local c = 1

    local function recursiveFix(entry)
        for k, v in ipairs(entry) do 
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

    self:ValidateFoldingAvailability(i)

    self:LineUnfolded(i, len, t)

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

function DataContext:ConstructContextLine(i, text) -- Rework this piece of shit 
    if not i then return {} end 

    self:LineConstructionStarted(i)

    text = string.gsub(text, "\r", "    ") -- Fuck this shit i legit cannot be asked...

    local prev = self.context[i - 1]

    local lastContextLine = prev or {}

    if prev and prev.folding and #prev.folding.folds > 0 then 
        lastContextLine = lastRecursiveEntry(prev.folding.folds) or self.context[i - 1]
    end

    local temp = {}

    temp.index = i 
    self.latestParsedLine = i
    temp.text   = text
    temp.tokens = self:ParseRow(text, (lastContextLine.tokens or {}))

    local level = lastContextLine.level 

    if level == nil then level = 0 end 

    local countedLevel, offset = self:CountIndentation(temp.tokens)

    countedLevel = countedLevel or 0 

    temp.offset = offset 
    temp.nextLineIndentationOffsetModifier = countedLevel + (lastContextLine.nextLineIndentationOffsetModifier or 0)
    temp.level = math.max((lastContextLine.nextLineIndentationOffsetModifier or 0) + math.min(countedLevel, 0), 0)

    self:LineConstructed(i, temp)

    return temp 
end

function DataContext:SetContext(text)
    if not text then return end 

    self.undo = {}
    self.redo = {}

    rules = rules or ""

    local lines = {}

    if type(text) == "table" then 
        lines = text 
    elseif type(text) == "string" then     
        lines = string.Split(text, "\n")
    else return end 

    self.context = {}

    for i, line in ipairs(lines) do 
        table.insert(self.context, self:ConstructContextLine(i, line))
        self:TrimRight(i)
    end

    self:GetGlobalFoldingAvailability()

    return self.context 
end

function DataContext:GetText()
    local function recursiveAdd(collection)
        local temp = ""

        for i = 1, #collection, 1 do 
            local item = collection[i]
            
            if not item then break end 

            temp = temp .. item.text .. "\n"
        
            if item.folding and #item.folding.folds > 0 then
                temp = temp .. recursiveAdd(item.folding.folds)
            end
        end
        
        return temp 
    end

    return recursiveAdd(self.context) 
end

function DataContext:GetLines()
    local result = {}

    local function recursiveAdd(collection)
        for i = 1, #collection, 1 do 
            local item = collection[i]

            if not item or not item.text then break end

            table.insert(result, item.text)

            if item.folding and #item.folding.folds > 0 then
                recursiveAdd(item.folding.folds)
            end
        end
        
        return temp 
    end

    recursiveAdd(self.context) 

    return result 
end

function DataContext:UnfoldAll()
    local i = 1 

    while true do 
        local item = self.context[i]

        if not item then break end 

        if IsValid(item.button) == true then 
            item.button:SetFolded(false)
        end

        self:UnfoldLine(i)

        i = i + 1
    end
end

function DataContext:FoldAll()
    local i = #self.context 

    while true do 
        local item = self.context[i]

        if not item then break end 

        self:ValidateFoldingAvailability(i)

        if IsValid(item.button) == true then 
            item.button:SetFolded(true)
        end

        if (self:FoldLine(i) or 0) ~= 0 then 
            i = #self.context
            continue 
        end

        i = i - 1
    end
end

function DataContext:GetFoldCount(i)
    if not i then return 0 end 
    local item = self.context[i]
    if not item or not item.folding then return 0 end
    return #(item.folding.folds or {})
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

function DataContext:FixFolding(i)
    self:FoldingAvailbilityCheckStarted()

    while self.context[i] do  
        if self.context[i].folding then  
            if self:ValidateFoldingAvailability(i) == true then break end 
        end 

        i = i - 1
    end
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

local function tokensSame(a, b)
    if #a ~= #b then return false end 

    for i = 1, #a, 1 do 
        if a[i].text ~= b[i].text or a[i].type ~= b[i].type then return false end 
    end

    return true 
end

-- Only use this function to do simple parsing for only the tokens.
function DataContext:SimpleAreaParse(s, e)
    local last = self.context[s - 1] or {}
    local index = s 

    local function recursiveParse(collection, start, ending, inFolds)
        for i = start, ending, 1 do 
            local entry = collection[i]

            if not entry then break end 
        
            self.latestParsedLine = i 
            local newTokens = self:ParseRow(entry.text, (last or {}).tokens or {})

            if inFolds == true and i == start and tokensSame(newTokens, entry.tokens) == true then -- We do this to determine wether a full parse is requiered, if the first folded line changes, then all the others are certainly gonna change too.
                last = collection[#collection] -- save the last token to continue the part that was skipped 
                index = index + #collection
                entry.tokens = newTokens 
                break
            end
            
            entry.tokens = newTokens 
            
            index = index + 1

            last = entry 

            if entry.folding and #entry.folding.folds > 0 then
                recursiveParse(entry.folding.folds, 1, #entry.folding.folds, true)
            end
        end
    end

    recursiveParse(self.context, s, e, false)

    return last 
end

DataContext:ResetProfile()
DataContext:SetContext("")

local prof = {}

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

do 
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
    
    prof = {
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

local function tableSame(a, b)
    if not a and not b then return true end -- both are nil, lol 
    if not a or not b then return false end 
    for k, v in pairs(a) do 
        if not b[k] or b[k] ~= v then return false end     
    end
    return true 
end

AccessorFunc(self, "tabSize", "TabSize", FORCE_NUMBER)
AccessorFunc(self, "colors", "Colors")

function self:Init()
    local super = self 

    self.colors = {}
    self.colors.background = dark(40)
    self.colors.lineNumbersBackground = dark(55)
    self.colors.linesEditorDivider = Color(240,130,0, 100)
    self.colors.lineNumbers = Color(240,130,0)

    self.colors.highlights = Color(0,60,220,35)
    self.colors.selection = Color(0,60,220,90)

    self.colors.caret = Color(25,175,25)
    self.colors.endOfText = dark(150,10)

    self.colors.tabIndicators = Color(175,175,175,35)
    self.colors.caretAreaTabIndicator = Color(175,175,175,125)

    self.colors.currentLine = dark(175,5)
    self.colors.currentLineOutlines = dark(200,25)

    self.colors.foldingIndicator = dark(175,35)
    self.colors.foldingAreaIndicator = Color(100,150,180, 15)
    self.colors.foldsPreviewBackground = dark(35)
    self.colors.amountOfFoldedLines = Color(10,255,10,75)

    self.colors.pairHighlights = dark(255, 255)

    self.tabSize = 4

    self.caret = {
        x = 0,
        y = 0, 
        char = 0,
        line = 1,
        actualLine = 1
    }
    self.lastCaret = table.Copy(self.caret)
    self.lastCaret.char = -1 

    self.lastCaretClick = table.Copy(self.caret)
    self.lastCaretClick.char = -1 

    self.caretBlink = RealTime()

    self.lastCaret.char = -1 

    self.caretRegion = {-1,-2,-3}

    self.highlights = {}
    self.selection = {
        start = {
            char = -1,
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
    self.mouseCounter = 1

    self.foldButtons = {}

    self.allTabs = {}

    self.undo = {}
    self.redo = {}

    self.lastCode = 0x0

    self.data = table.Copy(DataContext)

    self.data.LineFolded = function(_, line, len, b)
        self:ClearHighlights()
        self.pressedWord = nil 
        self:ResetBGProg()
        self:GetTabLevels()
        self:UpdateSurroudingPairs()

        b = b.button

        if IsValid(b) == true then 
            b:SetFolded(true)
        end

        if self.caret.actualLine <= line + len then return end
        self.caret.actualLine = self.caret.actualLine - len 
    end

    self.data.LineUnfolded = function(_, line, len, b)
        self:ClearHighlights()
        self.pressedWord = nil 
        self:ResetBGProg()
        self:GetTabLevels()
        self:UpdateSurroudingPairs()

        b = b.button

        if IsValid(b) == true then 
            b:SetFolded(false)
        end

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
                super.data:ValidateFoldingAvailability(i)
                self.isHovered = true
            elseif self:IsHovered() == false then self.isHovered = false end  
        end

        b.DoClick = function(_)
            local super = b.super 

            if not super then 
                self:HideButtons()
                return 
            end
        
            local line = self:KeyForIndex(super.index)

            if not line then return end 

            if #super.folding.folds == 0 then  
                local l = self.data.context[line]

                if self:IsShift() == true then 
                    local max = line + l.folding.available
                    self:SetSelection(0, line + 1, #self.data.context[max].text, max)
                    return 
                else 
                    self:ResetSelection()
                end

                if not l or not l.folding then
                    self:HideButtons()
                    return 
                end 

                if not l.folding.available then 
                    self:HideButtons()
                    self.data:ValidateFoldingAvailability(i)
                    return 
                end

                local limit = l.index + l.folding.available

                self.data:FoldLine(line)

                if self.caret.line > l.index and self.caret.line <= limit then 
                    self:SetCaret(self.caret.char, i) -- if the caret is inside an area that is being folded, push it the fuck out of there xoxoxo
                end

                b:SetFolded(true)
            else             
                self:ResetSelection()
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

    self.runBackgroundWorker = false  
    self.bgLineCounter = 1
    self.bgSuperHistory = {}
    self.bgLast = {}

    self:SetCursor("beam")
end

function self:InitBackgroundWorker() -- Initializes the background thread, this thread will constantly loop through the lines to make sure everything is in correct order.
    self.runBackgroundWorker = true 

    self.bgLast = {}

    self.backgroundWorker = coroutine.create(function() -- DO NOT TOUCH THIS UNDER ANY CIRCUMSTANCES ANY BUG WILL CAUSE A FREEZE
        local function reset()
            self.bgSuperHistory = {{collection=self.data.context,counter=1}}
            self.bgLineCounter = 1 
            self.bgLast = {}
        end

        reset()

        local function reload()
            self.bgLineCounter = 1
            self.bgLast = {} 
        end

        while self.runBackgroundWorker == true do 
            if IsValid(self) == false then break end 

            if not self.bgSuperHistory or #self.bgSuperHistory == 0 then -- insurance incase something fucks up
                reset() 
                coroutine.wait(0.1)
            end 

            if self:IsVisible() == false then -- If its not visible, why parse?
                coroutien.wait(1)
                continue 
            end

            local entry = self.bgSuperHistory[#self.bgSuperHistory]

            if not entry then 
                reset() 
                coroutine.wait(0.1)
                continue 
            end

            if entry.counter > #entry.collection then
                if #self.bgSuperHistory > 1 then 
                    table.remove(self.bgSuperHistory) -- just remove it, dont need to reset the counter in that case
                    entry = self.bgSuperHistory[#self.bgSuperHistory]
                else 
                    entry.counter = 1
                    reload()
                    coroutine.wait(0.1)
                    continue 
                end 
            end

            local item = entry.collection[entry.counter] 

            if item then 
                item.index = self.bgLineCounter 
                self.data.latestParsedLine = self.bgLineCounter
                item.tokens = self.data:ParseRow(item.text, self.bgLast.tokens or {}) 

                local countedLevel, offset = self.data:CountIndentation(item.tokens or {})
                
                item.offset = offset 
                item.nextLineIndentationOffsetModifier = countedLevel + (self.bgLast.nextLineIndentationOffsetModifier or 0)
                item.level = math.max((self.bgLast.nextLineIndentationOffsetModifier or 0) + math.min(countedLevel, 0), 0)
            end

            self.bgLineCounter = self.bgLineCounter + 1

            if self.bgLineCounter > #self.data.context then 
                reset()
                coroutine.wait(0.05)
                continue 
            end

            entry.counter = entry.counter + 1

            self.bgLast = item

            if item.folding and #item.folding.folds > 0 then 
                table.insert(self.bgSuperHistory, {
                    collection = item.folding.folds, 
                    counter = 1
                })
            end

            if self.bgLineCounter % 50 == 0 then 
                coroutine.wait(0.05)
            end 
        end
    end)

    coroutine.resume(self.backgroundWorker)
end

function self:ContinueBackgroundWorker()
    if not self.data.context or #self.data.context == 0 or self.stopBGWorker == true then return end 

    if not self.backgroundWorker then 
        self:InitBackgroundWorker()
        return 
    end

    if coroutine.status(self.backgroundWorker) == "running" then return end 

    if coroutine.status(self.backgroundWorker) == "suspended" or (self.backgroundWorker ~= nil and coroutine.status(self.backgroundWorker) ~= "running") then 
        coroutine.resume(self.backgroundWorker)
    elseif coroutine.status(self.backgroundWorker) == "dead" and not self.backgroundWorker then 
        self:ResetBGProg()
    end
end

function self:ResetBGProg(newProg)
    if not self.backgroundWorker then 
        self:InitBackgroundWorker()
        return 
    end
    
    if coroutine.status(self.backgroundWorker) ~= "dead" then
        self.bgLineCounter = newProg or 1
        self.bgLast = self.data.context[self.bgLineCounter - 1] or {}
        self.bgSuperHistory = {{collection=self.data.context,counter=1}}
    end
end

function self:KillBGWorker()
    if not self.backgroundWorker then return end 

    if coroutine.status(self.backgroundWorker) ~= "dead" then
        self.bgLineCounter = 1
        self.bgLast = {}
        self.bgSuperHistory = {{collection=self.data.context,counter=1}}
        self.runBackgroundWorker = false 
        self.backgroundWorker = nil 
    end
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

function self:SetSelection(...)
    local startChar, startLine, endingChar, endingLine = select(1, ...), select(2, ...), select(3, ...), select(4, ...)

    if startChar == nil then return end 

    if type(startChar) == "table" and startLine == nil then 
        self.selection.start = table.Copy(startChar)
        self.selection.ending = table.Copy(startChar)
        return 
    end 
    
    if type(startChar) == "table" and type(startLine) == "table" then 
        self.selection.start = table.Copy(startChar)
        self.selection.ending = table.Copy(startLine) 
        return 
    end 
    
    if type(startChar) == "number" and type(startLine) == "number" and endingChar == nil then 
        endingChar = startChar 
        endingLine = startLine  
    end

    self.selection = {
        start = {
            char = startChar, 
            line = startLine
        },
        ending = {
            char = endingChar,
            line = endingLine 
        }
    }
end 

function self:SetSelectionEnd(t, lol)
    if type(t) == "table" then 
        self.selection.ending = table.Copy(t)
        return 
    end  

    self.selection.ending.char = t
    self.selection.ending.line = lol 
end

function self:IsSelecting()
    return self.selection.start.char ~= self.selection.ending.char or self.selection.start.line ~= self.selection.ending.line 
end

function self:ResetSelection()
    self:SetSelection(self.caret.char, self.caret.actualLine)
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
    self:ClearHighlights()
    self.pressedWord = nil 
    self:UpdateSurroudingPairs()
    self:ResetSelection()
end 

function self:RemoveSelection()
    if self:IsSelecting() == true then
        local sc, sl, ec, el = self.data:RemoveTextArea(self.selection.start.char, self.selection.start.line, self.selection.ending.char, self.selection.ending.line)
        if sc and sl then 
            self:SetCaret(sc, sl)
        end 
    end 
end

function self:InsertText(text, char, line)
    char = char or self.caret.char 
    line = line or self.caret.actualLine
    char, line = self.data:InsertTextAt(text, char, line)
    if char then self:SetCaret(char, line) end
end

function self:_TextChanged() 
    local new = self.entry:GetText()

    self:RemoveSelection()

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
            self:InsertText(new)
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

function self:OnKeyCombo(key1, key2)

end
function self:_KeyCodePressed(code)
    self.lastCode = code 

    self:ToggleCaret()
    
    do 
        local keyA 

        if self:IsShift() then 
            keyA = input.IsKeyDown(KEY_LSHIFT) and KEY_LSHIFT or KEY_RSHIFT
        elseif self:IsCtrl() then 
            keyA = input.IsKeyDown(KEY_LCONTROL) and KEY_LCONTROL or KEY_RCONTROL
        end

        self:OnKeyCombo(keyA, code)
    end

    local line = self.data.context[self.caret.actualLine]

    if not line then return end 

    local left, right = getLR(line.text, self.caret.char) 

    local savedCaret = table.Copy(self.caret or {}) 

    local function handleSelection()
        if self:IsShift() == true then 
            if self:IsSelecting() == false then 
                self:SetSelection(savedCaret.char, savedCaret.actualLine, self.caret.char, self.caret.actualLine)
            else 
                self:SetSelectionEnd(self.caret.char, self.caret.actualLine)
            end
        else 
            self:ClearHighlights()
            self.pressedWord = nil 
            self:ResetSelection()
        end 
    end

    if self:IsCtrl() then
        if code == KEY_C then 
            if self:IsSelecting() == true then
                local copy = self.data:GetTextArea(self.selection.start, self.selection.ending)
                if copy then  
                    SetClipboardText(copy)
                end 
            end 
        elseif code == KEY_K then 
            self.data:FoldAll()
        elseif code == KEY_J then 
            self.data:UnfoldAll()
        elseif code == KEY_A then 
            local c = self.data.context 
            self:SetSelection(0,1,#c[#c].text, #c) 
        end

        return
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
            if self:IsSelecting() == true then
                self:RemoveSelection()
            else 
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
                            self.caret.char = self.caret.char - self.caret.char % self.tabSize 
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

function self:GetTokenAtPoint(char, line)
    local line = self.data.context[line]
    if not line or not line.tokens then return end
    for i = 1, #line.tokens, 1 do 
        local token = line.tokens[i]
        if token.start <= char and token.ending >= char then 
            return token, char, line, i
        end
    end
end

function self:GetSurroundingPairs(char, line)
    if not char or not line then return end 
    if not self.data.profile.closingPairs then return end 

    local token, _, _, tokenIndex = self:GetTokenAtPoint(char, line) 

    if (not token or (not tokenIndex and char == 1)) and line ~= 1 then 
        line = line - 1
        local entry = self.data.context[line]
        if not entry then return end 
        tokenIndex = #entry.tokens 
        token = entry.tokens[tokenIndex]
    end

    if not tokenIndex then return end 

    local function isPair(text)
        for k, v in pairs(self.data.profile.closingPairs) do 
            if v.open == text then 
                return "open", k, v 
            elseif v.close == text then 
                return "close", k, v 
            end
        end
    end

    local endArgs 
    local startArgs 
    
    do 
        local curToken = self.data.context[line].tokens[tokenIndex]

        if curToken then 
            local type, name, data = isPair(curToken.text) 

            if type and type == "close" then 
                local prevToken = {}

                local tki = tokenIndex 
                local tkl = line 

                if tki - 1 < 1 then 
                    tkl = tkl - 1 
                    if tkl < 1 then 
                        prevToken = nil 
                    else 
                        tki = #self.data.context[tkl].tokens 
                    end
                else 
                    tki = tki - 1
                end

                if prevToken then 
                    prevToken = self.data.context[tkl].tokens[tki]
                    if prevToken then 
                        tokenIndex = tokenIndex - 1
                        token = prevToken 
                    end 
                end 
            end
        end 
    end 

    local result = {}

    do 
        local function findStartPair(index, line)
            if not index or not line then return end 

            local counter = {}

            while true do 
                if index < 1 then 
                    line = line - 1 
                    if not self.data.context[line] or line < 1 then return end 
                    index = #self.data.context[line].tokens 
                    if not index then continue end 
                end

                local token = self.data.context[line].tokens[index]

                if token then 
                    local type, name, data = isPair(token.text)

                    if type == "open" then
                        if counter[name] == nil then counter[name] = 0 end  

                        if counter[name] == 0 then 
                            return index, line, token, type, name, data
                        else 
                            counter[name] = counter[name] - 1
                        end
                    elseif type == "close" then 
                        if counter[name] == nil then counter[name] = 0 end 
                        counter[name] = counter[name] + 1
                    end
                end 

                index = index - 1
            end 
        end

        startArgs = {findStartPair(tokenIndex, line)}

        if #startArgs == 0 then return end 

        result.start = {
            tkIndex = startArgs[1],
            line = startArgs[2]
        }
    end

    do 
        local function findClosePair(index, line, key)
            if not index or not line then return end 

            local counter = 0

            while true do 
                local item = self.data.context[line]

                if not item or not item.tokens then return end 

                if index > #item.tokens then
                    index = 1
                    line = line + 1
                    if line > #self.data.context then return end 
                end

                local token = self.data.context[line].tokens[index]

                if not token then return end 

                local type, name, data = isPair(token.text)

                if key then 
                    if name and name == key then 
                        if type == "close" then 
                            if counter == 0 then 
                                return index, line, token, type, name, data 
                            else 
                                counter = counter - 1 
                            end
                        elseif type == "open" then 
                            counter = counter + 1
                        end
                    end
                elseif type == "close" then 
                    return index, line, token, type, name, data 
                end

                index = index + 1
            end
        end

        endArgs = {findClosePair(tokenIndex + 1, line, (startArgs ~= nil and startArgs[5] or nil))}

        if #endArgs > 0 then 
            result.ending = {
                tkIndex = endArgs[1],
                line = endArgs[2]
            }
        end 
    end 

    return result 
end

function self:RefreshCaretMoveTimer()
    self.caretMoveTimer = RealTime() + 0.2
end

function self:UpdateSurroudingPairs()
    self.surroundingPairs = self:GetSurroundingPairs(self.caret.char, self.caret.actualLine)
end

function self:CaretStoppedMovingHandler()
    if not self.caretMoveTimer then return end  
    if RealTime() > self.caretMoveTimer then 
        self:UpdateSurroudingPairs()
        self.caretMoveTimer = nil 
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

function self:ParseVisibleLines()
    if self:IsVisible() == false then return end  
    self.data:SimpleAreaParse(self.textPos.line , (self.textPos.line + self:VisibleLines()))
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

    local x = (char - self.textPos.char + 1) * self.font.w 
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
    function self:SetCaret(...)
        if #{...} < 2 then return end 
    
        local char, line, swapOnReach = select(1, ...), select(2, ...), select(3, ...)

        self.lastCaret = table.Copy(self.caret)
    
        if self.caret.char ~= char or self.caret.line ~= line then 
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
    
            self:ToggleCaret()
    
            self:CaretSet(self.caret.char, self.caret.line, self.caret.actualLine)
    
            self.data:ValidateFoldingAvailability(self.caret.actualLine) 
    
            self:Goto()
    
            self:RefreshCaretMoveTimer()
        end
    
        return self.caret.line, self.caret.char 
    end
end

function self:WordAtPoint(char, line)
    if not char or not line then return end 

    local item = self.data.context[line]
    if not item then return end 

    item = item.text 

    local firstChar = item[char]

    if not firstChar then return end 

    if firstChar == " " then 
        for i = char - 1, 0, -1 do 
            local c = item[i] 
            if not c or c ~= " " then 
                local a, b, c = string.find(item, "(%s+)", i + 1)
                if a and b then 
                    return (a - 1), b, (c or string.sub(item, a, b))
                end 
            end
        end 
    else  
        if isSpecial(firstChar) == true then 
            for i = char - 1, 0, -1 do
                local c = item[i] 
                if not c or isSpecial(c) == false or string.gsub(c, "%s", "") == "" then 
                    local a, b, c = string.find(item, "(%p+)", i + 1)
                    if a and b then 
                        return (a - 1), b, (c or string.sub(item, a, b))
                    end 
                end 
            end
        else 
            for i = char - 1, 0, -1 do
                local c = item[i] 
                if not c or isSpecial(c) == true or string.gsub(c, "%s", "") == "" then 
                    local a, b, c = string.find(item, "([^ %p]+)", i + 1)
                    if a and b then 
                        return (a - 1), b, (c or string.sub(item, a, b))
                    end 
                end 
            end 
        end
    end 
end

-- Non recursive function to find words 
function self:FindWords(needle, usePatterns, rangeStart, rangeEnd, checkCallback, filterEmpty)
    if not needle then return {} end 

    checkCallback = checkCallback or function() return true end 

    if usePatterns == nil then usePatterns = true end 
    if filterEmpty == nil then filterEmpty = true end 

    rangeStart = rangeStart or self.textPos.line 
    rangeEnd   = rangeEnd   or (self.textPos.line + self:VisibleLines())

    local result = {}
    
    for line = rangeStart, rangeEnd, 1 do 
        local item = self.data.context[line]

        if not item then break end 

        local i = 1

        while i <= #item.text do 
            local a, b = string.find(item.text, needle, i, !usePatterns) 
            
            if a and b and a == i then

                if filterEmpty == true and string.gsub(string.sub(item.text, i, b), "%s", "") == "" then 
                    i = i + 1
                    continue 
                end 

                local temp = {
                    start = {
                        char = (i - 1),
                        line = line  
                    },
                    ending = {
                        char = b,
                        line = line 
                    }
                }

                if checkCallback(temp) == true then 
                    table.insert(result, temp)
                    i = i + #needle
                    continue 
                end 
            end 

            i = i + 1
        end
    end

    return result 
end

function self:HighlightPressedWord()
    if not self.pressedWord then return end 
    table.Merge(self.highlights, self:FindWords(self.pressedWord, false), nil, nil, function(temp)
        return tableSame(self.selection, temp) == false
    end)
end 

function self:OnMouseClick(code) end 
function self:OnMousePressed(code)
    self:OnMouseClick(code)

    if code == MOUSE_LEFT then 
        self:SetCaret(self:pit(self:LocalCursorPos()))
        
        local line = self.data.context[self.caret.actualLine]

        ::HandleNewMouseCounter:: 

        if line and tableSame(self.caret, self.lastCaretClick) == true then 
            self:ClearHighlights()

            if self.mouseCounter == 1 then 
                local start, ending, word = self:WordAtPoint(self.caret.char, self.caret.actualLine)

                if not start then 
                    self.mouseCounter = self.mouseCounter + 1
                    goto HandleNewMouseCounter
                end

                self:SetSelection(start, self.caret.actualLine, ending, self.caret.actualLine)
            elseif self.mouseCounter == 2 then 
                self:SetSelection(0, self.caret.actualLine, 0, math.min(self.caret.actualLine + 1, #self.data.context))
            else
                self:ResetSelection() 
            end

            self.mouseCounter = self.mouseCounter + 1
            
            if self.mouseCounter > 2 then self.mouseCounter = 0 end 
        else
            self:ClearHighlights()
            self:ResetSelection()
            
            self.pressedWord = ({self:WordAtPoint(self.caret.char, self.caret.actualLine)})[3] or nil 

            self:HighlightPressedWord()

            self.mouseCounter = 1
        end 
    elseif code == MOUSE_RIGHT then 

    end

    self.lastCaretClick = table.Copy(self.caret)

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

function self:AddHighlight(a, b, c, d)
    ::CheckParamsAgain::

    if a == nil or b == nil then return end 
    
    if type(a) == "table" and type(b) == "table" then 
        c = b.char 
        d = b.line 
        b = a.line 
        a = a.char 

        goto CheckParamsAgain 
    end 

    table.insert(self.highlights, {
        start = {
            char = a, 
            line = b
        },
        ending = {
            char = c, 
            line = d 
        }
    })
end

function self:ClearHighlights()
    self.highlights = {}
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

    local errors = {}

    local lastY = 0

    for tokenIndex, token in ipairs(tokens) do 
        local txt = token.text

        if token.type == "endofline" and self.textPos.char <= token.start then
            draw.SimpleText("⮯", self.font.n, x + lastY, y, self.colors.tabIndicators)
            break        
        elseif token.type == "error" then 
            table.insert(errors, token)
        end

        if token.ending < self.textPos.char or token.start > self.textPos.char + maxChars then 
            continue
        elseif token.start < self.textPos.char and token.ending >= self.textPos.char then  
            txt = string.sub(txt, self.textPos.char - token.start + 1, #txt)
        end

        local textY, _ = draw.SimpleText(txt, self.font.n, x + lastY, y, (not token.color and self.data.profile.colors[token.type] or self.data.profile.colors[token.color]) or Color(255,255,255))

        lastY = lastY + textY
    end

    return errors 
end

function self:ToggleCaret()
    self.caretBlink = RealTime() + 0.33
    self.caretToggle = true 
end

function self:PaintCaret(x, w, i, c, index)
    if self.caretToggle == nil then self.caretToggle = false end

    if RealTime() > self.caretBlink then 
        self.caretToggle = !self.caretToggle
        self.caretBlink = RealTime() + 0.33
    end 

    if index == self.caret.line then
        draw.RoundedBox(0, 0, c * self.font.h, w, 1, self.colors.currentLineOutlines)
        draw.RoundedBox(0, 0, c * self.font.h, w, self.font.h, self.colors.currentLine)
        draw.RoundedBox(0, 0, (c + 1) * self.font.h, w, 1, self.colors.currentLineOutlines)

        if self.caretToggle == true then 
            if self.caret.char + self.textPos.char >= self.textPos.char then 
                draw.RoundedBox(0, x + self.font.w * (self.caret.char - self.textPos.char + 1), c * self.font.h, 2, self.font.h, self.colors.caret)
            end
        end  
    else 
        self.data:TrimRight(i)
    end
end 

function self:PaintHighlights(i, c)
    if #self.highlights > 0 then 
        for _, v in ipairs(self.highlights) do 
            self:Highlight(v.start, v.ending, i, c)
        end
    end
end

function self:PaintSurroundingPairs(i, c)
    if not self.surroundingPairs then return end 
    surface.SetDrawColor(self.colors.pairHighlights)

    local s = self.surroundingPairs.start 
    local e = self.surroundingPairs.ending 

    if s and e and s.line == e.line and s.tkIndex + 1 == e.tkIndex and i == s.line then 
        local startToken = self.data.context[s.line].tokens[s.tkIndex]
        local endToken   = self.data.context[e.line].tokens[e.tkIndex]
        if startToken and endToken then 
            local x, y = self:pop(startToken.start - 1, c)
            surface.DrawOutlinedRect(x, y, (#startToken.text + #endToken.text) * self.font.w, self.font.h, 1)
            return 
        end 
    end

    if s and s.line == i then 
        local token = self.data.context[s.line].tokens[s.tkIndex]
        if token then 
            local x, y = self:pop(token.start - 1, c)
            surface.DrawOutlinedRect(x, y, #token.text * self.font.w, self.font.h, 1)
        end 
    end
    
    if e and e.line == i then 
        local token = self.data.context[e.line].tokens[e.tkIndex]
        if token then 
            local x, y = self:pop(token.start - 1, c)
            surface.DrawOutlinedRect(x, y, #token.text * self.font.w, self.font.h, 1)
        end 
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
        if bruh > #self.data.context * 2 then print("infinite loop") break end bruh = bruh + 1 

        local cLine = self.data.context[i]
        if not cLine then break end 

        -- Line Numbers 
        draw.SimpleText(cLine.index, self.font.n, offset + lineNumWidth * ((lineNumCharCount - #tostring(cLine.index)) / lineNumCharCount), c * self.font.h, self.colors.lineNumbers)
        
        self:PaintCaret(textoffset + x, w, i, c, cLine.index)

        -- This does the Syntax Coloring
        self:PaintTokensAt(cLine.tokens, textoffset + x, c * self.font.h, visChars)  

        -- Selection 
        if self:IsSelecting() == true then 
            self:Highlight(self.selection.start, self.selection.ending, i, c, self.colors.selection)
        end

        -- Highlights
        self:PaintHighlights(i, c)

        -- Surrounding Pairs 
        self:PaintSurroundingPairs(i, c)

        do -- Tab Indicators 
            local tab = self.allTabs[cLine.index]

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

        -- Code Folding Indication and Preview 
        if IsValid(cLine.button) and cLine.folding and cLine.folding.folds then 
            cLine.button:SetSize(offset * 0.75, cLine.button:GetWide())
            cLine.button:SetVisible((mx > 0 and mx <= textoffset + x) or (#cLine.folding.folds > 0))
            cLine.button:SetPos(x - offset + offset * 0.15, c * self.font.h + (self.font.h / 2 - cLine.button:GetTall() / 2) - 4)

            if cLine.button:IsHovered() == true then 
                currentHover = {cLine, i}

                if #cLine.folding.folds == 0 then -- When unfolded, show the area that will be folded 
                    draw.RoundedBox(0, x, (c + 1) * self.font.h, w, self.font.h * (cLine.folding.available or 0), self.colors.foldingAreaIndicator)
                    draw.RoundedBox(0, x, (c + 1) * self.font.h, self:GetWide() - x, 1, self.colors.foldingIndicator)
                    draw.RoundedBox(0, x, (c + 1 + (cLine.folding.available or 0)) * self.font.h, self:GetWide() - x, 1, self.colors.foldingIndicator)
                else -- If its folded and button is hovered, show the text that could get unfolded 
                    local len = math.min(#cLine.folding.folds, visLines - c - 1)

                    draw.RoundedBox(0, x, (c + 1) * self.font.h, w, len * self.font.h, self.colors.foldsPreviewBackground)

                    for i = 1, len, 1 do 
                        local l = cLine.folding.folds[i]
                        local lf = l.folding

                        if lf and #lf.folds > 0 then 
                            draw.SimpleText(" < " .. #lf.folds .. " Line" .. (#lf.folds > 1 and "s" or "") .. " hidden >", self.font.n, x + math.max(l.tokens[#l.tokens].ending + 1 - self.textPos.char, 0) * self.font.w, (c + i) * self.font.h, self.colors.amountOfFoldedLines)
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
                draw.SimpleText(" < " .. #cLine.folding.folds .. " Line" .. (#cLine.folding.folds > 1 and "s" or "") .. " hidden >", self.font.n, x + math.max(cLine.tokens[#cLine.tokens].ending + 1 - self.textPos.char, 0) * self.font.w, c * self.font.h, self.colors.amountOfFoldedLines)

                if not currentHover 
                or IsValid(currentHover[1].button) == false 
                or (IsValid(currentHover[1].button) == true and (i <= currentHover[2] or currentHover[2] + (currentHover[1].folding.available or 0) <= i)) then  
                    draw.RoundedBox(0, x, c * self.font.h, w, self.font.h, self.colors.foldingAreaIndicator) -- We dont want the indicators to overlap in the case of a fold inside a hovered fold
                end 

                draw.RoundedBox(0, 0, (c + 1) * self.font.h, self:GetWide(), 1, self.colors.foldingIndicator)
            end
        elseif cLine.button ~= nil then self.data.context[i].button = nil
        elseif IsValid(cLine.button) and cLine.folding and cLine.folding.folds then self:HandleBadButton(cLine.button) end 

        i = i + 1
        c = c + 1
    
        if i > #self.data.context then break end 
    end

    self.scroller:SetUp(visLines + 1, #self.data.context + visLines)

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
    self:ClearHighlights()
    self:HighlightPressedWord()
    self:OnScrolled(diff)
end

function self:OnMouseWheeled(delta)
    if self:IsCtrl() == false then 
        self.scroller:SetScroll(self.scroller:GetScroll() - delta * 4)
    else 
        self:SetFont(self.font.an, self.font.s - delta * 2)
    end
end

function self:HighlightSelectedWords()
    if tableSame(self.selection, self.lastSelection or {}) == false then 
        self:ClearHighlights()

        local selectedText = self.data:GetTextArea(self.selection.start, self.selection.ending)

        if selectedText then 
            self.pressedWord = selectedText
            self:HighlightPressedWord()
        end

        self.lastSelection = table.Copy(self.selection) 
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

    if input.IsMouseDown(MOUSE_LEFT) == true then 
        if vgui.GetHoveredPanel() == self and self.scroller.Dragging == false and self.mouseCounter == 1 then 
            self:SetCaret(self:pit(self:LocalCursorPos()))

            if self.selectionStartFix then 
                self:SetSelection(self.selection.start.char, self.selection.start.line, self.caret.char, self.caret.actualLine)
            else 
                self.selectionStartFix = true 
                self:ResetSelection()
            end

            if self.selection.start.line == self.selection.ending.line and self.selection.start.char ~= self.selection.ending.char then 
                self:HighlightSelectedWords()
            elseif 
            (self.selection.start.line == self.selection.ending.line and self.selection.start.char == self.selection.ending.char and tableSame(self.caret, self.lastCaret) == false) 
            or self.selection.start.line ~= self.selection.ending.line 
            then 
                self:ClearHighlights()
            end 

        end
    elseif self:IsShift() == true then 
        self:HighlightSelectedWords()
    end

    self:ContinueBackgroundWorker()
    self:CaretStoppedMovingHandler()

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

vgui.Register("SkyLabCodeBox", self, "DPanel")



local function open()
    if IsValid(TESTWINDAW) == false or IsValid(TESTWINDAW.view) == false then 
        TESTWINDAW = vgui.Create("DFrame")
        TESTWINDAW:SetPos( ScrW() / 2 - 900 , ScrH() / 2 - 1000 / 2 )
        TESTWINDAW:SetSize( 900, 1000 )
        TESTWINDAW:SetTitle( "Derma SyntaxBox V6" )
        TESTWINDAW:SetDraggable( true )
        TESTWINDAW:MakePopup()
        TESTWINDAW:SetSizable(true)
        TESTWINDAW:SetMinWidth(200)
        TESTWINDAW:SetMinHeight(100)
        TESTWINDAW.view = vgui.Create("SkyLabCodeBox", TESTWINDAW)
    end 

    TESTWINDAW.view:SetProfile(prof)
	TESTWINDAW.view:Dock(FILL)
    TESTWINDAW.view:SetFont("Consolas", 16)

    TESTWINDAW.view:SetText([[function DataContext:SmartFolding(startLine) -- Uses Whitespace differences to detect folding
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
    end]])
    --    TESTWINDAW.view:SetText(file.Read("expression2/Projects/Mechs/Spidertank/Spidertank_NewAnim/spiderwalker-v1.txt", "DATA"))
--  TESTWINDAW.view:SetText(file.Read("expression2/libraries/e2parser_v2.txt", "DATA"))
--TESTWINDAW.view:SetText(file.Read("expression2/crashmaster.txt", "DATA"))
end

concommand.Add("sopen", function( ply, cmd, args )
    open()
end)

open()