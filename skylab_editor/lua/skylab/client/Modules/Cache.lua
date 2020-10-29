--[[
    Cache Library to store data without using file lib

    Author: Sixmax
    Contact: sixmax@gmx.de

    Copyright, all rights reserved

    License: CC BY-NC-ND 3.0
    Licensed to Team Skylon (Sixmax & Evaneos[KOWAR])
]]

if not SSLE or SERVER then 
	return 
end

-- Uncomment this to get SQL Errors again 
--sql.m_strError = nil
--setmetatable(sql,{__newindex = function(t,k,v) if k == "m_strError" and v then print("[SQL Error] "..v) end end})

--[[

    All this can most likely be done much better, if you can do it better, do it. I never touched SQLite before doing this.

]]


local _gid = "SkyLab Editor Global Cache"
local gid = sql.SQLStr(_gid)
local cache = {gid=gid}

local function check()
    if sql.TableExists(_gid) == false then 
        sql.Query("CREATE TABLE " .. gid .. "(key TEXT, value TEXT)")
    end    
end

-- Check if a key in the table exists 
function cache:ValueExists(key)
    if not key then return end 

    check()

    local r = sql.Query("SELECT key FROM " .. gid .. " WHERE key=" .. sql.SQLStr(key))

    if not r then 
        return false 
    end 

    return (type(r) == "table" and true or r)
end

-- Set a value for a key 
function cache:SetValueForKey(key, value)
    if not key or not value then return end 

    check()

    if type(value) == "table" then 
        value = util.TableToJSON(value)
    elseif type(value) ~= "string" then 
        value = tostring(value) 
    end

    if self:ValueExists(key) == false then 
        sql.Query("INSERT INTO "..gid.."(key, value) VALUES ("..sql.SQLStr(key)..","..sql.SQLStr(value)..")")
        return 
    end 

    sql.Query("UPDATE "..gid.." SET value="..sql.SQLStr(value).." WHERE key="..sql.SQLStr(key))
end         

-- Get a value for a key 
function cache:GetValueForKey(key)
    if not key then return "" end 

    check()

    return (((sql.Query("SELECT value FROM " .. gid .. " WHERE key=" .. sql.SQLStr(key)) or {})[1] or {}).value) or ""
end 

-- Combines Set & Get into 1
function cache:Value4Key(key, value)
    if not key then return end 

    if not value then 
        return self:GetValueForKey(key)
    end

    self:SetValueForKey(key, value)
end

-- Delete a value for a key 
function cache:DeleteValueForKey(key)
    if not key then return end 
    
    check()

    if self:ValueExists(key) == true then 
        sql.Query("DELETE FROM " .. gid .. " WHERE key=" .. sql.SQLStr(key))
    end
end

function cache:Clear()
    check()
    sql.Query("DROP TABLE " .. gid)
end

-- Get the global cache table
function cache:GetAll()
    check()
    return sql.Query("SELECT * FROM " .. gid) or {}
end  

SSLE.modules = SSLE.modules or {}
SSLE.modules.cache = cache  