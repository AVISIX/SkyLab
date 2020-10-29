--[[
    Syntax Profile Controller

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

--[[
    Reason for this System:

    - In the case of Expression 2, there is a userfunctions cache. 
    It is 100% assured, that if multiple Expression 2 Editors were open, this single cache would contain the data of all of the Editors, causing them to conflict and bug the hell out.
]]

if not SSLE then 
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Failed to mount Syntax Controller, global table does not exist!")
    return 
end

-- Create a new Syntax Profile 
-- id = Unique Profile identifier such as "C#-Profile" or "GLua-Profile"
-- cache = The Data your profile will use. In the case of Expression2 there is a cache, which saves the Userfunctions for that specific file.
-- profileFunc = The Function that handles everything related to the Profile. See it as "Container", where you can do all the stuff related to your Profile. MUST RETURN PROFILE AS TABLE!
function SSLE.RegisterProfile(id, profileFunc)
    if not SSLE.profiles then 
        SSLE.profiles = {} 
    end 

    SSLE.profiles[id] = {
        profile = function() return profileFunc() end 
    }
end

-- Run this function to get the a syntax Profile
function SSLE.GetProfile(id)
    if not SSLE.profiles then 
        SSLE.profiles = {} 
    end 

    if not SSLE.profiles[id] then 
        return {} 
    end 

    return table.Copy(SSLE.profiles[id]).profile()
end