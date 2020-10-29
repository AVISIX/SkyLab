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

local self 	   = {}
local tonumber = tonumber
local type     = type

SSLE.GlobalConstructor (self, SSLE, "SSLE:T71CMCD - Internal")

function self:constructor()
	local InternalConstruction = SSLE ["SSLE:GeneralController [ctor()]"]:constructor ()
	self.Data 	= {}
	self.Buffer = {}
end

function self:DispatchReliableChannel (Ichannel, Signal, Packet)
	if not Ichannel or type (Ichannel) ~= "string" then
		if not Ichannel then 
			SSLE:Error ("SSLE:DispatchReliableChannel : IChannel is not specified.") 
			return 
		end
		SSLE:Error ("SSLE:DispatchReliableChannel : IChannel expected string, but received " .. type (Ichannel) .. ".")
		return 
	elseif type (Signal) ~= "boolean" then
		SSLE:Error ("SSLE:DispatchReliableChannel : Signal expected boolean, but received " .. type (Signal) .. ".")
		return
	elseif type (Packet) ~= "string" or Packet == nil then
		if Packet ~= nil then
			SSLE:Error ("SSLE:DispatchReliableChannel : Packet expected string, but received " .. type (Packet) .. ".")
			return
		end
		SSLE:Error ("SSLE:DispatchReliableChannel : Packet is unexpectedly short.")
		return
	end
	local Indexor   		= SSLE ["SSLE:GeneralController [ctor()]"].Compressor (Packet)
	local FinalBufferResult = Indexor
	SSLE ["SSLE:GeneralController [ctor()]"].Registering (Ichannel)
	SSLE ["SSLE:GeneralController [ctor()]"].Boolean (Signal)
	SSLE ["SSLE:GeneralController [ctor()]"].Header (FinalBufferResult:len())
	SSLE ["SSLE:GeneralController [ctor()]"].Buffer (FinalBufferResult, FinalBufferResult:len())
	SSLE ["SSLE:GeneralController [ctor()]"].Dispatch ()
end

function self:destructor()
	self.Data 	= nil
	self.Buffer = nil
end

function self:RegisterId()
	return "T71 - CMCD" or "Internal Dispatcher"
end

self:constructor()
SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Internal Dispatcher loaded successfully.")
-- invoke dtor() in the last subroutine class