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

---Runs a benchmark and prints the results.
---@param func function
local function test(func)
	local runtime, displayName = func()

	print(string.format("Benchmarking %q: %.3f ms per call.", displayName, runtime*1000))
end

-- Run tests.
--test(benchmarkGetNearestNodeOrNil)
