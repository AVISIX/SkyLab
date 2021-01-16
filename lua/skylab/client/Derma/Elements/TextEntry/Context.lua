if not SSLE then return end 

local function swap(a, b)
    local save = (type(a) == "table" and table.Copy(a) or a)
    return b, save 
end

local function getLeftLen(str)
    if not str then return 0 end 
    local _,_,r = string.find(str, "^(%s*)")
    return #r or 0
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

local function tokensSame(a, b)
    if #a ~= #b then return false end 
    for i = 1, #a, 1 do if a[i].text ~= b[i].text or a[i].type ~= b[i].type then return false end end
    return true 
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

function DataContext:GetIndexForKey(line) -- The Index is basically the "actual" line. 
    if not line then return 0 end 
    if line <= 0 or line > #self.context then return 0 end  
    return self.context[line].index 
end

function DataContext:GetKeyForIndex(index)
    if not index or index <= 0 then return 0, false end

    local function recursiveSearch(collection)
        for k, v in ipairs(collection) do 
            if v.index == index then return true end 
            if v.folding and v.folding.folds and #v.folding.folds > 0 then return recursiveSearch(v.folding.folds) end
        end
        return false 
    end 

    for k, v in ipairs(self.context) do 
        if v.index == index then return k, false end 
        if v.folding and v.folding.folds and #v.folding.folds > 0 then if recursiveSearch(v.folding.folds) == true then return k, true end end
    end 

    return 0, false
end

