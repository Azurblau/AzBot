-- Temporary code to overwrite the GetNearestNodeOrNil method of the navmesh.

--[[local fallback = D3bot.NavMeshMeta.__index
function fallback:GetNearestNodeOrNil(pos)
	local nearestNodeOrNil
	local distSqrMin = math.huge
	for id, node in pairs(self.NodeById) do
		local nodePos = node.Pos
		if node.HasArea then
			local params = node.Params
			nodePos = Vector(math.Clamp(pos.x, params.AreaXMin, params.AreaXMax), math.Clamp(pos.y, params.AreaYMin, params.AreaYMax), nodePos.z)
		end
		local distSqr = pos:DistToSqr(nodePos)
		if distSqr < distSqrMin then
			nearestNodeOrNil = node
			distSqrMin = distSqr
		end
	end
	return nearestNodeOrNil
end

local mathMin = math.min
local mathMax = math.max
local mathSqrt = math.sqrt

---Returns the node that is closest to the given position.
---@param pos GVector
---@return any|nil
function fallback:GetNearestNodeOrNil(pos)
	-- Optimization notes:
	-- - We don't want to use vectors as they would disallow specific optimizations. Also, creating vectors is slow. LuaJIT can't optimize any calls on them, as they are userdata objects outside of the Lua runtime.
	-- - Put some math functions into upvalues, as the optimizer then can be sure the function doesn't change between calls.
	-- - Sieve out nodes before calculating the squared distance (via non squared distance).

	-- Benchmarks:
	-- Map: zs_infected_square_v1
	-- 2020-06-23: ~1.6 ms per call.
	-- 2022-09-23: ~

	local nearestNodeOrNil

	-- Current search sphere around pos.
	local distSqrMin = math.huge -- The squared distance to the closest node.
	local distMin    = math.huge -- The distance to the closest node.
	local distMinNeg = -distMin -- The negated distance to the closest node.

	local posX, posY, posZ = pos:Unpack()

	for id, node in pairs(self.NodeById) do
		local nodeX, nodeY, nodeZ = node.Pos:Unpack() -- This is unfortunately a point where anything like math.min could be modified. Therefore we need to put such references into upvalues.

		if node.HasArea then
			local params = node.Params
			nodeX = mathMin(mathMax(posX, params.AreaXMin), params.AreaXMax)
			nodeY = mathMin(mathMax(posY, params.AreaYMin), params.AreaYMax)
		end

		-- Sieve out nodes that definitely lie outside the search sphere.
		-- This is the same as checking against bounding boxes of nodes that are extended by the current distMin.
		local diffX = posX - nodeX
		if diffX < distMin and diffX > distMinNeg then
			local diffY = posY - nodeY
			if diffY < distMin and diffY > distMinNeg then
				local diffZ = posZ - nodeZ
				if diffZ < distMin and diffZ > distMinNeg then
					local distSqr = diffX ^ 2 + diffY ^ 2 + diffZ ^ 2
					if distSqr < distSqrMin then
						nearestNodeOrNil = node
						distSqrMin = distSqr
						distMin = mathSqrt(distSqr) -- We need the non squared distance to quickly sieve out nodes.
						distMinNeg = -distMin
					end
				end
			end
		end
	end

	return nearestNodeOrNil
end]]

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
