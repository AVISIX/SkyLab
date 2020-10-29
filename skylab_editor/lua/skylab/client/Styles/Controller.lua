if not SSLE then 
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Failed to mount Syntax Controller, global table does not exist!")
    return 
end

local function check(l)
    if not SSLE.styles then 
        SSLE.styles = {} 
    end 

    if not SSLE.styles[l] then 
        SSLE.styles[l] = {}
    end
end

function SSLE.RegisterStyle(language, stylename, coloring)
    if not language or not coloring or not stylename then return end 
    if type(stylename) ~= "string" or type(language) ~= "string" or type(coloring) ~= "table" then return end 

    check(language)

    SSLE.styles[language][stylename] = coloring 
end

function SSLE.RemoveStyle(language, stylename)
    if not language or not stylename then return end 
    if type(stylename) ~= "string" or type(language) ~= "string" then return end 

    check(language)

    SSLE.styles[language][stylename] = nil 
end 