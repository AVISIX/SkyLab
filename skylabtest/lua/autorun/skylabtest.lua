local function l(p) return "slabtest/" .. p end

if SERVER then 

    print("AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA A")

    include(l"import.lua")

    AddCSLuaFile()

    addCSFolder(l(""))
end 


if CLIENT then 
    SkyLabTest = {}

    SkyLabTest.lua = include(l"client/lua.lua")
    SkyLabTest.tokentable = include(l"client/TokenTable.lua")
 
    include(l"client/Editor.lua")
    include(l"client/RichTextBox.lua")

    include(l"client/Tester.lua")

    print("done loading skylab test")
end