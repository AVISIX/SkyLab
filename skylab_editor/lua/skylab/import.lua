--[[
    Simple Importing Framework

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

-- This Lib is quite old so DONT FUCKING TOUCH IT UNLESS U KNOW WHAT UR DOING!!!!!

SkyLon_Import_Lib_Debug = true 

local imports = {}

function skylon_skylab_reset_imports()
	imports = {}	
	imports.client = {}
	imports.server = {}
end

skylon_skylab_reset_imports()

local function msg(text)
	if SkyLon_Import_Lib_Debug == false then return end 
	MsgC(Color(0,255,0), "> ", Color(255,255,255), text .. "\n")
end

-- Add Clientside File
function addCSFile(file)
	if file == "" then return end
	file = file or "this"
	if file == "this" then
		AddCSLuaFile()
		return
	end
	AddCSLuaFile(file)
	msg(file)
end

-- Add Clientside Folder
function addCSFolder(folder)
	if folder == "" then return end
	local dirs = string.Split(folder, "/")
	if dirs == nil then return end
	if not (#dirs == 0) then
		local last = dirs[#dirs] 
		if not (last == "*") then
			if last == "" then
				folder = folder .. "*"
			else
				folder = folder .. "/*"
			end
		end
	else
		folder = folder .. "/*"
	end
	local files, directories = file.Find(folder, "LUA")
	if not (files == nil) then
		if table.Count(files) > 0 then
			for _, v in pairs(files) do
				local path = string.Replace(folder, "*", "") .. v
				addCSFile(path)
			end
		end
	end
	if not (directories == nil) then
		if table.Count(directories) > 0 then
			for _, v in pairs(directories) do
				local path = string.Replace(folder, "*", "") .. v
				if not (path == nil) then
					addCSFolder(path)
				end
			end
		end 
	end
end

-- Import File
function import(path)
	if path == "" then return end
	if CLIENT then 
		if imports.client[string.lower(path)] then return end 
		imports.client[string.lower(path)] = 1
	else
		if imports.server[string.lower(path)] then return end 
		imports.server[string.lower(path)] = 1
	end
	msg(path)
	include(path)	
end

-- Import Folder
function importFolder(folder)
	if folder == "" then return end
	local dirs = string.Split(folder, "/")
	if dirs == nil then return end
	if not (#dirs == 0) then
		local last = dirs[#dirs] 
		if not (last == "*") then
			if last == "" then
				folder = folder .. "*"
			else
				folder = folder .. "/*"
			end
		end
	else
		folder = folder .. "/*"
	end
	local files, directories = file.Find(folder, "LUA")
	if not (files == nil) then
		if table.Count(files) > 0 then
			for _, v in pairs(files) do
				local path = string.Replace(folder, "*", "") .. v
				import(path)
			end
		end
	end
	if not (directories == nil) then
		if table.Count(directories) > 0 then
			for _, v in pairs(directories) do
				local path = string.Replace(folder, "*", "") .. v
				if not (path == nil) then
					importFolder(path)
				end
			end
		end 
	end
end