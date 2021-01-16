--[[
    Editor Constructor 

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

if not SSLE then 
    MsgC(Color(255,0,0), "Failed to mount constructor. Skylon _G table does not exist!")
end 

SSLE.launch = function()
    SSLE.editor:Open("LUA", "vgui/contextbase.lua")
      --  SSLE:OpenBrowser(function()end)
end

concommand.Add("SkyLab_lua_launch", SSLE.launch, nil, "Launch SkyLab Lua Panel")