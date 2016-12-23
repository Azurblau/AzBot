
local function registerCmd(camelCaseName, ...)
	local func
	local params = {}
	for idx, arg in ipairs({...}) do
		if istable(arg) then
			table.insert(params, arg)
		elseif isfunction(arg) then
			func = arg
			break
		else
			break
		end
	end
	ulx["azBot" .. camelCaseName] = func
	local cmdStr = "azbot " .. camelCaseName:lower()
	local cmd = ulx.command("AzBot", cmdStr, func, "!" .. cmdStr)
	for k, param in pairs(params) do cmd:addParam(param) end
	cmd:defaultAccess(ULib.ACCESS_SUPERADMIN)
end

local plsParam = { type = ULib.cmds.PlayersArg }
local strParam = { type = ULib.cmds.StringArg }
local optionalStrParam = { type = ULib.cmds.StringArg, ULib.cmds.optional }

registerCmd("ViewMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "view") end end)
registerCmd("EditMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, "edit") end end)
registerCmd("HideMesh", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.SetMapNavMeshUiSubscription(pl, nil) end end)

registerCmd("SaveMesh", function(caller)
	AzBot.SaveMapNavMesh()
	caller:ChatPrint("Saved.")
end)
registerCmd("ReloadMesh", function(caller)
	AzBot.LoadMapNavMesh()
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Reloaded.")
end)
registerCmd("RefreshMeshView", function(caller)
	AzBot.UpdateMapNavMeshUiSubscribers()
	caller:ChatPrint("Refreshed.")
end)

registerCmd("Remove", strParam, function(caller, id)
	local item = AzBot.MapNavMesh.ItemById[id]
	if not item then
		caller:ChatPrint("Item not found")
		return
	end
	item:Remove()
end)
registerCmd("SetParam", strParam, strParam, optionalStrParam, function(caller, id, name, serializedNumOrStrOrEmpty)
	AzBot.TryCatch(function()
		AzBot.MapNavMesh.ItemById[AzBot.DeserializeNavMeshItemId(id)]:SetParam(name, serializedNumOrStrOrEmpty)
		AzBot.UpdateMapNavMeshUiSubscribers()
	end, function(errorMsg)
		caller:ChatPrint("Error. Re-check your parameters.")
	end)
end)

registerCmd("ViewPath", plsParam, strParam, strParam, function(caller, pls, startNodeId, endNodeId)
	local nodeById = AzBot.MapNavMesh.NodeById
	local startNode = nodeById[AzBot.DeserializeNavMeshItemId(startNodeId)]
	local endNode = nodeById[AzBot.DeserializeNavMeshItemId(endNodeId)]
	if not startNode or not endNode then
		caller:ChatPrint("Not all specified nodes exist.")
		return
	end
	local path = AzBot.GetBestMeshPathOrNil(startNode, endNode)
	if not path then
		caller:ChatPrint("Couldn't find any path for the two specified nodes.")
		return
	end
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, path) end
end)
registerCmd("DebugPath", plsParam, optionalStrParam, function(caller, pls, serializedEntIdxOrNil)
	local ent = serializedEntIdxOrNil and Entity(tonumber(serializedEntIdxOrNil) or 1) or caller:GetEyeTrace().Entity
	if not IsValid(ent) then
		caller:ChatPrint("No entity cursored or invalid entity index specified.")
		return
	end
	caller:ChatPrint("Debugging path from player to " .. ent .. ".")
	for k, pl in pairs(pls) do AzBot.ShowMapNavMeshPath(pl, pl, ent) end
end)
registerCmd("ResetPath", plsParam, function(caller, pls) for k, pl in pairs(pls) do AzBot.HideMapNavMeshPath(pl) end end)
