function D3bot.GetBestMeshPathOrNil(startNode, endNode, additionalCostOrNilByLink, abilities)
	-- See https://en.wikipedia.org/wiki/A*_search_algorithm
	
	if additionalCostOrNilByLink == nil then additionalCostOrNilByLink = {} end
	
	local minimalTotalPathCostByNode = {}
	local minimalPathCostByNode = { [startNode] = 0 }
	
	local entranceByNode = {}
	
	local evaluationNodeQueue = D3bot.NewSortedQueue(function(nodeA, nodeB) return (minimalTotalPathCostByNode[nodeA] or math.huge) > (minimalTotalPathCostByNode[nodeB] or math.huge) end)
	evaluationNodeQueue:Enqueue(startNode)
	
	while true do
		local node = evaluationNodeQueue:Dequeue()
		if not node then return end
		
		if node == endNode then
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
			
			local able = true
			if link.Params.Walking == "Needed" and abilities and not abilities.Walk then able = false end
			if link.Params.Pouncing == "Needed" and abilities and not abilities.Pounce then able = false end
			
			if able and not blocked and not (link.Params.Direction == "Forward" and link.Nodes[2] == node) and not (link.Params.Direction == "Backward" and link.Nodes[1] == node) then
				local linkedNodePathCost = minimalPathCostByNode[node] + math.max(node.Pos:Distance(linkedNode.Pos) + (linkedNode.Params.Cost or 0) + (link.Params.Cost or 0) + (additionalCostOrNilByLink[link] or 0), 0) -- Prevent the costs of decreasing, it will get stuck forever otherwise
				if linkedNodePathCost < (minimalPathCostByNode[linkedNode] or math.huge) then
					entranceByNode[linkedNode] = node
					minimalPathCostByNode[linkedNode] = linkedNodePathCost
					minimalTotalPathCostByNode[linkedNode] = linkedNodePathCost + linkedNode.Pos:Distance(endNode.Pos)
					evaluationNodeQueue:Enqueue(linkedNode)
				end
			end
		end
	end
end

function D3bot.GetEscapeMeshPathOrNil(startNode, iterations, pathCostFunction, totalCostFunction, abilities)
	local minimalTotalPathCostByNode = {}
	local minimalPathCostByNode = { [startNode] = 0 }
	
	local entranceByNode = {}
	
	local evaluationNodeQueue = D3bot.NewSortedQueue(function(nodeA, nodeB) return (minimalTotalPathCostByNode[nodeA] or math.huge) > (minimalTotalPathCostByNode[nodeB] or math.huge) end)
	evaluationNodeQueue:Enqueue(startNode)
	
	while true do
		local node = evaluationNodeQueue:Dequeue()
		if not node then return end
		
		iterations = iterations - 1
		if iterations == 0 then
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
			
			local able = true
			if link.Params.Walking == "Needed" and abilities and not abilities.Walk then able = false end
			if link.Params.Pouncing == "Needed" and abilities and not abilities.Pounce then able = false end
			
			if able and not blocked and not (link.Params.Direction == "Forward" and link.Nodes[2] == node) and not (link.Params.Direction == "Backward" and link.Nodes[1] == node) then
				local linkedNodePathCost = minimalPathCostByNode[node] + math.max((linkedNode.Params.Cost or 0) + (link.Params.Cost or 0) + (pathCostFunction and pathCostFunction(node, linkedNode, link) or 0), 0) -- Prevent the costs of decreasing, it will get stuck forever otherwise
				if linkedNodePathCost < (minimalPathCostByNode[linkedNode] or math.huge) then
					entranceByNode[linkedNode] = node
					minimalPathCostByNode[linkedNode] = linkedNodePathCost
					minimalTotalPathCostByNode[linkedNode] = linkedNodePathCost + (totalCostFunction and totalCostFunction(node, linkedNode, link) or 0)
					evaluationNodeQueue:Enqueue(linkedNode)
				end
			end
		end
	end
end