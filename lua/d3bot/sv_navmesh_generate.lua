local function round(num) return math.Round(num * 10) / 10 end

local function setPos(node, pos)
	node:SetParam("X", round(pos.x))
	node:SetParam("Y", round(pos.y))
	node:SetParam("Z", round(pos.z))
end

function D3bot.ConvertNavmesh()
	print("Starting navmesh conversion...")

	local mapNavMesh = D3bot.NewNavMesh()

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

	print("Nodes placed.")

	for _, area in ipairs(navmesh.GetAllNavAreas()) do
		for _, neighbor in ipairs(area:GetAdjacentAreas()) do
			if math.abs(area:GetCenter().z - neighbor:GetCenter().z) <= 68 then

				local selectedNode = mapNavMesh:GetNearestNodeOrNil(area:GetCenter())

				if selectedNode then
					local node = mapNavMesh:GetNearestNodeOrNil(neighbor:GetCenter())

					if node then
						mapNavMesh:ForceGetLink(selectedNode, node)
					end
				end
			end
		end
	end

	print("Links connected.")

	D3bot.MapNavMesh = mapNavMesh

	print("Complete!")
	print("This mesh does not autosave. Save this manually.")
	print("In order to use the converted navmesh, reload the map.")
	print("Also, make sure that D3bot.ValveNavOverride in sv_config.lua is set to false.")
end

function D3bot.GenerateAndConvertNavmesh(initPos)
	navmesh.Load()
	
	if not navmesh.IsLoaded() then
		print("Starting Valve navmesh generation... (Be patient this takes a while!)")
		print("Be sure to run this again after the map change.")
		navmesh.AddWalkableSeed(initPos, Vector(0, 0, 1))
		navmesh.BeginGeneration()
	end

	timer.Simple(1, function()
		if not navmesh.IsGenerating() then
			D3bot.ConvertNavmesh()
		end
	end)
end

concommand.Add("d3bot_nav_generate", function(ply, str, args, argStr)
	if not ply:IsValid() or not ply:IsSuperAdmin() then return end

	D3bot.GenerateAndConvertNavmesh(ply:GetPos())
	D3bot.UpdateMapNavMeshUiSubscribers()
end)
