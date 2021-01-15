--[[
    Main File for SkyLab Lua Compiler

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

local function l(p) return "skylab/" .. p end

if SERVER then  
    MsgC(Color(255,0,0), [[
 _ _______                      _____ _          _             
| |__   __|                    / ____| |        | |            
| |  | | ___  __ _ _ __ ___   | (___ | | ___   _| | ___  _ __  
| |  | |/ _ \/ _` | '_ ` _ \   \___ \| |/ / | | | |/ _ \| '_ \ 
|_|  | |  __/ (_| | | | | | |  ____) |   <| |_| | | (_) | | | |
(_)  |_|\___|\__,_|_| |_| |_| |_____/|_|\_\\__, |_|\___/|_| |_|
                                            __/ |              
                                           |___/                     
	]] ..  "\n")

    AddCSLuaFile()
    include(l"import.lua")  
 
    skylon_skylab_reset_imports()

    -- Shared Init
    import(l"shared/init/LuaExtras.lua")
    import(l"shared/init/selfcomputing.lua")
    import(l"shared/init/deceleration.lua")
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Loaded main modules.")

 
    -- Serverside Import
    import(l"server/init/acceleratedtransfer.lua")
    importFolder(l"server/*") 
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Imported Serverside Files.")


    -- Clientside File Registrations
    addCSFile(l"import.lua")
    addCSFolder(l"client/*")
    addCSFolder(l"shared/*")
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Registered Clientside Files.")

    local files, _ = file.Find("addons/SkyLab/materials/skylab/*", "GAME")
    for _, v in pairs(files) do 
        resource.AddSingleFile("addons/SkyLab/materials/skylab/"..v)
    end
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Registered Resource Files.")
end

if CLIENT then 
    MsgC(Color(255,0,0), [[
 _ _______                      _____ _          _              
| |__   __|                    / ____| |        | |             
| |  | | ___  __ _ _ __ ___   | (___ | | ___   _| | ___  _ __  
| |  | |/ _ \/ _` | '_ ` _ \   \___ \| |/ / | | | |/ _ \| '_ \ 
|_|  | |  __/ (_| | | | | | |  ____) |   <| |_| | | (_) | | | |  
(_)  |_|\___|\__,_|_| |_| |_| |_____/|_|\_\\__, |_|\___/|_| |_|
                                            __/ |               
                                           |___/                     
	]] ..  "\n")

    include(l"import.lua") 
 
    skylon_skylab_reset_imports()   
  
    -- Shared Init  
    import(l"shared/init/LuaExtras.lua")
    import(l"shared/init/selfcomputing.lua")
    import(l"shared/init/deceleration.lua")
    import(l"shared/Data/filetypes.lua")
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Loaded main modules.")
  

    -- Client Init
    import(l"client/modules/Cache.lua")

    import(l"client/init/clientsideconstructor.lua") 
    import(l"client/init/internaldispatcher.lua")
    import(l"client/init/livesnapshotcontroller.lua")

    import(l"client/modules/Ascii.lua")
    importFolder(l"client/modules/*")


    import(l"client/Derma/Elements/DSleekPanel.lua")
    import(l"client/Derma/Elements/DSleekButton.lua")
    import(l"client/Derma/Elements/DSleekTextbox.lua")  
    import(l"client/Derma/Elements/DSleekScrollbar.lua")

    import(l"client/Derma/Elements/Entry/Context.lua")
    import(l"client/Derma/Elements/Entry/SyntaxBox.lua")

    import(l"client/Derma/Elements/DSleekFilePreview.lua")
    import(l"client/Derma/Elements/DSleekFileInfo.lua")
    import(l"client/Derma/Elements/DSleekFileViewer.lua") 
    
     
    import(l"client/Derma/Elements/BetterLabels.lua")
    importFolder(l"client/Derma/Elements/*")
    import(l"client/Derma/UtilPopups.lua")
    import(l"client/Derma/Editor/Editor.lua")
    importFolder(l"client/Derma/*") 
    
    import(l"client/Styles/Controller.lua")
    importFolder(l"client/Styles/*")

    import(l"client/Syntax/Controller.lua")
    importFolder(l"client/Syntax/Profiles/*")

    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Imported Main Clientside Files.")

 
    -- Other Imports 
    importFolder(l"shared/*")
    importFolder(l"client/*")
    SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Imported Other Clientside Files.")

    SSLE.materials = {}

    local f, _ = file.Find("materials/skylab/*", "GAME")
    for _, v in pairs(f) do 
        local mat = Material(v, "smooth")
        if mat:IsError() == true then continue end 
        SSLE.materials[v:Split(".")[1]] = mat 
    end 
    function SSLE:GetMat(id, alt)
        if not id then return nil end 
        return self.materials[id] or alt 
    end 
end   