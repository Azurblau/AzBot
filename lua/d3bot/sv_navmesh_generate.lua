local function round(num) return math.Round(num * 10) / 10 end

local function setPos(node, pos)
	node:SetParam("X", round(pos.x))
	node:SetParam("Y", round(pos.y))
	node:SetParam("Z", round(pos.z))
end

function D3bot.ConvertNavmesh(callback)
	if D3bot.StartedConversion then return end
	local co = coroutine.create(function()
		D3bot.StartedConversion = true
		PrintMessage(HUD_PRINTTALK, "Starting navmesh conversion...")

		local mapNavMesh = D3bot.NewNavMesh()
	
		local allAreas = navmesh.GetAllNavAreas()

		for k, area in ipairs(allAreas) do
			local node = mapNavMesh:NewNode()
			setPos(node, area:GetCenter())

			local northWestCorner = area:GetCorner(0)
			local southEastCorner = area:GetCorner(2)

			node:SetParam("AreaXMin", northWestCorner.x)
			node:SetParam("AreaYMin", northWestCorner.y)
			node:SetParam("AreaXMax", southEastCorner.x)
			node:SetParam("AreaYMax", southEastCorner.y)
		end

		PrintMessage(HUD_PRINTTALK, "Nodes placed.")

		for _, area in ipairs(allAreas) do
			for k, neighbor in ipairs(area:GetAdjacentAreas()) do
				if math.abs(area:GetCenter().z - neighbor:GetCenter().z) <= 68 then

					local selectedNode = mapNavMesh:GetNearestNodeOrNil(area:GetCenter())

					if selectedNode then
						local node = mapNavMesh:GetNearestNodeOrNil(neighbor:GetCenter())

						if node then
							mapNavMesh:ForceGetLink(selectedNode, node)
						end
					end
				end
				
				if (k % 4) == 0 then
					coroutine.yield()
				end
			end
		end

		PrintMessage(HUD_PRINTTALK, "Links connected.")
		PrintMessage(HUD_PRINTTALK, " ")

		D3bot.MapNavMesh = mapNavMesh

		PrintMessage(HUD_PRINTTALK, "Complete!")
		PrintMessage(HUD_PRINTTALK, " ")
		PrintMessage(HUD_PRINTTALK, "This mesh does not autosave. Save this manually.")
		PrintMessage(HUD_PRINTTALK, "Also, make sure that D3bot.ValveNavOverride in sv_config.lua is set to false.")

		hook.Remove("ConverterCoroutineStep")

		D3bot.StartedConversion = false

		if callback then
			callback()
		end
	end)

	hook.Add("Think", "ConverterCoroutineStep", function()
		coroutine.resume(co)
	end)
end

function D3bot.GenerateAndConvertNavmesh(initPos, onGround, callback)
	if not navmesh.IsLoaded() then
		navmesh.Load()
	end
	
	if not navmesh.IsLoaded() then
		if not onGround then
			PrintMessage(HUD_PRINTTALK, "Please stand on flat/level terrain in the playable area before starting.")
			return
		end
		
		PrintMessage(HUD_PRINTTALK, "Starting Valve navmesh generation... (Be patient this takes a while!)")
		PrintMessage(HUD_PRINTTALK, "Be sure to run GenerateMesh again after the map change.")
		PrintMessage(HUD_PRINTTALK, "You may check the finished mesh by typing \"nav_edit 1\" in the developer console with cheats enabled in a non-dedicated server")
		PrintMessage(HUD_PRINTTALK, "See the valve developer wiki for more information, especially if your mesh is sub-optimal: https://developer.valvesoftware.com/wiki/Nav_Mesh_Editing")
		PrintMessage(HUD_PRINTTALK, "It is recommended to check before full conversion.")
		
		navmesh.AddWalkableSeed(initPos, Vector(0, 0, 1))
		navmesh.BeginGeneration()
	end

	timer.Simple(1, function()
		if not navmesh.IsGenerating() then
			D3bot.ConvertNavmesh(callback)
		end
	end)
end

concommand.Add("d3bot_nav_generate", function(ply, str, args, argStr)
	if not ply:IsValid() or not ply:IsSuperAdmin() then return end

	D3bot.GenerateAndConvertNavmesh(ply:GetPos(), ply:IsOnGround(), function()
		D3bot.UpdateMapNavMeshUiSubscribers()
	end)
end)
