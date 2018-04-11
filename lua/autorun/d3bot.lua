
AddCSLuaFile()
include("d3bot/azlib.lua")("D3bot", {
	"d3bot/1_extraprop_sv.lua",
	"d3bot/1_navmesh.lua",
	"d3bot/1_navmesh_cl.lua",
	"d3bot/1_navmesh_sv.lua",
	"d3bot/2_path_sv.lua",
	"d3bot/2_bot_sv.lua",
	"d3bot/2_mapnavmeshui_cl.lua",
	"d3bot/2_mapnavmeshui_sv.lua" })

AddCSLuaFile("d3bot/sh_utilities.lua")
include("d3bot/sh_utilities.lua")

if SERVER then
	include("d3bot/sv_extend_player.lua")
	
	if engine.ActiveGamemode() == "zombiesurvival" then
		include("d3bot/sv_zs_bot_handler/handle.lua")
		include("d3bot/sv_zs_bot_handler/basics.lua")
	end
end