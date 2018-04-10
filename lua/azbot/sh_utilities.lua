function AzBot.GetTrajectories2DParams(g, initVel, distZ, distRad)
	local trajectories = {}
	local radix = initVel^4 - g*(g*distRad^2 + 2*distZ*initVel^2)
	
	if radix < 0 then return trajectories end
	local pitch = math.atan((initVel^2 - math.sqrt(radix)) / (g*distRad))
	local t1 = distRad / (initVel * math.cos(pitch))
	table.insert(trajectories, {g = g, initVel = initVel, pitch = pitch, t1 = t1})
	if radix > 0 then
		local pitch = math.atan((initVel^2 + math.sqrt(radix)) / (g*distRad))
		local t1 = distRad / (initVel * math.cos(pitch))
		table.insert(trajectories, {g = g, initVel = initVel, pitch = pitch, t1 = t1})
	end
	
	return trajectories
end

function AzBot.GetTrajectory2DPoints(trajectory, segments)
	trajectory.points = {}
	for i = 0, segments, 1 do
		local t = Lerp(i/segments, 0, trajectory.t1)
		local r = Vector(math.cos(trajectory.pitch)*trajectory.initVel*t, 0, math.sin(trajectory.pitch)*trajectory.initVel*t - trajectory.g/2*t^2)
		table.insert(trajectory.points, r)
	end
	
	return trajectory
end

function AzBot.GetTrajectories(initVel, r0, r1, segments)
	local g = 600 -- Hard coded acceleration, should be read from gmod later
	
	local distZ = r1.z - r0.z
	local distRad = math.sqrt((r1.x - r0.x)^2 + (r1.y - r0.y)^2)
	local yaw = math.atan2(r1.y - r0.y, r1.x - r0.x)
	
	local trajectories = AzBot.GetTrajectories2DParams(g, initVel, distZ, distRad)
	for i, trajectory in ipairs(trajectories) do
		trajectories[i].yaw = yaw
		-- Calculate 2D trajectory from parameters
		trajectories[i] = AzBot.GetTrajectory2DPoints(trajectory, segments)
		-- Rotate and move trajectory into 3D space
		for k, _ in ipairs(trajectory.points) do
			trajectory.points[k]:Rotate(Angle(0, math.deg(yaw), 0))
			trajectory.points[k]:Add(r0)
		end
	end
	
	return trajectories
end

-- Remove spectating and dead players
function AzBot.RemoveObsDeadTgts(tgts)
	return AzBot.From(tgts):Where(function(k, v) return IsValid(v) and v:GetObserverMode() == OBS_MODE_NONE and v:Alive() end).R
end