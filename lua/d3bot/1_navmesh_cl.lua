
return function(lib)
	local buffer = ""

	net.Receive(lib.MapNavMeshNetworkStr, function()
		local finished = net.ReadBool()
		local data = net.ReadData(net.ReadUInt(16))

		if data then
			buffer = buffer .. util.Decompress(data)
		end
		
		if finished then
			lib.MapNavMesh = lib.DeserializeNavMesh(buffer) or {}
			buffer = ""
		end
	end)
end
