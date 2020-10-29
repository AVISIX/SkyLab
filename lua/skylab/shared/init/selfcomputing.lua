--[[---------------------------------
	SkyLab | Lua Compiler:
	Client and Server;
	TimeStamp: 08/23/20
	Author: Warlord
    Contact: clearwater9401@gmail.com

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Warlord)
-----------------------------------]]

SSLE = {}

local self		  = {}
local tonumber 	  = tonumber
local type     	  = type
local error		  = error
local pairs		  = pairs
local Msg		  = Msg
local MsgC		  = MsgC
self.StartupBench = SysTime()

function SSLE.GlobalConstructor (SignalAccelerator, SignalFilter, ISaveMap)
    SignalFilter [ISaveMap] = SignalAccelerator
end

function SSLE:Error (Data)
	if not Data then return end
	if type (Data) ~= "string" then return end
	error (Data)
end

function self:ImpulseReducer (num, idp)
	local power = 10 ^ (idp or 0)
	return math.floor (num * power + 0.5) / power
end

function self:ReliableChannel (...)
	if not SSLE then
		error ("SkyLab - Lua Compiler : ReliableChannel Not Initialized.")
	end
	MsgC(
	Color(65, 185, 255) , "SkyLab - LuaCompiler ",
	Color(236, 240, 241), "[" .. self:ImpulseReducer (self.StartupBench, 3) .. "] | ",
	Color(255, 20, 21), ... 
	) 
	Msg ("\n")
	Msg ("\n")
	self.StartupBench = SysTime()
end

function self:checkPermissions (cmd, ply)	
	if ULib then 
		for _,group in pairs(ULib.ucl.groups) do 
			local Usergroup = ply:GetUserGroup()	
			
			if group == Usergroup then 
				for _,command in pairs(b.allow) do
					if command == cmd then			
						return true
					end
				end
			end
		end 
	
		for validCmds, data in pairs (ULib.cmds.translatedCmds) do 
			local opposite = data.opposite
			
			if opposite ~= validCmds and (ply:query (data.cmd) or (opposite and ply:query (opposite))) then
				if validCmds == cmd then 
					return true
				end
			end
		end
	end
	
	if ply:IsSuperAdmin() or ply:IsAdmin() then 
		return true
	end
	
	return false
end

SSLE.GlobalConstructor (self, SSLE, "SSLE:InternalConstructor")
