if not SSLE or CLIENT then 
	return 
end

local self 	    = {}
local tonumber  = tonumber
local type      = type
local ipairs    = ipairs
local RunString = RunString

SSLE.GlobalConstructor (self, SSLE, "SSLE:Acceleration")

util.AddNetworkString ("SkyLab-LiveUploader")
util.AddNetworkString ("SkyLab-LiveDownloader")
util.AddNetworkString ("SkyLab-LiveRunner")
util.AddNetworkString ("SkyLab-LiveExample")

net.Receive("SkyLab-LiveRunner",
	function (len,ply)
		local Name 	  = ply:GetName   ()
		local SteamId = ply:SteamID   ()
		local Allowed = net.ReadBool  ()
		local Buffer  = net.ReadFloat ()
		local Packets = util.Decompress (net.ReadData  (Buffer))
		
		if not Allowed or not ply:IsSuperAdmin () then
			return
		end
		
		SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Received code ran on Server from: ",Color(0,255,0),Name .. "(" .. SteamId .. ").")
		RunString (Packets,"SkyLab|LuaCompiler")
		
	end
)

net.Receive("SkyLab-LiveUploader",
	function (len,ply)
		local Name 	  = ply:GetName   ()
		local SteamId = ply:SteamID   ()
		local Allowed = net.ReadBool  ()
		local Buffer  = net.ReadFloat ()
		local Packets = net.ReadData  (Buffer)
		
		if not Allowed or not ply:IsSuperAdmin () then
			return
		end
		
		SSLE ["SSLE:InternalConstructor"]:ReliableChannel ("Received code launched on all Clients from: ",Color(0,255,0),Name .. "(" .. SteamId .. ").")
		
		net.Start 	   ("SkyLab-LiveDownloader")
		net.WriteBool  (true)
		net.WriteFloat (Packets:len())
		net.WriteData  (Packets, Packets:len())
		net.Broadcast  ()
		
	end
)