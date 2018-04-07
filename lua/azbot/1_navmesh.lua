
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
	
	lib.BotNodeMinProximity = 20
	
	lib.MapNavMeshNetworkStr = "AzBot Map NavMesh"
	
	lib.NavMeshItemsSeparator = "\n"
	lib.NavMeshItemsSeparatorOld = ";"
	lib.NavMeshItemIdParamsPairSeparator = ":"
	lib.NavMeshItemParamsSeparator = ","
	lib.NavMeshItemParamNameNumPairSeparator = "="
	lib.NavMeshLinkNodesSeparator = "-"
	
	lib.Params = {
		Correct = {
			Jump = {"Disabled", "Always"},
			JumpTo = {"Disabled", "Always"},
			Duck = {"Disabled", "Always"},
			DuckTo = {"Disabled", "Always"},
			Wall = {"Suicide", "Retarget"},
			See = {"Disabled"},
			Aim = {"Straight"},
			AimTo = {"Straight"},
			Cost = {},
			Condition = {"Unblocked", "Blocked"},
			Direction = {"Forward", "Backward"},
			Walking = {"Needed"},
			Pouncing = {"Needed"},
			DMGPerSecond = {},
			BotMod = {} },
		Replace = {
			Unidir = "Direction"} }
	
	lib.NavmeshParams = {
		Correct = {
			BotMod = {},
			ZPH = {},
			ZPHM = {},
			ZPHW = {},
			ZPM = {},
			ZPW = {} },
		Replace = {} }
	
	function lib.NormalizeParam(name, numOrSerializedNumOrStrOrEmpty)
		-- Replace
		for k, v in pairs(lib.Params.Replace) do
			if k:lower() == name:lower() then
				name = v
				break
			end
		end
		-- Correct
		for k, v in pairs(lib.Params.Correct) do
			if k:lower() == name:lower() then
				name = k
				if type(numOrSerializedNumOrStrOrEmpty) == "string" then
					for _, v2 in pairs(v) do
						if v2:lower() == numOrSerializedNumOrStrOrEmpty:lower() then
							numOrSerializedNumOrStrOrEmpty = v2
							break
						end
					end
				end
				break
			end
		end
		return name, numOrSerializedNumOrStrOrEmpty
	end
	
	function lib.NormalizeNavmeshParam(name, numOrSerializedNumOrStrOrEmpty)
		-- Replace
		for k, v in pairs(lib.NavmeshParams.Replace) do
			if k:lower() == name:lower() then
				name = v
				break
			end
		end
		-- Correct
		for k, v in pairs(lib.NavmeshParams.Correct) do
			if k:lower() == name:lower() then
				name = k
				if type(numOrSerializedNumOrStrOrEmpty) == "string" then
					for _, v2 in pairs(v) do
						if v2:lower() == numOrSerializedNumOrStrOrEmpty:lower() then
							numOrSerializedNumOrStrOrEmpty = v2
							break
						end
					end
				end
				break
			end
		end
		return name, numOrSerializedNumOrStrOrEmpty
	end
	
	function lib.NewNavMesh() return setmetatable({
		ItemById = {},
		NodeById = {},
		LinkById = {},
		Params = {} }, lib.NavMeshMeta) end
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
			local nodeIds = from(serializedNodeIds):SelV(tonumber).R
			if from(nodeIds):Len().R != 2 then error("Invalid node ID.", 2) end
			nodeA, nodeB = unpack(from(nodeIds):SelV(function(nodeId) return self:ForceGetNode(nodeId) end).R)
		else
			nodeA = idOrNodeA
			nodeB = nilOrNodeB
		end
		if nodeA == nodeB then return nil end
		local r = nodeA.LinkByLinkedNode[nodeB]
		if r then return r end
		local id = nodeA.Id .. lib.NavMeshLinkNodesSeparator .. nodeB.Id
		r = setmetatable(newItem(self, id), lib.NavMeshLinkMeta)
		r.Nodes = { nodeA, nodeB }
		lib.TwoWay(nodeA, nodeB, function(node, linkedNode) node.LinkByLinkedNode[linkedNode] = r end)
		self.LinkById[id] = r
		return r
	end
	function fallback:SetParam(name, numOrSerializedNumOrStrOrEmpty)
		if name == "" then error("Name is empty.", 2) end
		name, numOrSerializedNumOrStrOrEmpty = lib.NormalizeNavmeshParam(name, numOrSerializedNumOrStrOrEmpty)
		if numOrSerializedNumOrStrOrEmpty == "" then
			self.Params[name] = nil
			return
		end
		local numOrStr = tonumber(numOrSerializedNumOrStrOrEmpty) or numOrSerializedNumOrStrOrEmpty
		if (name .. (isstring(numOrStr) and numOrStr or "")):find("[^%w_]") then error("Only alphanumeric letters and underscore allowed in name and string values.", 2) end
		self.Params[name] = numOrStr
	end
	
	local function itemParamChanged(item, paramName)
		local params = item.Params
		if item.Pos then item.Pos = Vector(params.X or 0, params.Y or 0, params.Z or 0) end
		item.HasArea = not not (params.AreaXMin and params.AreaXMax and params.AreaYMin and params.AreaYMax)
	end
	function itemFallback:SetParam(name, numOrSerializedNumOrStrOrEmpty)
		if name == "" then error("Name is empty.", 2) end
		name, numOrSerializedNumOrStrOrEmpty = lib.NormalizeParam(name, numOrSerializedNumOrStrOrEmpty)
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
	
	function linkFallback:GetParam(name) return self.Params[name] or self.Nodes[1].Params[name] or self.Nodes[2].Params[name] end
	
	function nodeFallback:GetContains(pos)
		if not self.HasArea then return pos:Distance(self.Pos) < lib.BotNodeMinProximity end
		local params = self.Params
		return math.abs(pos.z - self.Pos.z) < 50 and pos.x >= params.AreaXMin and pos.x <= params.AreaXMax and pos.y >= params.AreaYMin and pos.y <= params.AreaYMax
	end
	
	function fallback:GetCursoredItemOrNil(pl)
		local relAngMin = 5
		local cursoredItemOrNil
		local eyePos, eyeAngs = pl:EyePos(), pl:EyeAngles()
		for id, item in pairs(self.ItemById) do
			local angs = (item:GetFocusPos() - eyePos):Angle()
			local relP = math.AngleDifference(eyeAngs.p, angs.p)
			local relY = math.AngleDifference(eyeAngs.y, angs.y)
			local relAng = math.sqrt(relP * relP + relY * relY)
			if relAng < relAngMin then
				cursoredItemOrNil = item
				relAngMin = relAng
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
				nodePos = Vector(math.Clamp(pos.x, params.AreaXMin, params.AreaXMax), math.Clamp(pos.y, params.AreaYMin, params.AreaYMax), nodePos.z)
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
		return from(self.ItemById):Sel(function(id, item)
			return nil, id .. lib.NavMeshItemIdParamsPairSeparator .. from(item.Params):Sel(function(name, numOrStr)
				return nil, name .. lib.NavMeshItemParamNameNumPairSeparator .. numOrStr
			end):Join(lib.NavMeshItemParamsSeparator).R
		end):Join(lib.NavMeshItemsSeparator).R
	end
	function fallback:SerializeSorted()
		return from(self.ItemById):SelSort(function(id, item)
			return nil, id .. lib.NavMeshItemIdParamsPairSeparator .. from(item.Params):SelSort(function(name, numOrStr)
				return nil, name .. lib.NavMeshItemParamNameNumPairSeparator .. numOrStr
			end, function(a,b) return tostring(a)<tostring(b) end):Join(lib.NavMeshItemParamsSeparator).R
		end, function(a,b) return tostring(a)<tostring(b) end):Join(lib.NavMeshItemsSeparator).R
	end
	function fallback:ParamsSerializeSorted()
		return from(self.Params):SelSort(function(name, numOrStr)
			return nil, name .. lib.NavMeshItemParamNameNumPairSeparator .. numOrStr
		end, function(a,b) return tostring(a)<tostring(b) end):Join(lib.NavMeshItemsSeparator).R
	end
	function lib.DeserializeNavMesh(serialized)
		serialized = serialized:gsub("\r\n", "\n")
		serialized = serialized:gsub("\r", "\n")
		serialized = serialized:gsub(lib.NavMeshItemsSeparatorOld, lib.NavMeshItemsSeparator)
		local navMesh = lib.NewNavMesh()
		for idx, serializedItem in ipairs(lib.GetSplitStr(serialized, lib.NavMeshItemsSeparator)) do
			local serializedId, serializedParams = unpack(serializedItem:Split(lib.NavMeshItemIdParamsPairSeparator))
			local item = navMesh:ForceGetItem(lib.DeserializeNavMeshItemId(serializedId))
			for idx, serializedParam in ipairs(lib.GetSplitStr(serializedParams, lib.NavMeshItemParamsSeparator)) do
				item:SetParam(unpack(serializedParam:Split(lib.NavMeshItemParamNameNumPairSeparator)))
			end
		end
		return navMesh
	end
	function fallback:DeserializeNavMeshParams(serialized)
		for idx, serializedItem in ipairs(lib.GetSplitStr(serialized, lib.NavMeshItemsSeparator)) do
			local serializedName, serializedNumOrStr = unpack(serializedItem:Split(lib.NavMeshItemParamNameNumPairSeparator))
			self:SetParam(serializedName, serializedNumOrStr)
		end
	end
	function lib.DeserializeNavMeshItemId(serializedId) return tonumber(serializedId) or serializedId end
end
