function swap(a, b)
    local save = (type(a) == "table" and table.Copy(a) or a)
    return b, save 
end

function isWhitespace(str)
    return string.gsub(str, "%s", "") == "" 
end 

function isUpper(char)  
    if not char or char == "" then return false end 
    local n = string.byte(char)
    return n >= 65 and n <= 90 
end

function isLower(char)  
    if not char or char == "" then return false end 
    local n = string.byte(char)
    return n >= 97 and n <= 122 
end

function isNumber(char) 
    if not char or char == "" then return false end 
    local n = string.byte(char)
    return n >= 48 and n <= 57 
end

function isLetter(char)
    return isUpper(char) == true or isLower(char) == true or isNumber(char) == true
end

function isSpecial(char)
    return isNumber(char) == false and isLower(char) == false and isUpper(char) == false 
end 

function dark(n,a)
    if a == nil then a = 255 end 
    return Color(n,n,n,a)
end

function isFolding(line)
    return line and line.folding and line.folding.folds and #line.folding.folds > 0 
end

function getLeftLen(str)
    if not str then return 0 end 
    local _,_,r = string.find(str, "^(%s*)")
    return #r or 0
end

function mSub(x, strength) return x - (math.floor(x) % strength) end

function tableSame(a, b)
    if not a and not b then return true end -- both are nil, lol 
    if not a or not b then return false end 
    for k, v in pairs(a) do 
        if not b[k] or b[k] ~= v then return false end     
    end
    return true 
end
