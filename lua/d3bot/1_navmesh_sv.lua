
return function(lib)
	lib.MapNavMeshDir = "d3bot/navmesh/map/"
	
	function lib.GetMapNavMeshPath(mapName)
		return lib.MapNavMeshDir .. mapName .. ".txt"
	end
	function lib.GetMapNavMeshParamsPath(mapName)
		return lib.MapNavMeshDir .. mapName .. ".params.txt"
	end
	lib.MapNavMeshPath = lib.GetMapNavMeshPath(game.GetMap())
	lib.MapNavMeshParamsPath = lib.GetMapNavMeshParamsPath(game.GetMap())
	
	function lib.CheckMapNavMesh(mapName)
		return file.Exists(lib.GetMapNavMeshPath(mapName), "DATA")
	end
	
	util.AddNetworkString(lib.MapNavMeshNetworkStr)
	function lib.UploadMapNavMesh(plOrPls)
		local rawData = lib.MapNavMesh:Serialize()
		local dataLen = rawData:len()
		local maxSize = 2 ^ 16

		for i = maxSize, dataLen + maxSize, maxSize do
			local subDataComp = util.Compress(string.sub(rawData, i - maxSize + 1, dataLen < maxSize and dataLen or i))
			subDataComp = subDataComp or ""

			local subDataCompLen = subDataComp:len()
			
			net.Start(lib.MapNavMeshNetworkStr)
			net.WriteBool(i >= dataLen)
			net.WriteUInt(subDataCompLen, 16)
			net.WriteData(subDataComp, subDataCompLen)
			net.Send(plOrPls)
		end
	end
	
	file.CreateDir(lib.MapNavMeshDir)
	function lib.SaveMapNavMesh()
		file.Write(lib.MapNavMeshPath, lib.MapNavMesh:SerializeSorted())
		file.Write(lib.MapNavMeshParamsPath, lib.MapNavMesh:ParamsSerializeSorted())
	end
	function lib.SaveMapNavMeshParams()
		file.Write(lib.MapNavMeshParamsPath, lib.MapNavMesh:ParamsSerializeSorted())
	end
	function lib.LoadMapNavMesh()
		local mapNavMesh
		lib.TryCatch(function()
			mapNavMesh = lib.DeserializeNavMesh(file.Read(lib.MapNavMeshPath) or "")
		end, function(errorMsg)
			mapNavMesh = lib.NewNavMesh()
			lib.LogError("Couldn't load " .. lib.MapNavMeshDir .. " (using empty nav mesh instead):\n" .. errorMsg)
		end)
		lib.TryCatch(function()
			mapNavMesh:DeserializeNavMeshParams(file.Read(lib.MapNavMeshParamsPath) or "")
		end, function(errorMsg)
			lib.LogError("Couldn't load params for " .. lib.MapNavMeshDir .. ":\n" .. errorMsg)
		end)
		lib.MapNavMesh = mapNavMesh
	end
	lib.LoadMapNavMesh()
end
