--[[
    Default Text Syntax Profile

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

SSLE.RegisterProfile("Default", function()
    return {
        language = "Plain",

        filetype = ".txt",
    
        reserved = {},
        unreserved = {},
        closingPairs = {},
    
        indenting = {
            open = {},
            close = {},
            openValidation = function() return true end,
            closeValidation = function() return true end,
            offsets = {}
        },
    
        autoPairing = {},
    
        matches = {
            whitespace = {
                pattern = "%s+"
            }
        },
        
        captures = {},
    
        intending = {},
    
        colors = {
            error = Color(255,0,0),
            whitespace = Color(255,255,255)
        },
    
        onLineParsed = function() end,
        onLineParseStarted = function() end,
        onMatched = function() end,
        onCaptureStart = function() end,
        onTokenSaved = function() end 
    }
end)