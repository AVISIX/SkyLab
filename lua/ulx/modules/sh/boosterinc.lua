if not ulx then return end 

-- Computer written by Cardinal Global Exporter.exe
-- Timestamp: 08/23/20
local CATEGORY = "SkyLab"

local function SkyLab_lua( calling_ply )
	if not calling_ply:IsValid() then
		Msg ( "SkyLab | LuaCompiler menu cannot be opened from the server." )
		return
	end

	--elseif calling_ply:IsAdmin() or calling_ply:IsSuperAdmin() then
		calling_ply:ConCommand( "SkyLab_lua_launch" )
--	else
--		MsgC( Color(255,0,0), calling_ply:GetName() .. " is attempting to open SkyLab | LuaCompiler GUI without administrator privileges." )
--	end
end

local SkyLabUlxCompatibilities = ulx.command( CATEGORY, "ulx skylab", SkyLab_lua, "!skylab", true )
--SkyLabUlxCompatibilities:defaultAccess( ULib.ACCESS_ADMIN )
SkyLabUlxCompatibilities:help( "Open SkyLab | LuaCompiler panel." )