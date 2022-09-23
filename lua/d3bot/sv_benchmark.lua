---This will benchmark GetNearestNodeOrNil on the current navmesh.
---It will sample random points around the origin.
---@return number runtime
---@return string displayName
local function benchmarkGetNearestNodeOrNil()
	local startTime = SysTime()
	local iterations = 1000
	local displayName = "GetNearestNodeOrNil"

	local navMesh = D3bot.MapNavMesh

	for _ = 1, iterations do
		local pos = VectorRand(-5000, 5000)

		local node = navMesh:GetNearestNodeOrNil(pos)
	end

	local endTime = SysTime()
	return (endTime - startTime) / iterations, displayName
end

---This will benchmark GetBestMeshPathOrNil on the current navmesh.
---Only works correctly if zs_infected_square_v1 is loaded.
---@return number runtime
---@return string displayName
local function benchmarkGetBestMeshPathOrNil()
	local startTime = SysTime()
	local iterations = 1
	local displayName = "GetBestMeshPathOrNil"

	local pathCostFunction = function(node, linkedNode, link)
		local linkMetadata = D3bot.LinkMetadata[link]
		local linkPenalty = linkMetadata and linkMetadata.ZombieDeathCost or 0
		return linkPenalty * 1
	end

	local abilities = {Walk = true}

	local navMesh = D3bot.MapNavMesh
	local startNode = navMesh.NodeById[32]
	local endNode = navMesh.NodeById[866]

	local path = D3bot.GetBestMeshPathOrNil(startNode, endNode, pathCostFunction, nil, abilities)

	local endTime = SysTime()
	return (endTime - startTime) / iterations, displayName
end

---Runs a benchmark and prints the results.
---@param func function
local function test(func)
	local runtime, displayName = func()

	print(string.format("Benchmarking %q: %.3f ms per call.", displayName, runtime*1000))
end

-- Run tests.
--test(benchmarkGetNearestNodeOrNil)
--test(benchmarkGetBestMeshPathOrNil)
