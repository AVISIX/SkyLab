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

SSLE.GlobalConstructor (self, SSLE, "SSLE:GeneralController [ctor()]")


function self:constructor ()
	self.Registering = net.Start
	self.Boolean	 = net.WriteBool
	self.String		 = net.WriteString
	self.Dispatch    = net.SendToServer
	self.Compressor  = util.Compress
	self.Decompress  = util.Decompress
	self.ConvertTTJ  = util.TableToJSON
	self.ConvertJTT  = util.JSONToTable
	self.Header		 = net.WriteFloat
	self.Buffer		 = net.WriteData
	self.AddReceiver = net.Receive
	self.Entry		 = net.ReadBool
	self.RHeader	 = net.ReadFloat
	self.RBuffer     = net.ReadData
end

function self:destructor ()
	self.Registering = nil
	self.Boolean	 = nil
	self.String		 = nil
	self.Dispatch    = nil
	self.Compressor  = nil
	self.ConvertTTJ  = nil
	self.ConvertJTT  = nil
	self.Header		 = nil
	self.Buffer		 = nil
end