function DataContext:RevealLine(index)
    if not index or index <= 0 then return end

    local foldstack = {}

    local function recursiveSearch(collection) 
        for k, v in ipairs(collection) do 
            if v.index == index then return true end 
            if v.folding and #v.folding.folds > 0 then 
                table.insert(foldstack, v.index)
                if recursiveSearch(collection) == true then return true end
                table.remove(foldstack)
            end
        end
        return false 
    end 

    local function createFoldstack()
        for k, v in ipairs(self.context) do 
            if v.index == index then return end 
            if v.folding and #v.folding.folds > 0 then 
                foldstack = {}
                table.insert(foldstack, v.index)
                if recursiveSearch(v.folding.folds) == true then return end 
            end
        end
    end
    
    createFoldstack()

    while #foldstack > 0 do  
        local item = foldstack[1]
        for k, v in ipairs(self.context) do 
            if v.index == item then 
                for i, v2 in pairs(v.folding.folds) do 
                    if v2.button then v2.button:SetVisible(false) end 
                    table.insert(self.context, k + i, v2)
                    self:LineUnfolded(k, #v.folding.folds, v)
                end
            end 
        end
        table.remove(foldstack, 1)
    end
    
    self:GetGlobalFoldingAvailability()
    self:FixIndeces()
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

function DataContext:InsertTextAt(text, char, line, do_undo) 
    self:ValidateFoldingAvailability(line)
    self:ValidateFoldingAvailability(line - 1) 
    return self:_InsertTextAt(text, char, line, do_undo) 
end
function DataContext:_InsertTextAt(text, char, line, do_undo)
    if not text or not char or not line then return end 

    local entry = self.context[line]
        
    if not entry then return end 

    if do_undo == nil then do_undo = true end 

    if do_undo == true then 
        self.redo = {}
        table.insert(self.undo, {
            t = "remove",
            text = text,
            char = char,
            line = line
        })
    end

    local lines = string.Split(text, "\n")

    if #lines == 1 then 
        text = lines[1]
        
        local left = string.sub(entry.text, 1, char) .. text

        self:_OverrideLine(line, left .. string.sub(entry.text, char + 1, #entry.text))

        return #left, line
    end

    local left  = string.sub(entry.text, 1, char)
    local right = string.sub(entry.text, char + 1, #entry.text)

    self:_OverrideLine(line, left .. lines[1])

    local function il(i, t) table.insert(self.context, math.min(i, #self.context + 1), self:ConstructContextLine(i, t)) end

    for i = #lines, 2, -1 do 
        if i == #lines then 
            il(line + 1, lines[i] .. right)
        else 
            il(line + 1, lines[i])
        end
    end

    self:FixIndeces()

    return #lines[#lines], (line + #lines - 1)
end 

function DataContext:RemoveTextArea(startChar, startLine, endChar, endLine, do_undo)
    self:ValidateFoldingAvailability(startLine)
    self:ValidateFoldingAvailability(startLine - 1) 
    return self:_RemoveTextArea(startChar, startLine, endChar, endLine, do_undo) 
end

function DataContext:_RemoveTextArea(startChar, startLine, endChar, endLine, do_undo)
    if not startChar and not startLine then return end 

    local text = endChar
    
    if type(endLine) == "boolean" then 
        do_undo = endLine 
    else
        if do_undo == nil then do_undo = true end 
    end

    if type(startChar) == "table" and type(startLine) == "table" then 
        endChar   = startLine.char 
        endLine   = startLine.line 
        startLine = startChar.line 
        startChar = startChar.char 
    elseif type(endChar) == "string" then 
        local lines = string.Split(endChar, "\n")

        endLine = startLine + #lines - 1

        if startLine == endLine then 
            endChar = startChar + #lines[#lines]
        else 
            endChar = #lines[#lines]
        end
    end

    local function storeUndo()
        if do_undo == true then 
            self.redo = {}

            if type(endChar) ~= "string" then 
                text = self:GetTextArea(startChar, startLine, endChar, endLine)
            end

            table.insert(self.undo, {
                t = "insert",
                text = text,
                char = startChar,
                line = startLine
            })
        end    
    end

    if startLine == endLine then 
        if startChar > endChar then 
            startChar, endChar = swap(startChar, endChar)
        end

        local entry = self.context[startLine]

        if not entry then return startChar, startLine, endChar, endLine end 

        storeUndo()

        local partA = string.sub(entry.text, 1, startChar)
        local partB = string.sub(entry.text, endChar + 1, #entry.text)

        self:_OverrideLine(startLine, partA .. partB)

        return startChar, startLine, endChar, endLine
    elseif startLine > endLine then  
        startLine, endLine = swap(startLine, endLine)
        startChar, endChar = swap(startChar, endChar)
    end

    startLine = math.max(startLine, 1)

    local sl = self.context[startLine]
    local el = self.context[endLine]

    if not sl or not el then return end 

    storeUndo()

    sl = sl.text 
    el = el.text 

    self:_OverrideLine(startLine, string.sub(sl, 1, startChar) ..string.sub(el, endChar + 1, #el))

    for i = startLine + 1, endLine, 1 do 
        table.remove(self.context, i)
    end

    self:FixIndeces()

    return startChar, startLine, endChar, endLine
end

function DataContext:AddText(text, char, line, do_undo)
    return self:_InsertTextAt(text, char, line, do_undo)
end

function DataContext:RemoveText(text, char, line, do_undo)
    self:ValidateFoldingAvailability(line)
    self:ValidateFoldingAvailability(line - 1)
    return self:_RemoveTextArea(char, line, text, do_undo)
end

function DataContext:InsertLine(i, text)
    i = i - 1
    local line = self.context[i]
    if not line or not line.text then return end 
    self:InsertTextAt("\n" .. text, #line.text, i)
end

function DataContext:RemoveLine(i)
    local endChar, endLine
    do 
        local cur = self.context[i]
        if cur and cur.text then 
            endChar, endLine = (#cur.text), i 
        else return end 
    end

    local startChar, startLine 
    do 
        local prev = self.context[i - 1]
        if prev and prev.text then 
            startChar, startLine = (#prev.text), (i - 1) 
        else 
            startChar, startLine = 0, i 
        end
    end 

    self:_RemoveTextArea(startChar, startLine, endChar, endLine)
end

function DataContext:OverrideLine(i, text) self:_OverrideLine(i, text) end
function DataContext:_OverrideLine(i, text)
    if i <= 0 or i > #self.context then return end 
    if not text then return end 

    self.context[i] = self:ConstructContextLine(i, text)

    self:ValidateFoldingAvailability(i)
    self:ValidateFoldingAvailability(i - 1)

    self:FixIndeces()
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

function DataContext:Undo()
    if #self.undo == 0 then return end

    local r1, r2 

    local entry = table.Copy(self.undo[#self.undo])

    if entry.t == "insert" then 
        r1, r2 = self:_InsertTextAt(entry.text, entry.char, entry.line, false)

        local cp = table.Copy(entry)
        cp.t = "remove"

        table.insert(self.redo, cp)
    elseif entry.t == "remove" then 
        r1, r2 = self:_RemoveTextArea(entry.char, entry.line, entry.text, false)

        local cp = table.Copy(entry)
        cp.t = "insert"

        table.insert(self.redo, cp)
    else 
        error("Unknown Undo Type (What the fuck?)")
    end 

    table.remove(self.undo)

    return r1, r2 
end

function DataContext:Redo()
    if #self.redo == 0 then return end

    local r1, r2 

    local entry = self.redo[#self.redo]

    if entry.t == "insert" then 
        r1, r2 = self:_InsertTextAt(entry.text, entry.char, entry.line, false)

        local cp = table.Copy(entry)
        cp.t = "remove"

        table.insert(self.undo, cp)
    elseif entry.t == "remove" then 
        r1, r2 = self:_RemoveTextArea(entry.char, entry.line, entry.text, false)

        local cp = table.Copy(entry)
        cp.t = "insert"

        table.insert(self.undo, cp)
    else 
        error("Unknown Redo Type (What the fuck? v2)")
    end

    table.remove(self.redo)

    return r1, r2 
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

function DataContext:UnfoldLine(i, fix)
    if i == nil then return 0 end 

    if fix == nil then fix = true end 

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

function DataContext:TextFromToken(t)
    return constructTextFromTokens(t)
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

    text = string.gsub(text, "[\r\t]", "    ") -- Fuck this shit i legit cannot be asked...

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

SSLE.DataContext = DataContext

--[[
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
]]