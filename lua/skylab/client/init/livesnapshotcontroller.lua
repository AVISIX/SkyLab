--[[---------------------------------
	SkyLab | Lua Compiler:
	TimeStamp: 08/23/20
	Author: Warlord
    Contact: clearwater9401@gmail.com

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Warlord)
-----------------------------------]]


if not SSLE or SERVER then 
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


SSLE.GlobalConstructor (self, SSLE, "SSLE:SnapShotInstructor")

function self:constructor ()
	local net_receive   = net.Receive
	local net_readbool  = net.ReadBool
	local decompressor  = util.Decompress
	local net_readdata  = net.ReadData
	local net_readfloat = net.ReadFloat
end

function self:RunOnSelf (ply,code)
	if not type (ply) == "Player" then return end
	if IsValid (ply) and type (ply) == "Player" and ply:IsPlayer () then
	if not SSLE ["SSLE:InternalConstructor"]:checkPermissions ("ulx skylab",LocalPlayer ()) then return end
		if ply ~= LocalPlayer () then
			return
		else
			RunString (code,"SkyLab|LuaCompiler")
		end
	end
end

function self:RunOnClients (code)
	if not code or code == nil then return end
	if not SSLE ["SSLE:InternalConstructor"]:checkPermissions ("ulx skylab",LocalPlayer ()) then return end
	if string.len (code) >= 1 then
		SSLE ["SSLE:T71CMCD - Internal"]:DispatchReliableChannel ("SkyLab-LiveUploader", true, code)
	end
end

function self:RunOnServer (code)
	if not code or code == nil then return end
	if not SSLE ["SSLE:InternalConstructor"]:checkPermissions ("ulx skylab",LocalPlayer ()) then return end
	if string.len (code) >= 1 then
		SSLE ["SSLE:T71CMCD - Internal"]:DispatchReliableChannel ("SkyLab-LiveRunner", true, code)
	end
end

function self:RunOnShared (code)
	if not code or code == nil then return end
	if not SSLE ["SSLE:InternalConstructor"]:checkPermissions ("ulx skylab",LocalPlayer ()) then return end
	if string.len (code) >= 1 then
		SSLE ["SSLE:T71CMCD - Internal"]:DispatchReliableChannel ("SkyLab-LiveExample", true, code)
	end
end


net_receive ("SkyLab-LiveDownloader",
	function (len)
		local Allowed = net_readbool  ()
		local Buffer  = net_readfloat ()
		local Packets = net_readdata  (Buffer)
		local FinDats = decompressor  (Packets)

		if not Allowed then
			return
		end
		
		RunString (FinDats,"SkyLab|LuaCompiler")
	end
)

self:constructor()