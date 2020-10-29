--[[
    Misc Lua Functions

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

function getFilesize(path, root)

    local size 
    if type(path) ~= "number" then 
        size = file.Size(path, root)
    else 
        size = path 
    end

    if not size or size == 0 then return 0 .. " B" end 

    local sizeName = " B"
    
    if size > 1024 then -- 1 kilobyte
        size = math.floor(size / 1024)
        sizeName = " KB"
    end 

    if size > 1024 then -- 1 megabyte
        size = math.floor(size / 1024)
        sizeName = " MB"
    end        

    if size > 1024 then -- 1 gigabyte
        size = math.floor(size / 1024)
        sizeName = " GB"
    end          

    return size .. sizeName
end 

function shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function swap(a, b)
    return table.Copy(b), table.Copy(a) 
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

function isLetter(char)
    return isUpper(char) == true or isLower(char) == true 
end

function isNumber(char) 
    if not char or char == "" then return false end 
    local n = string.byte(char)
    return n >= 48 and n <= 57 
end

function isSpecial(char)
    return isNumber(char) == false and isLower(char) == false and isUpper(char) == false 
end 

function mSub(x, strength)
    return x - (math.floor(x) % strength)
end

function whitespace(str)
    if not str then return false end 
    return string.gsub(str, "%s", "") == ""
end

function compareLines(A, B)
    if not A or not B then return nil end 
    local aL = {}
    local bL = {}
    do 
        local aT = type(A)
        local bT = type(B)
        if aT == "string" then 
            aL = string.Split(A, "\n")
        elseif aT == "table" then 
            aL = A 
        else return 0, 0 end 
        if bT == "string" then 
            bL = string.Split(B, "\n")
        elseif bT == "table" then 
            bL = B 
        else return nil end 
    end 
    local eL = 0 
    if #aL ~= #bL then 
        eL = (#aL > #bL and #aL or #bL)
    else 
        eL = #aL 
        while eL >= 1 and aL[eL] == bL[eL] do  
            eL = eL - 1
        end
    end
    if eL == 0 then return {0,0} end
    local sL = 1
    while aL[sL] == bL[sL] and sL < eL do  
        sL = sL + 1
    end
    return {sL, eL}
end

function randomLetter()
    local letter = string.char(math.random(97, 122))
    return math.random(1,2) == 1 and letter or string.upper(letter)
end

function randomNumber()
    return string.char(math.random(48,57)) 
end

function randomWord(len)    
    local result = randomLetter()
    for i = 1, len - 1, 1 do 
        result = result .. (math.random(1,2) == 1 and randomLetter() or randomNumber())
    end
    return result 
end
