
return function(lib)
	local from = lib.From

	local isEnabled = false
	local hooksId = tostring({})
	
	local cursoredItemOrNil
	
	local isPathPieceById = {}
	function lib.SetShownMapNavMeshPath(ids)
		isPathPieceById = {}
		local previousId
		for k, id in ipairs(ids) do
			isPathPieceById[id] = true
			if previousId then
				isPathPieceById[previousId .. lib.NavMeshLinkNodesSeparator .. id] = true
				isPathPieceById[id .. lib.NavMeshLinkNodesSeparator .. previousId] = true
			end
			previousId = id
		end
	end
	
	local isHighlightedById = {}
	function lib.HighlightInMapNavMeshView(id) isHighlightedById[id] = true end
	function lib.ClearMapNavMeshViewHighlights() isHighlightedById = {} end
	
	local function getItemColor(item) return lib.Color[isHighlightedById[item.Id] and "Green" or (item == cursoredItemOrNil and "Orange" or (isPathPieceById[item.Id] and "Yellow" or "Red"))] end
	
	local isHiddenParamByParamName = from((" "):Explode("X Y Z AreaXMin AreaYMin AreaXMax AreaYMax")):ValuesSet().R
	
	function lib.SetIsMapNavMeshViewEnabled(bool)
		if isEnabled == bool then return end
		isEnabled = bool
		if isEnabled then
			hook.Add("Think", hooksId, function() cursoredItemOrNil = lib.MapNavMesh:GetCursoredItemOrNil(LocalPlayer()) end)
			hook.Add("PostDrawOpaqueRenderables", hooksId, function()
				cam.IgnoreZ(true)
				render.SetColorMaterial()
				for id, node in pairs(lib.MapNavMesh.NodeById) do
					if node.HasArea then
						local z = node.Pos.z
						local params = node.Params
						for k, cullMode in ipairs{ MATERIAL_CULLMODE_CW, MATERIAL_CULLMODE_CCW } do
							render.CullMode(cullMode)
							render.DrawQuad(
								Vector(params.AreaXMin, params.AreaYMin, z),
								Vector(params.AreaXMin, params.AreaYMax, z),
								Vector(params.AreaXMax, params.AreaYMax, z),
								Vector(params.AreaXMax, params.AreaYMin, z),
								getItemColor(node).EightAlpha)
						end
					end
				end
				for id, link in pairs(lib.MapNavMesh.LinkById) do
					local nodeA, nodeB = unpack(link.Nodes)
					render.DrawBeam(nodeA.Pos, nodeB.Pos, 1, 0, 1, getItemColor(link))
				end
				for id, node in pairs(lib.MapNavMesh.NodeById) do render.DrawSphere(node.Pos, 2, 8, 8, getItemColor(node)) end
				cam.IgnoreZ(false)
			end)
			hook.Add("HUDPaint", hooksId, function()
				surface.SetFont("Default")
				local eyePos = EyePos()
				for id, item in pairs(lib.MapNavMesh.ItemById) do
					local isCursored = item == cursoredItemOrNil
					local itemPos = item:GetFocusPos()
					if isCursored or itemPos:Distance(eyePos) <= 500 then
						local pos = itemPos:ToScreen()
						if pos.visible then
							local paramsQuery = from(item.Params)
							if not isCursored then paramsQuery:Where(function(name) return not isHiddenParamByParamName[name] end) end
							local txt = item.Id .. ":\n" .. paramsQuery:Select(function(name, v) return nil, name .. " = " .. v end):Sort():Join("\n").R
							local txtW, txtH = surface.GetTextSize(txt)
							local w = txtW + 10
							local h = txtH + 10
							surface.SetDrawColor(lib.Color.White.HalfAlpha)
							surface.DrawRect(pos.x, pos.y, w, h)
							surface.SetDrawColor(lib.Color.Black)
							surface.DrawOutlinedRect(pos.x, pos.y, w, h)
							draw.DrawText(txt, "Default", pos.x + 5, pos.y + 5, lib.Color.Black)
						end
					end
				end
			end)
		else
			hook.Remove("Think", hooksId)
			hook.Remove("PostDrawOpaqueRenderables", hooksId)
			hook.Remove("HUDPaint", hooksId)
		end
	end
end
