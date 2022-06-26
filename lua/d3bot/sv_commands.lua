local function round(num) return math.Round(num * 10) / 10 end
	
local function setPos(node, pos)
	node:SetParam("X", round(pos.x))
	node:SetParam("Y", round(pos.y))
	node:SetParam("Z", round(pos.z))
end

local function convert_navmesh()
	Msg("Starting namvsh conversion...")

	local mapNavMesh = D3bot.MapNavMesh

	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		local node = mapNavMesh:NewNode()
		setPos(node, area:GetCenter())

		local northWestCorner = area:GetCorner(0)
		local southEastCorner = area:GetCorner(2)

		node:SetParam("AreaXMin", northWestCorner.x)
		node:SetParam("AreaYMin", northWestCorner.y)
		node:SetParam("AreaXMax", southEastCorner.x)
		node:SetParam("AreaYMax", southEastCorner.y)
	end

	Msg("Nodes placed.")

	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		for _, neighbor in ipairs(area:GetAdjacentAreas()) do
			if math.abs(area:GetCenter().z - neighbor:GetCenter().z) > 68 then continue end
			
			local selectedNode = mapNavMesh:GetNearestNodeOrNil(area:GetCenter())
			
			if selectedNode then
				local node = mapNavMesh:GetNearestNodeOrNil(neighbor:GetCenter())

				if node then
					mapNavMesh:ForceGetLink(selectedNode, node)
				end
			end
		end
	end

	Msg("Links connected.")

	D3bot.UpdateMapNavMeshUiSubscribers()
	
	Msg("Complete!")
	Msg("This mesh does not autosave. Save this manually.")
end

concommand.Add("d3bot_nav_generate", function(ply, str, args, argStr)
	if ply:IsValid() and not ply:IsSuperAdmin() then return end
	
	navmesh.Load()
	
	if not navmesh.IsLoaded() then
		Msg("Starting Valve navmesh generation... (Be patient this takes a while!)")
		Msg("Be sure to run this again after the map change.")
		navmesh.AddWalkableSeed(ply:GetPos(), Vector(0, 0, 1))
		navmesh.BeginGeneration()
	end

	timer.Simple(1, function()
		if not navmesh.IsGenerating() then
			convert_navmesh()
		end
	end)
end)
