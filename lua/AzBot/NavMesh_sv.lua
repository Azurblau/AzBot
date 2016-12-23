
return function(lib)
	lib.MapNavMeshDir = "azbot/navmesh/map/"
	lib.MapNavMeshPath = lib.MapNavMeshDir .. game.GetMap() .. ".txt"
	
	util.AddNetworkString(lib.MapNavMeshNetworkStr)
	function lib.UploadMapNavMesh(plOrPls) net.Start(lib.MapNavMeshNetworkStr) net.WriteString(lib.MapNavMesh:Serialize()) net.Send(plOrPls) end
	
	file.CreateDir(lib.MapNavMeshDir)
	function lib.SaveMapNavMesh() file.Write(lib.MapNavMeshPath, lib.MapNavMesh:Serialize()) end
	function lib.LoadMapNavMesh()
		local mapNavMesh
		lib.TryCatch(function()
			mapNavMesh = lib.DeserializeNavMesh(file.Read(lib.MapNavMeshPath) or "")
		end, function(errorMsg)
			mapNavMesh = lib.NewNavMesh()
			lib.LogError("Couldn't load " .. lib.MapNavMeshDir .. " (using empty nav mesh instead):\n" .. errorMsg)
		end)
		lib.MapNavMesh = mapNavMesh
	end
	lib.LoadMapNavMesh()
end
