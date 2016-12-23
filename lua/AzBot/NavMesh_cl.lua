
return function(lib)
	net.Receive(lib.MapNavMeshNetworkStr, function() lib.MapNavMesh = lib.DeserializeNavMesh(net.ReadString()) end)
end
