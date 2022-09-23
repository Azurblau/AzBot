local mathMax = math.max
local mathHuge = math.huge
local tableInsert = table.insert

---Returns the best path (or nil if there is no possible path) between startNode and endNode.
---@param startNode any
---@param endNode any
---@param pathCostFunction function|nil
---@param heuristicCostFunction function|nil
---@param abilities any|nil
---@return any|nil
function D3bot.GetBestMeshPathOrNil(startNode, endNode, pathCostFunction, heuristicCostFunction, abilities)
	-- See: https://en.wikipedia.org/wiki/A*_search_algorithm

	-- Benchmarks:
	-- Navmesh: zs_infected_square_v1
	-- CPU: Intel(R) Core(TM) i5-10600K CPU @ 4.10GHz
	-- 2020-06-23 (769f186): ~4.95 ms per call.
	-- 2022-09-24 (       ): ~4.45 ms per call.

	local minimalTotalPathCostByNode = {}
	local minimalPathCostByNode = { [startNode] = 0 }

	local entranceByNode = {}

	local evaluationNodeQueue = D3bot.NewSortedQueue(function(nodeA, nodeB)
		return (minimalTotalPathCostByNode[nodeA] or mathHuge) > (minimalTotalPathCostByNode[nodeB] or mathHuge)
	end)
	evaluationNodeQueue:Enqueue(startNode)

	while true do
		local node = evaluationNodeQueue:Dequeue()
		if not node then return end

		if node == endNode then
			local path = { node }
			while true do
				node = entranceByNode[node]
				if not node then break end
				tableInsert(path, 1, node)
			end
			return path
		end

		for linkedNode, link in pairs(node.LinkByLinkedNode) do
			local linkedNodeParams = linkedNode.Params
			local linkParams = link.Params

			local blocked = false
			if linkedNodeParams.Condition == "Unblocked" or linkedNodeParams.Condition == "Blocked" then
				local ents = ents.FindInBox(linkedNode.Pos + D3bot.NodeBlocking.mins, linkedNode.Pos + D3bot.NodeBlocking.maxs)
				for _, ent in ipairs(ents) do
					if D3bot.NodeBlocking.classes[ent:GetClass()] then blocked = true; break end
				end
				if linkedNodeParams.Condition == "Blocked" then blocked = not blocked end
			end

			-- Block pathing if the wave is outside of the interval [BlockBeforeWave, BlockAfterWave].
			if linkedNodeParams.BlockBeforeWave and tonumber(linkedNodeParams.BlockBeforeWave) then
				if GAMEMODE:GetWave() < tonumber(linkedNodeParams.BlockBeforeWave) then blocked = true end
			end
			if linkedNodeParams.BlockAfterWave and tonumber(linkedNodeParams.BlockAfterWave) then
				if GAMEMODE:GetWave() > tonumber(linkedNodeParams.BlockAfterWave) then blocked = true end
				-- TODO: Invert logic when BlockBeforeWave > BlockAfterWave. This way it's possible to describe a interval of blocked waves, instead of unblocked waves
			end

			local able = true
			if abilities then
				if linkParams.Walking == "Needed" and not abilities.Walk then able = false end
				if linkParams.Pouncing == "Needed" and not abilities.Pounce then able = false end
				if linkedNodeParams.Climbing == "Needed" and not abilities.Climb then able = false end
			end

			if able and not blocked and not (linkParams.Direction == "Forward" and link.Nodes[2] == node) and
				not (linkParams.Direction == "Backward" and link.Nodes[1] == node) then
				local linkedNodePathCost = minimalPathCostByNode[node] + mathMax(node.Pos:Distance(linkedNode.Pos) + (linkedNodeParams.Cost or 0) + (linkParams.Cost or 0) + (pathCostFunction and pathCostFunction(node, linkedNode, link) or 0), 0) -- Prevent negative change of the link costs, otherwise it will get stuck decreasing forever.
				if linkedNodePathCost < (minimalPathCostByNode[linkedNode] or mathHuge) then
					entranceByNode[linkedNode] = node
					minimalPathCostByNode[linkedNode] = linkedNodePathCost
					local heuristic = (heuristicCostFunction and heuristicCostFunction(linkedNode) or 0)
					minimalTotalPathCostByNode[linkedNode] = linkedNodePathCost + heuristic + linkedNode.Pos:Distance(endNode.Pos) -- Negative costs are allowed here.
					evaluationNodeQueue:Enqueue(linkedNode)
				end
			end
		end
	end
end

