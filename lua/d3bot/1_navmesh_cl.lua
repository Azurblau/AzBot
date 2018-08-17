
return function(lib)
	net.Receive(lib.MapNavMeshNetworkStr, function()
		local data = net.ReadData(net.ReadUInt(32))
		if data ~= "" then data = util.Decompress(data) end
		lib.MapNavMesh = lib.DeserializeNavMesh(data)
	end)
end
