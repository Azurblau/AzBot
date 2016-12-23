
return function(lib)
	function lib.GetBestMeshPathOrNil(startNode, endNode)
		-- See https://en.wikipedia.org/wiki/A*_search_algorithm
	
		local minimalTotalPathCostByNode = {}
		
		local evaluationNodeQueue = lib.NewSortedQueue(function(nodeA, nodeB) return (minimalTotalPathCostByNode[nodeA] or math.huge) > (minimalTotalPathCostByNode[nodeB] or math.huge) end)
		evaluationNodeQueue:Enqueue(startNode)
		
		local minimalPathCostByNode = {}
		minimalPathCostByNode[startNode] = 0
		
		local entranceByNode = {}
		
		local evaluatedNodesSet = {}
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
			
			evaluatedNodesSet[node] = true
			for linkedNode, link in pairs(node.LinkByLinkedNode) do
				if not evaluatedNodesSet[linkedNode] then
					evaluationNodeQueue:Enqueue(linkedNode)
					
					local linkedNodePathCost = minimalPathCostByNode[node] + node.Pos:Distance(linkedNode.Pos)
					if linkedNodePathCost < (minimalPathCostByNode[linkedNode] or math.huge) then
						entranceByNode[linkedNode] = node
						minimalPathCostByNode[linkedNode] = linkedNodePathCost
						minimalTotalPathCostByNode[linkedNode] = linkedNodePathCost + linkedNode.Pos:Distance(endNode.Pos)
					end
				end
			end
		end
	end
end
