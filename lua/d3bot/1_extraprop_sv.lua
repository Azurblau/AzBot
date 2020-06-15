
return function(lib)
	local from = lib.From
	
	lib.ExtraPropsDir = "extraprops/"
	lib.ExtraPropsPath = lib.ExtraPropsDir .. game.GetMap() .. ".txt"
	lib.ExtraPropsSeparator = ";"
	lib.ExtraPropSeparator = ","
	
	lib.ExtraPropByEnt = {}
	
	file.CreateDir(lib.ExtraPropsDir)
	function lib.ReloadExtraProps()
		for ent in pairs(lib.ExtraPropByEnt) do if IsValid(ent) then ent:Remove() end end
		lib.ExtraPropByEnt = {}
		if not file.Exists(lib.ExtraPropsPath, "DATA") then return end
		for idx, serializedPosAndAngAndModel in ipairs(lib.ExtraPropsSeparator:Explode(file.Read(lib.ExtraPropsPath, "DATA"))) do
			local x, y, z, p, y2, r, model = unpack(lib.ExtraPropSeparator:Explode(serializedPosAndAngAndModel))
			if model then
				local extraProp = {
					Model = model,
					Pos = Vector(tonumber(x), tonumber(y), tonumber(z)),
					Ang = Angle(tonumber(p), tonumber(y2), tonumber(r)) }
				local ent = ents.Create("prop_physics")
				lib.ExtraPropByEnt[ent] = extraProp
				ent:SetModel(extraProp.Model)
				ent:SetPos(extraProp.Pos)
				ent:SetAngles(extraProp.Ang)
				ent:Spawn()
			end
		end
		if GAMEMODE.SetupProps then gamemode.Call("SetupProps") end
	end
	hook.Add("InitPostEntityMap", tostring({}), function() lib.ReloadExtraProps() end)
	
	function lib.SaveExtraProps()
		file.Write(lib.ExtraPropsPath, from(lib.ExtraPropByEnt):Sel(function(k, v)
			return nil, lib.ExtraPropSeparator:Implode{ v.Pos.x, v.Pos.y, v.Pos.z, v.Ang.p, v.Ang.y, v.Ang.r, v.Model }
		end):Join(lib.ExtraPropsSeparator).R)
	end
	
	function lib.GetIsExtraProp(ent) return lib.ExtraPropByEnt[ent] ~= nil end
	
	function lib.TrySetExtraProp(ent)
		if not lib.GetIsExtraProp(ent) and IsValid(ent) and ent:GetClass() == "prop_physics" then
			lib.ExtraPropByEnt[ent] = {
				Model = ent:GetModel(),
				Pos = ent:GetPos(),
				Ang = ent:GetAngles() }
			return true
		end
		return false
	end
	function lib.TryUnsetExtraProp(ent)
		if lib.GetIsExtraProp(ent) then
			lib.ExtraPropByEnt[ent] = nil
			return true
		end
		return false
	end
end