function D3bot.GetBestValveMeshPathOrNil( startArea, endArea, pathCostFunction, heuristicCostFunction, abilities )
	if not IsValid( startArea ) or not IsValid( endArea ) then return nil end
	
	local cameFrom = {}
	
	startArea:ClearSearchLists()
	startArea:AddToOpenList()
	startArea:SetCostSoFar( 0 )
	
	while not startArea:IsOpenListEmpty() do
		local current = startArea:PopOpenList()
		if not current then return end
		
		if current == endArea then
			local path = { current }
			current = current:GetID()
			while cameFrom[ current ] do
				current = cameFrom[ current ]
				if not current then break end
				table.insert( path, 1, navmesh.GetNavAreaByID( current ) )
			end
			return path
		end
		current:AddToClosedList()
		
		for _, linkedArea in pairs( current:GetAdjacentAreas() ) do
			local linkedAreaData = linkedArea:GetMetaData()
			local link = current:SharesLink( linkedArea )
			local linkData = link:GetMetaData()
			
			local blocked = false
			if linkedAreaData.Params.Condition == "Unblocked" or linkedAreaData.Params.Condition == "Blocked" then
				local entities = ents.FindInBox( linkedArea:GetCenter() + D3bot.NodeBlocking.mins, linkedArea:GetCenter() + D3bot.NodeBlocking.maxs )
				for _, ent in ipairs( entities ) do
					if D3bot.NodeBlocking.classes[ ent:GetClass() ] then
						blocked = true
						break
					end
				end
				if linkedAreaData.Params.Condition == "Blocked" then blocked = not blocked end
			end
			
			local able = true
			if linkData.Params.Walking == "Needed" and abilities and not abilities.Walk then able = false end
			if linkData.Params.Pouncing == "Needed" and abilities and not abilities.Pounce then able = false end
			if linkedAreaData.Params.Climbing == "Needed" and abilities and not abilities.Climb then able = false end
			
			if able and not blocked then
				local newCostSoFar = current:GetCostSoFar() + math.max( current:GetCenter():Distance( linkedArea:GetCenter() ) + ( ( linkedAreaData.Params.Cost and current:GetCostSoFar() / 4 ) or 0 ) + ( ( linkData.Params.Cost and current:GetCostSoFar() / 4 ) or 0 ) + ( pathCostFunction and pathCostFunction( current, linkedArea, link ) or 0 ), 0 )
				if not ( linkedArea:IsOpen() or linkedArea:IsClosed() and linkedArea:GetCostSoFar() <= newCostSoFar ) then
					cameFrom[ linkedArea:GetID() ] = current:GetID()
					linkedArea:SetCostSoFar( newCostSoFar )
					local heuristic = ( heuristicCostFunction and heuristicCostFunction( linkedArea ) or 0 )
					linkedArea:SetTotalCost( newCostSoFar + heuristic + linkedArea:GetCenter():Distance( endArea:GetCenter() ) )  -- Negative costs are allowed here
					if linkedArea:IsClosed() then
						linkedArea:RemoveFromClosedList()
					end
					if linkedArea:IsOpen() then
						linkedArea:UpdateOnOpenList()
					else
						linkedArea:AddToOpenList()
					end
				end
			end
		end
	end
end

function D3bot.GetEscapeMeshPathOrNil(startNode, iterations, pathCostFunction, heuristicCostFunction, abilities)
	local minimalTotalPathCostByNode = {}
	local minimalPathCostByNode = { [startNode] = 0 }
	
	local entranceByNode = {}
	local heuristic = (heuristicCostFunction and heuristicCostFunction(startNode) or 0)
	local bestNode, bestNodeCost = startNode, heuristic
	
	local evaluationNodeQueue = D3bot.NewSortedQueue(function(nodeA, nodeB) return (minimalTotalPathCostByNode[nodeA] or math.huge) > (minimalTotalPathCostByNode[nodeB] or math.huge) end)
	evaluationNodeQueue:Enqueue(startNode)
	
	while true do
		local node = evaluationNodeQueue:Dequeue()
		
		iterations = iterations - 1
		if iterations == 0 or not node then
			if not bestNode then return end
			local node = bestNode
			local path = { node }
			while true do
				node = entranceByNode[node]
				if not node then break end
				table.insert(path, 1, node)
			end
			return path
		end
		
		for linkedNode, link in pairs(node.LinkByLinkedNode) do
			
			local blocked = false
			if linkedNode.Params.Condition == "Unblocked" or linkedNode.Params.Condition == "Blocked" then
				local ents = ents.FindInBox(linkedNode.Pos + D3bot.NodeBlocking.mins, linkedNode.Pos + D3bot.NodeBlocking.maxs)
				for _, ent in ipairs(ents) do
					if D3bot.NodeBlocking.classes[ent:GetClass()] then blocked = true; break end
				end
				if linkedNode.Params.Condition == "Blocked" then blocked = not blocked end
			end

			-- Block pathing if the wave is outside of the interval [BlockBeforeWave, BlockAfterWave]
			if linkedNode.Params.BlockBeforeWave and tonumber(linkedNode.Params.BlockBeforeWave) then
				if GAMEMODE:GetWave() < tonumber(linkedNode.Params.BlockBeforeWave) then blocked = true end
			end
			if linkedNode.Params.BlockAfterWave and tonumber(linkedNode.Params.BlockAfterWave) then
				if GAMEMODE:GetWave() > tonumber(linkedNode.Params.BlockAfterWave) then blocked = true end
				-- TODO: Invert logic when BlockBeforeWave > BlockAfterWave. This way it's possible to describe a interval of blocked waves, instead of unblocked waves
			end
			
			local able = true
			if link.Params.Walking == "Needed" and abilities and not abilities.Walk then able = false end
			if link.Params.Pouncing == "Needed" and abilities and not abilities.Pounce then able = false end
			if linkedNode.Params.Climbing == "Needed" and abilities and not abilities.Climb then able = false end

			if able and not blocked and not (link.Params.Direction == "Forward" and link.Nodes[2] == node) and not (link.Params.Direction == "Backward" and link.Nodes[1] == node) then
				local linkedNodePathCost = minimalPathCostByNode[node] + math.max((linkedNode.Params.Cost or 0) + (link.Params.Cost or 0) + (pathCostFunction and pathCostFunction(node, linkedNode, link) or 0), 0) -- Prevent negative change of the link costs, otherwise it will get stuck decreasing forever
				if linkedNodePathCost < (minimalPathCostByNode[linkedNode] or math.huge) then
					entranceByNode[linkedNode] = node
					minimalPathCostByNode[linkedNode] = linkedNodePathCost
					local heuristic = (heuristicCostFunction and heuristicCostFunction(linkedNode) or 0) -- Negative costs are allowed here
					minimalTotalPathCostByNode[linkedNode] = linkedNodePathCost + heuristic
					if bestNodeCost >= minimalTotalPathCostByNode[linkedNode] then
						bestNodeCost = minimalTotalPathCostByNode[linkedNode]
						bestNode = linkedNode
					end
					evaluationNodeQueue:Enqueue(linkedNode)
				end
			end
		end
	end
