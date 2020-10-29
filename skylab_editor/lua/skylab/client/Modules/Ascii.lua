if not SSLE or SERVER then 
	return 
end

local ascii = {}

function ascii:GetControlCharacters()
    local result = {}
    for i = 0, 31, 1 do 
        result[i + 1] = string.char(i)
    end
    return result 
end

function ascii:GetPrintableCharacters()
    local result = {}
    for i = 32, 127, 1 do 
        result[#result + 1] = string.char(i)
    end
    return result 
end

function ascii:GetExtendedAscii()
    local result = {}
    for i = 128, 255, 1 do 
        result[#result + 1] = string.char(i)
    end
    return result 
end

function ascii:IsControlChar(char)
    if not char then return end
    local byte = string.byte(char) 
    return byte >= 0 and byte <= 31 
end

function ascii:SsPrintableCharacter(char)
    if not char then return end
    local byte = string.byte(char) 
    return byte >= 32 and byte <= 127 
end

function ascii:IsExtendedAscii(char)
    if not char then return end
    local byte = string.byte(char) 
    return byte >= 128 and byte <= 255 
end

SSLE.modules = SSLE.modules or {}
SSLE.modules.ascii = ascii    