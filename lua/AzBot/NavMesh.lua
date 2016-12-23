
return function(lib)
	local from = lib.From
	
	lib.NavMeshMeta = { __index = {} }
	lib.NavMeshItemMeta = { __index = {} }
	lib.NavMeshNodeMeta = {
		__index = setmetatable({ Type = "node" }, lib.NavMeshItemMeta),
		__tostring = function(node) return "N" .. node.Id end }
	lib.NavMeshLinkMeta = {
		__index = setmetatable({ Type = "link" }, lib.NavMeshItemMeta),
		__tostring = function(link) return link.Id end }
	
	local fallback = lib.NavMeshMeta.__index
	local itemFallback = lib.NavMeshItemMeta.__index
	local nodeFallback = lib.NavMeshNodeMeta.__index
	local linkFallback = lib.NavMeshLinkMeta.__index
	
	lib.MapNavMeshNetworkStr = "AzBot Map NavMesh"
	
	lib.NavMeshItemsSeparator = ";"
	lib.NavMeshItemIdParamsPairSeparator = ":"
	lib.NavMeshItemParamsSeparator = ","
	lib.NavMeshItemParamNameNumPairSeparator = "="
	lib.NavMeshLinkNodesSeparator = "-"
	
	function lib.NewNavMesh() return setmetatable({
		ItemById = {},
		NodeById = {},
		LinkById = {} }, lib.NavMeshMeta) end
	local function newItem(navMesh, id)
		local r = {
			NavMesh = navMesh,
			Id = id,
			Pos = Vector(),
			AreaVertices = {},
			Params = {} }
		navMesh.ItemById[id] = r
		return r
	end
	
	function fallback:ForceGetItem(id) return isnumber(id) and self:ForceGetNode(id) or self:ForceGetLink(id) end
	function fallback:NewNode() return self:ForceGetNode(#self.ItemById + 1) end
	function fallback:ForceGetNode(id)
		local r = self.NodeById[id]
		if r then return r end
		r = setmetatable(newItem(self, id), lib.NavMeshNodeMeta)
		r.LinkByLinkedNode = {}
		self.NodeById[id] = r
		return r
	end
	function fallback:ForceGetLink(idOrNodeA, nilOrNodeB)
		local nodeA, nodeB
		if nilOrNodeB == nil then
			local id = idOrNodeA
			local serializedNodeIds = id:Split(lib.NavMeshLinkNodesSeparator)
			if #serializedNodeIds != 2 then error("Link must have exactly 2 nodes to link.", 2) end
			local nodeIds = from(serializedNodeIds):SelectV(tonumber).R
			if from(nodeIds):Len().R != 2 then error("Invalid node ID.", 2) end
			nodeA, nodeB = unpack(from(nodeIds):SelectV(function(nodeId) return self:ForceGetNode(nodeId) end).R)
		else
			nodeA = idOrNodeA
			nodeB = nilOrNodeB
		end
		local r = nodeA.LinkByLinkedNode[nodeB]
		if r then return r end
		local id = nodeA.Id .. lib.NavMeshLinkNodesSeparator .. nodeB.Id
		r = setmetatable(newItem(self, id), lib.NavMeshLinkMeta)
		r.Nodes = { nodeA, nodeB }
		lib.TwoWay(nodeA, nodeB, function(node, linkedNode) node.LinkByLinkedNode[linkedNode] = r end)
		self.LinkById[id] = r
		return r
	end
	
	local function itemParamChanged(item, paramName)
		local params = item.Params
		if item.Pos then item.Pos = Vector(params.X or 0, params.Y or 0, params.Z or 0) end
		item.HasArea = not not (params.AreaXMin and params.AreaXMax and params.AreaYMin and params.AreaYMax)
	end
	function itemFallback:SetParam(name, numOrSerializedNumOrStrOrEmpty)
		if name == "" then error("Name is empty.", 2) end
		if numOrSerializedNumOrStrOrEmpty == "" then
			self.Params[name] = nil
			itemParamChanged(self, name)
			return
		end
		local numOrStr = tonumber(numOrSerializedNumOrStrOrEmpty) or numOrSerializedNumOrStrOrEmpty
		if (name .. (isstring(numOrStr) and numOrStr or "")):find("[^%w_]") then error("Only alphanumeric letters and underscore allowed in name and string values.", 2) end
		self.Params[name] = numOrStr
		itemParamChanged(self, name)
	end
	
	function nodeFallback:GetFocusPos() return self.Pos end
	function linkFallback:GetFocusPos() return LerpVector(0.5, self.Nodes[1].Pos, self.Nodes[2].Pos) end
	
	function nodeFallback:GetContains(pos)
		if not self.HasArea then return pos:Distance(self.Pos) < 50 end
		local params = self.Params
		return math.abs(pos.z - self.Pos.z) < 50 and pos.x >= params.AreaXMin and pos.x <= params.AreaXMax and pos.y >= params.AreaYMin and pos.y <= params.AreaYMax
	end
	
	function fallback:GetCursoredItemOrNil(pl)
		local trR = pl:GetEyeTrace()
		if not trR.Hit then return end
		local cursoredPos = trR.HitPos
		local distMin = 10
		local cursoredItemOrNil
		for id, item in pairs(self.ItemById) do
			local dist = item:GetFocusPos():Distance(cursoredPos)
			if dist < distMin then
				cursoredItemOrNil = item
				distMin = dist
			end
		end
		return cursoredItemOrNil
	end
	
	function fallback:GetNearestNodeOrNil(pos)
		local nearestNodeOrNil
		local distMin = math.huge
		for id, node in pairs(self.NodeById) do
			local nodePos = node.Pos
			if node.HasArea then
				local params = node.Params
				nodePos.x = math.Clamp(pos.x, params.AreaXMin, params.AreaXMax)
				nodePos.y = math.Clamp(pos.y, params.AreaYMin, params.AreaYMax)
			end
			local dist = pos:Distance(nodePos)
			if dist < distMin then
				nearestNodeOrNil = node
				distMin = dist
			end
		end
		return nearestNodeOrNil
	end
	
	local function removeItem(item)
		item.NavMesh.ItemById[item.Id] = nil
		item.NavMesh = nil
	end
	function nodeFallback:Remove()
		for linkedNode, link in pairs(from(self.LinkByLinkedNode):ShallowCopy().R) do link:Remove() end
		self.NavMesh.NodeById[self.Id] = nil
		removeItem(self)
	end
	function linkFallback:Remove()
		local nodeA, nodeB = unpack(self.Nodes)
		self.Nodes = {}
		lib.TwoWay(nodeA, nodeB, function(node, linkedNode) node.LinkByLinkedNode[linkedNode] = nil end)
		self.NavMesh.LinkById[self.Id] = nil
		removeItem(self)
	end
	
	function fallback:Serialize()
		return from(self.ItemById):Select(function(id, item)
			return nil, id .. lib.NavMeshItemIdParamsPairSeparator .. from(item.Params):Select(function(name, numOrStr)
				return nil, name .. lib.NavMeshItemParamNameNumPairSeparator .. numOrStr
			end):Join(lib.NavMeshItemParamsSeparator).R
		end):Join(lib.NavMeshItemsSeparator).R
	end
	function lib.DeserializeNavMesh(serialized)
		local navMesh = lib.NewNavMesh()
		for idx, serializedItem in ipairs(lib.SplitStr(serialized, lib.NavMeshItemsSeparator)) do
			local serializedId, serializedParams = unpack(serializedItem:Split(lib.NavMeshItemIdParamsPairSeparator))
			local item = navMesh:ForceGetItem(lib.DeserializeNavMeshItemId(serializedId))
			for idx, serializedParam in ipairs(lib.SplitStr(serializedParams, lib.NavMeshItemParamsSeparator)) do
				item:SetParam(unpack(serializedParam:Split(lib.NavMeshItemParamNameNumPairSeparator)))
			end
		end
		return navMesh
	end
	function lib.DeserializeNavMeshItemId(serializedId) return tonumber(serializedId) or serializedId end
end
