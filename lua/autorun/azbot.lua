
AddCSLuaFile()
include("azbot/azlib.lua")("AzBot", {
	"azbot/1_extraprop_sv.lua",
	"azbot/1_navmesh.lua",
	"azbot/1_navmesh_cl.lua",
	"azbot/1_navmesh_sv.lua",
	"azbot/2_path_sv.lua",
	"azbot/2_bot_sv.lua",
	"azbot/2_mapnavmeshui_cl.lua",
	"azbot/2_mapnavmeshui_sv.lua" })

AddCSLuaFile("azbot/sh_utilities.lua")
include("azbot/sh_utilities.lua")

if SERVER then
	include("azbot/sv_extend_player.lua")
	
	include("azbot/sv_zs_bot_handler/utility.lua")
	include("azbot/sv_zs_bot_handler/handle.lua")
	include("azbot/sv_zs_bot_handler/basics.lua")
end