end

function D3bot.GetEscapeValveMeshPathOrNil( startArea, iterations, pathCostFunction, heuristicCostFunction, abilities )
	if not IsValid( startArea ) then return nil end
	
	local cameFrom = {}

	startArea:ClearSearchLists()
	startArea:AddToOpenList()
	startArea:SetCostSoFar( 0 )

	local heuristic = ( heuristicCostFunction and heuristicCostFunction( startArea ) or 0 )
	local bestArea, bestAreaCost = startArea, heuristic

	while not startArea:IsOpenListEmpty() do
		local current = startArea:PopOpenList()
		
		iterations = iterations - 1
		if iterations == 0 or not current then
			if not bestArea then return end
			local current = bestArea
			local path = { current }
			current = current:GetID()
			while cameFrom[ current ] do
				current = cameFrom[ current ]
				if not current then break end
				table.insert( path, 1, navmesh.GetNavAreaByID( current ) )
			end
			return path
		end
		current:AddToClosedList()

		for _, linkedArea in pairs( current:GetAdjacentAreas() ) do
			local linkedAreaData = linkedArea:GetMetaData()
			local link = current:SharesLink( linkedArea )
			local linkData = link:GetMetaData()

			local blocked = false
			if linkedAreaData.Params.Condition == "Unblocked" or linkedAreaData.Params.Condition == "Blocked" then
				local entities = ents.FindInBox( linkedArea:GetCenter() + D3bot.NodeBlocking.mins, linkedArea:GetCenter() + D3bot.NodeBlocking.maxs )
				for _, ent in ipairs( entities ) do
					if D3bot.NodeBlocking.classes[ ent:GetClass() ] then
						blocked = true
						break
					end
				end
				if linkedAreaData.Params.Condition == "Blocked" then blocked = not blocked end
			end

			local able = true
			if linkData.Params.Walking == "Needed" and abilities and not abilities.Walk then able = false end
			if linkData.Params.Pouncing == "Needed" and abilities and not abilities.Pounce then able = false end
			if linkedAreaData.Params.Climbing == "Needed" and abilities and not abilities.Climb then able = false end
		
			if able and not blocked then
				local newCostSoFar = current:GetCostSoFar() + math.max( current:GetCenter():Distance( linkedArea:GetCenter() ) + ( ( linkedAreaData.Params.Cost and current:GetCostSoFar() / 4 ) or 0 ) + ( ( linkData.Params.Cost and current:GetCostSoFar() / 4 ) or 0 ) + ( pathCostFunction and pathCostFunction( current, linkedArea, link ) or 0 ), 0 )
				if not ( linkedArea:IsOpen() or linkedArea:IsClosed() and linkedArea:GetCostSoFar() <= newCostSoFar ) then
					if linkedArea:IsClosed() then
						linkedArea:RemoveFromClosedList()
					end
					if linkedArea:IsOpen() then
						linkedArea:UpdateOnOpenList()
					else
						linkedArea:AddToOpenList()
					end
					cameFrom[ linkedArea:GetID() ] = current:GetID()
					linkedArea:SetCostSoFar( newCostSoFar )
					local heuristic = ( heuristicCostFunction and heuristicCostFunction( linkedArea ) or 0 )
					linkedArea:SetTotalCost( newCostSoFar + heuristic )  -- Negative costs are allowed here
					if linkedArea:IsClosed() then
						linkedArea:RemoveFromClosedList()
					end
					if linkedArea:IsOpen() then
						linkedArea:UpdateOnOpenList()
					else
						linkedArea:AddToOpenList()
					end
					if bestAreaCost >= linkedArea:GetTotalCost() then
						bestAreaCost = linkedArea:GetTotalCost()
						bestArea = linkedArea
					end
				end
			end
		end
	end
end
