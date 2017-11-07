
return function(lib)
	function lib.GetBestMeshPathOrNil(startNode, endNode, additionalCostOrNilByLink, abilities)
		-- See https://en.wikipedia.org/wiki/A*_search_algorithm
		
		if additionalCostOrNilByLink == nil then additionalCostOrNilByLink = {} end
		
		local minimalTotalPathCostByNode = {}
		local minimalPathCostByNode = { [startNode] = 0 }
		
		local entranceByNode = {}
		
		local evaluationNodeQueue = lib.NewSortedQueue(function(nodeA, nodeB) return (minimalTotalPathCostByNode[nodeA] or math.huge) > (minimalTotalPathCostByNode[nodeB] or math.huge) end)
		evaluationNodeQueue:Enqueue(startNode)
		local evaluatedNodesSet = {}
		
		while true do
			local node = evaluationNodeQueue:Dequeue()
			if not node then return end
			evaluatedNodesSet[node] = true
			
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
					local ents = ents.FindInBox(linkedNode.Pos + lib.NodeBlocking.mins, linkedNode.Pos + lib.NodeBlocking.maxs)
					for _, ent in ipairs(ents) do
						if lib.NodeBlocking.classes[ent:GetClass()] then blocked = true; break end
					end
					if linkedNode.Params.Condition == "Blocked" then blocked = not blocked end
				end
				
				local able = true
				if link.Params.Walking == "Needed" and abilities and not abilities.Walk then able = false end
				if link.Params.Pouncing == "Needed" and abilities and not abilities.Pounce then able = false end
				
				if able and not blocked and not evaluatedNodesSet[linkedNode] and not (link.Params.Direction == "Forward" and link.Nodes[2] == node) and not (link.Params.Direction == "Backward" and link.Nodes[1] == node) then
					
					local linkedNodePathCost = minimalPathCostByNode[node] + node.Pos:Distance(linkedNode.Pos) + (node.Params.Cost or 0) + (link.Params.Cost or 0) + (additionalCostOrNilByLink[link] or 0)
					if linkedNodePathCost < (minimalPathCostByNode[linkedNode] or math.huge) then
						entranceByNode[linkedNode] = node
						minimalPathCostByNode[linkedNode] = linkedNodePathCost
						minimalTotalPathCostByNode[linkedNode] = linkedNodePathCost + linkedNode.Pos:Distance(endNode.Pos)
					end
					evaluationNodeQueue:Enqueue(linkedNode)
				end
			end
		end
	end
end
